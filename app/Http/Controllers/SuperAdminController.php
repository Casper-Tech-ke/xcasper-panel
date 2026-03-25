<?php

namespace Pterodactyl\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\View\View;
use Illuminate\Contracts\Encryption\Encrypter;
use Pterodactyl\Contracts\Repository\SettingsRepositoryInterface;
use Pterodactyl\Providers\SettingsServiceProvider;
use Pterodactyl\Models\User;
use Pterodactyl\Models\XcasperBan;
use Pterodactyl\Models\XcasperBilling;
use Pterodactyl\Models\XcasperTransaction;
use Pterodactyl\Models\XcasperWallet;
use Pterodactyl\Services\Billing\PushNotificationService;

class SuperAdminController extends Controller
{
    private string $configPath;
    private const SESSION_KEY = 'xcasper_sa_unlocked';

    public function __construct(
        private SettingsRepositoryInterface $settings,
        private Encrypter $encrypter,
    ) {
        $this->configPath = storage_path('app/xcasper-config.json');
    }

    private function isUnlocked(Request $request): bool
    {
        return $request->session()->get(self::SESSION_KEY) === true;
    }

    public static function getConfig(): array
    {
        $path = storage_path('app/xcasper-config.json');
        $defaults = [
            'app_name'           => 'XCASPER Hosting',
            'tagline'            => 'we believe in building together',
            'terminal_name'      => 'xcasper',
            'primary_color'      => '#00D4FF',
            'accent_color'       => '#7C3AED',
            'bg_color'           => '#050D1F',
            'bg_image_url'       => '',
            'logo_url'           => '',
            'email_primary'      => '#00D4FF',
            'email_accent'       => '#a78bfa',
            'email_bg'           => '#0f172a',
            'email_card_bg'      => '#162032',
            'email_btn_text'     => '#ffffff',
            'paystack_public_key'=> '',
            'paystack_secret_key'=> '',
            'admin_server_limit' => 'unlimited',
            'default_node_id'    => 1,
            'default_egg_id'     => 3,
            'basic_memory_mb'    => 512,
            'basic_disk_mb'      => 5120,
            'basic_cpu_pct'      => 50,
            'pro_memory_mb'      => 2048,
            'pro_disk_mb'        => 20480,
            'pro_cpu_pct'        => 100,
            'admin_memory_mb'    => 4096,
            'admin_disk_mb'      => 51200,
            'admin_cpu_pct'      => 200,
            'vapid_public_key'   => null,
            'vapid_private_key'  => null,
        ];

        if (!file_exists($path)) {
            return $defaults;
        }

        $data = json_decode(file_get_contents($path), true);
        return array_merge($defaults, is_array($data) ? $data : []);
    }

    public function index(Request $request): View
    {
        if (!$this->isUnlocked($request)) {
            return view('super-admin-lock');
        }

        $mailConfig = [
            'host'         => config('mail.mailers.smtp.host', ''),
            'port'         => config('mail.mailers.smtp.port', 587),
            'encryption'   => config('mail.mailers.smtp.encryption', 'tls'),
            'username'     => config('mail.mailers.smtp.username', ''),
            'from_address' => config('mail.from.address', ''),
            'from_name'    => config('mail.from.name', ''),
        ];

        return view('super-admin', [
            'config'     => self::getConfig(),
            'mailConfig' => $mailConfig,
        ]);
    }

    public function unlock(Request $request): RedirectResponse
    {
        $entered  = $request->input('_sa_key', '');
        $expected = env('XCASPER_SUPER_KEY', 'CasperXK-2025');

        if (hash_equals($expected, $entered)) {
            $request->session()->put(self::SESSION_KEY, true);
            return redirect('/super-admin');
        }

        return redirect('/super-admin')->with('lock_error', true);
    }

    public function lock(Request $request): RedirectResponse
    {
        $request->session()->forget(self::SESSION_KEY);
        return redirect('/super-admin');
    }

    public function save(Request $request): RedirectResponse
    {
        if (!$this->isUnlocked($request)) {
            return redirect('/super-admin');
        }

        // Merge with existing config so we never lose billing/VAPID/server settings
        $existing = self::getConfig();

        $existing['app_name']      = $request->input('app_name', 'XCASPER Hosting');
        $existing['tagline']       = $request->input('tagline', 'we believe in building together');
        $existing['terminal_name'] = $request->input('terminal_name', 'xcasper');
        $existing['primary_color'] = $request->input('primary_color', '#00D4FF');
        $existing['accent_color']  = $request->input('accent_color', '#7C3AED');
        $existing['bg_color']      = $request->input('bg_color', '#050D1F');
        $existing['bg_image_url']  = $request->input('bg_image_url', '');
        $existing['logo_url']      = $request->input('logo_url', '');

        file_put_contents($this->configPath, json_encode($existing, JSON_PRETTY_PRINT));

        return redirect('/super-admin')->with('success', 'Settings saved successfully!');
    }

    public function saveEmail(Request $request): RedirectResponse
    {
        if (!$this->isUnlocked($request)) {
            return redirect('/super-admin');
        }

        $values = [
            'mail:mailers:smtp:host'       => $request->input('mail_host', ''),
            'mail:mailers:smtp:port'       => (int) $request->input('mail_port', 587),
            'mail:mailers:smtp:encryption' => $request->input('mail_encryption', 'tls'),
            'mail:mailers:smtp:username'   => $request->input('mail_username', ''),
            'mail:from:address'            => $request->input('mail_from_address', ''),
            'mail:from:name'               => $request->input('mail_from_name', 'XCASPER Hosting'),
        ];

        $password = $request->input('mail_password', '');

        foreach ($values as $key => $value) {
            $this->settings->set('settings::' . $key, $value);
        }

        if (!empty($password) && $password !== '••••••••') {
            $encrypted = $this->encrypter->encrypt($password);
            $this->settings->set('settings::mail:mailers:smtp:password', $encrypted);
        }

        $existing = self::getConfig();
        $existing['email_primary']  = $request->input('email_primary', '#00D4FF');
        $existing['email_accent']   = $request->input('email_accent', '#a78bfa');
        $existing['email_bg']       = $request->input('email_bg', '#0f172a');
        $existing['email_card_bg']  = $request->input('email_card_bg', '#162032');
        $existing['email_btn_text'] = $request->input('email_btn_text', '#ffffff');
        file_put_contents($this->configPath, json_encode($existing, JSON_PRETTY_PRINT));

        return redirect('/super-admin?tab=email')->with('success', 'Email settings saved!');
    }

    // ── Billing Config ────────────────────────────────────────────────────────

    public function saveBilling(Request $request): RedirectResponse
    {
        if (!$this->isUnlocked($request)) {
            return redirect('/super-admin');
        }

        $existing = self::getConfig();
        $existing['paystack_public_key']  = trim($request->input('paystack_public_key', ''));
        $existing['paystack_secret_key']  = trim($request->input('paystack_secret_key', ''));

        $limitInput = strtolower(trim($request->input('admin_server_limit', 'unlimited')));
        $existing['admin_server_limit'] = ($limitInput === '' || $limitInput === 'unlimited') ? 'unlimited' : $limitInput;

        file_put_contents($this->configPath, json_encode($existing, JSON_PRETTY_PRINT));

        return redirect('/super-admin?tab=billing')->with('success', 'Billing settings saved!');
    }

    public function revenue(Request $request): JsonResponse
    {
        if (!$this->isUnlocked($request)) {
            return response()->json(['error' => 'Unauthorized'], 403);
        }

        $totalRevenue = XcasperTransaction::where('status', 'success')->sum('amount_kes');
        $totalUsers   = User::count();
        $activeUsers  = XcasperBilling::where('status', 'active')
            ->where('expires_at', '>', now())
            ->count();

        $planBreakdown = XcasperTransaction::where('status', 'success')
            ->selectRaw('plan, COUNT(*) as count, SUM(amount_kes) as total')
            ->groupBy('plan')
            ->get();

        $recentTx = XcasperTransaction::with('user')
            ->where('status', 'success')
            ->latest()
            ->limit(10)
            ->get()
            ->map(fn($t) => [
                'user'      => $t->user?->email ?? 'Unknown',
                'plan'      => $t->plan,
                'amount'    => $t->amount_kes,
                'reference' => $t->reference,
                'date'      => $t->created_at?->format('d M Y H:i'),
            ]);

        return response()->json([
            'total_revenue_kes' => (float) $totalRevenue,
            'total_users'       => $totalUsers,
            'active_billings'   => $activeUsers,
            'plan_breakdown'    => $planBreakdown,
            'recent'            => $recentTx,
        ]);
    }

    // ── User Management ───────────────────────────────────────────────────────

    public function users(Request $request): JsonResponse
    {
        if (!$this->isUnlocked($request)) {
            return response()->json(['error' => 'Unauthorized'], 403);
        }

        $search = $request->input('q', '');
        $query  = User::query()
            ->leftJoin('xcasper_billing', 'users.id', '=', 'xcasper_billing.user_id')
            ->select('users.id', 'users.username', 'users.email', 'users.root_admin',
                     'xcasper_billing.plan', 'xcasper_billing.status', 'xcasper_billing.expires_at');

        if (!empty($search)) {
            $query->where(function ($q) use ($search) {
                $q->where('users.email', 'LIKE', "%{$search}%")
                  ->orWhere('users.username', 'LIKE', "%{$search}%");
            });
        }

        $users = $query->orderByDesc('users.id')->limit(50)->get();
        $bannedIds = XcasperBan::pluck('user_id')->toArray();

        $users = $users->map(fn($u) => array_merge($u->toArray(), [
            'is_banned' => in_array($u->id, $bannedIds),
        ]));

        return response()->json(['users' => $users]);
    }

    public function banUser(Request $request): JsonResponse
    {
        if (!$this->isUnlocked($request)) {
            return response()->json(['error' => 'Unauthorized'], 403);
        }

        $userId = (int) $request->input('user_id');
        $reason = $request->input('reason', 'Banned by administrator');

        $user = User::find($userId);
        if (!$user) {
            return response()->json(['error' => 'User not found'], 404);
        }

        XcasperBan::firstOrCreate(['user_id' => $userId], [
            'reason'       => $reason,
            'banned_by_id' => null,
            'is_active'    => true,
        ]);

        return response()->json(['success' => true, 'message' => "User {$user->email} banned."]);
    }

    public function unbanUser(Request $request): JsonResponse
    {
        if (!$this->isUnlocked($request)) {
            return response()->json(['error' => 'Unauthorized'], 403);
        }

        $userId = (int) $request->input('user_id');
        XcasperBan::where('user_id', $userId)->delete();

        return response()->json(['success' => true, 'message' => 'User unbanned.']);
    }

    public function forceDeleteUser(Request $request): JsonResponse
    {
        if (!$this->isUnlocked($request)) {
            return response()->json(['error' => 'Unauthorized'], 403);
        }

        $userId = (int) $request->input('user_id');
        $user   = User::find($userId);

        if (!$user) {
            return response()->json(['error' => 'User not found'], 404);
        }

        $email = $user->email;
        XcasperBan::where('user_id', $userId)->delete();
        XcasperBilling::where('user_id', $userId)->delete();
        XcasperTransaction::where('user_id', $userId)->delete();
        $user->delete();

        return response()->json(['success' => true, 'message' => "User {$email} force-deleted."]);
    }

    public function addFunds(Request $request): JsonResponse
    {
        if (!$this->isUnlocked($request)) {
            return response()->json(['error' => 'Unauthorized'], 403);
        }

        $userId     = (int) $request->input('user_id');
        $plan       = $request->input('plan', 'basic');
        $days       = (int) $request->input('days', 30);
        $walletKes  = (float) $request->input('wallet_kes', 0);

        $user = User::find($userId);
        if (!$user) {
            return response()->json(['error' => 'User not found'], 404);
        }

        $plans = XcasperBilling::getPlans();
        if (!isset($plans[$plan])) {
            return response()->json(['error' => 'Invalid plan'], 422);
        }

        $billing = XcasperBilling::firstOrNew(['user_id' => $userId]);
        $billing->plan               = $plan;
        $billing->status             = 'active';
        $billing->paystack_reference = 'ADMIN-GRANT-' . time();
        $billing->amount_paid_kes    = 0;
        $billing->started_at         = now();
        $billing->expires_at         = now()->addDays($days);
        $billing->reminder_sent      = false;
        $billing->save();

        if ($plan === 'admin') {
            $user->root_admin = true;
            $user->save();
        }

        if ($walletKes > 0) {
            $wallet = XcasperWallet::forUser($userId);
            $wallet->credit($walletKes);
        }

        XcasperTransaction::create([
            'user_id'     => $userId,
            'amount_kes'  => $walletKes,
            'type'        => 'admin_grant',
            'plan'        => $plan,
            'reference'   => $billing->paystack_reference,
            'description' => "Admin granted {$plans[$plan]['label']} plan for {$days} days" . ($walletKes > 0 ? " + KES {$walletKes} wallet credit" : ''),
            'status'      => 'success',
        ]);

        return response()->json([
            'success' => true,
            'message' => "Granted {$plans[$plan]['label']} plan to {$user->email} for {$days} days." . ($walletKes > 0 ? " Added KES {$walletKes} to wallet." : ''),
        ]);
    }

    public function saveServerConfig(Request $request): RedirectResponse
    {
        if (!$this->isUnlocked($request)) {
            return redirect('/super-admin?tab=billing');
        }

        $existing = self::getConfig();

        $fields = [
            'default_node_id', 'default_egg_id',
            'basic_memory_mb', 'basic_disk_mb', 'basic_cpu_pct',
            'pro_memory_mb',   'pro_disk_mb',   'pro_cpu_pct',
            'admin_memory_mb', 'admin_disk_mb', 'admin_cpu_pct',
        ];

        foreach ($fields as $field) {
            if ($request->has($field)) {
                $existing[$field] = (int) $request->input($field);
            }
        }

        file_put_contents($this->configPath, json_encode($existing, JSON_PRETTY_PRINT));

        return redirect('/super-admin?tab=billing')->with('success', 'Server creation config saved!');
    }

    public function generateVapid(Request $request): JsonResponse
    {
        if (!$this->isUnlocked($request)) {
            return response()->json(['error' => 'Unauthorized'], 403);
        }

        $keys = \Pterodactyl\Services\Billing\PushNotificationService::generateVapidKeys();

        $existing = self::getConfig();
        $existing['vapid_public_key']  = $keys['public'];
        $existing['vapid_private_key'] = $keys['private'];
        file_put_contents($this->configPath, json_encode($existing, JSON_PRETTY_PRINT));

        return response()->json([
            'success'    => true,
            'public_key' => $keys['public'],
        ]);
    }
}
