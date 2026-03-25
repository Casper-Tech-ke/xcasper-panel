<?php

namespace Pterodactyl\Http\Controllers\Auth;

use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Pterodactyl\Http\Controllers\Controller;
use Pterodactyl\Services\Users\UserCreationService;
use Pterodactyl\Notifications\RegistrationVerification;

class RegisterController extends Controller
{
    public function __construct(private UserCreationService $creationService)
    {
    }

    /** Allowed email provider domains. */
    private const ALLOWED_DOMAINS = ['gmail.com', 'outlook.com', 'hotmail.com'];

    /**
     * Patterns in the local part (before @) that are clearly fake/spam.
     * Exact match OR starts-with match against these prefixes.
     */
    private const BLOCKED_LOCAL_PREFIXES = [
        'test', 'fake', 'temp', 'spam', 'noreply', 'no-reply', 'no_reply',
        'admin', 'info', 'contact', 'support', 'hello', 'mail', 'email',
        'user', 'example', 'sample', 'demo', 'dummy', 'abc', 'aaa', 'xxx',
        'asdf', 'qwerty', 'password', 'pass', '1234', 'random', 'null',
        'void', 'disposable', 'throwaway', 'trash', 'junk', 'delete',
    ];

    /**
     * Validate the email address thoroughly:
     * - Must be from an allowed provider
     * - Local part must meet naming conventions
     * - Domain must have valid MX records (defence-in-depth)
     *
     * Returns a human-readable error message or null if the email is valid.
     */
    private function validateEmailAddress(string $email): ?string
    {
        $atPos = strrpos($email, '@');
        if ($atPos === false) {
            return 'Invalid email address format.';
        }

        $local  = strtolower(substr($email, 0, $atPos));
        $domain = strtolower(substr($email, $atPos + 1));

        // ── 1. Domain allow-list ──────────────────────────────────────────
        if (!in_array($domain, self::ALLOWED_DOMAINS, true)) {
            return 'Only Gmail (@gmail.com), Outlook (@outlook.com), and Hotmail (@hotmail.com) addresses are accepted.';
        }

        // ── 2. Local-part minimum length ──────────────────────────────────
        // Gmail enforces at least 6 characters; we apply 5 universally.
        if (strlen($local) < 5) {
            return 'The email address is too short to be a valid ' . ucfirst(explode('.', $domain)[0]) . ' address.';
        }

        // ── 3. Gmail-specific: only letters, numbers, and dots allowed ─────
        if ($domain === 'gmail.com' && !preg_match('/^[a-z0-9][a-z0-9.]+[a-z0-9]$/', $local)) {
            return 'This does not appear to be a valid Gmail address. Gmail addresses can only contain letters, numbers, and dots.';
        }

        // ── 4. Block obviously fake / spam local-part prefixes ─────────────
        foreach (self::BLOCKED_LOCAL_PREFIXES as $prefix) {
            if ($local === $prefix
                || str_starts_with($local, $prefix . '.')
                || str_starts_with($local, $prefix . '_')
                || str_starts_with($local, $prefix . '-')
                || str_starts_with($local, $prefix . '0')
                || str_starts_with($local, $prefix . '1')
                || str_starts_with($local, $prefix . '2')
            ) {
                return 'Please use your real email address. This address does not appear to be genuine.';
            }
        }

        // ── 5. Block repetitive character patterns (e.g. aaaa@, 1111@) ────
        if (preg_match('/^(.)\1{3,}/', $local)) {
            return 'This email address does not appear to be real. Please use your actual email.';
        }

        // ── 6. MX record check — verify the domain actually accepts mail ───
        if (!checkdnsrr($domain, 'MX')) {
            return 'The email domain does not appear to accept emails. Please double-check your address.';
        }

        return null; // all checks passed
    }

    public function register(Request $request): JsonResponse
    {
        $request->validate([
            'email'      => 'required|email|max:255',
            'username'   => 'required|alpha_num|min:3|max:30',
            'name_first' => 'required|string|max:50',
            'name_last'  => 'required|string|max:50',
            'password'   => 'required|string|min:8|confirmed',
        ]);

        $email    = strtolower(trim($request->input('email')));
        $username = trim($request->input('username'));

        // ── Email quality validation ──────────────────────────────────────
        $emailError = $this->validateEmailAddress($email);
        if ($emailError !== null) {
            return new JsonResponse(['errors' => [['detail' => $emailError]]], 422);
        }

        if (\Pterodactyl\Models\User::where('email', $email)->exists()) {
            return new JsonResponse(['errors' => [['detail' => 'An account with that email already exists.']]], 422);
        }

        if (\Pterodactyl\Models\User::where('username', $username)->exists()) {
            return new JsonResponse(['errors' => [['detail' => 'That username is already taken.']]], 422);
        }

        $token = Str::random(64);

        DB::table('pending_registrations')->updateOrInsert(
            ['email' => $email],
            [
                'username'   => $username,
                'name_first' => trim($request->input('name_first')),
                'name_last'  => trim($request->input('name_last')),
                'password'   => encrypt($request->input('password')),
                'token'      => $token,
                'expires_at' => now()->addHours(24),
                'created_at' => now(),
                'updated_at' => now(),
            ]
        );

        \Illuminate\Support\Facades\Notification::route('mail', $email)
            ->notify(new RegistrationVerification($token, $email, trim($request->input('name_first'))));

        return new JsonResponse(['data' => ['sent' => true]]);
    }

    public function verify(Request $request, string $token): \Illuminate\Http\RedirectResponse
    {
        $pending = DB::table('pending_registrations')->where('token', $token)->first();

        if (!$pending) {
            return redirect('/auth/login')->with('flash_error', 'Invalid or expired verification link.');
        }

        if (now()->isAfter($pending->expires_at)) {
            DB::table('pending_registrations')->where('token', $token)->delete();
            return redirect('/auth/login')->with('flash_error', 'This verification link has expired. Please register again.');
        }

        if (\Pterodactyl\Models\User::where('email', $pending->email)->exists()) {
            DB::table('pending_registrations')->where('token', $token)->delete();
            return redirect('/auth/login')->with('flash_success', 'Account already exists. Please log in.');
        }

        try {
            $this->creationService->handle([
                'email'      => $pending->email,
                'username'   => $pending->username,
                'name_first' => $pending->name_first,
                'name_last'  => $pending->name_last,
                'password'   => decrypt($pending->password),
                'root_admin' => false,
                'language'   => 'en',
            ]);

            DB::table('pending_registrations')->where('token', $token)->delete();
        } catch (\Exception $e) {
            \Illuminate\Support\Facades\Log::error('Registration verification failed: ' . $e->getMessage());
            return redirect('/auth/login')->with('flash_error', 'Account creation failed. Please try again or contact support.');
        }

        return redirect('/auth/login')->with('flash_success', 'Your account has been verified! You can now log in.');
    }
}
