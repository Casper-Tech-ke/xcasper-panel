<?php

namespace Pterodactyl\Services\Billing;

use Pterodactyl\Models\XcasperPushSubscription;
use Pterodactyl\Http\Controllers\SuperAdminController;
use Illuminate\Support\Facades\Log;

class PushNotificationService
{
    /**
     * Send a push notification to all subscriptions for a user.
     */
    public function sendToUser(int $userId, string $title, string $body, string $icon = '/xcasper-icon.png', string $url = '/dashboard'): void
    {
        $subscriptions = XcasperPushSubscription::where('user_id', $userId)->get();

        foreach ($subscriptions as $sub) {
            try {
                $this->sendPush($sub, $title, $body, $icon, $url);
            } catch (\Throwable $e) {
                Log::warning("[Push] Failed to send to subscription {$sub->id}: " . $e->getMessage());
                if (str_contains($e->getMessage(), '410') || str_contains($e->getMessage(), '404')) {
                    $sub->delete();
                }
            }
        }
    }

    private function sendPush(XcasperPushSubscription $sub, string $title, string $body, string $icon, string $url): void
    {
        $cfg = SuperAdminController::getConfig();
        $vapidPublicKey  = $cfg['vapid_public_key']  ?? null;
        $vapidPrivateKey = $cfg['vapid_private_key'] ?? null;

        if (!$vapidPublicKey || !$vapidPrivateKey) {
            Log::warning('[Push] VAPID keys not configured, skipping push.');
            return;
        }

        $payload = json_encode([
            'title'    => $title,
            'body'     => $body,
            'icon'     => $icon,
            'url'      => $url,
            'timestamp'=> time(),
        ]);

        $audience = $this->extractAudience($sub->endpoint);
        $jwt      = $this->buildVapidJwt($audience, $vapidPublicKey, $vapidPrivateKey);

        $headers = [
            'Content-Type: application/octet-stream',
            'TTL: 86400',
            'Authorization: vapid t=' . $jwt . ',k=' . $vapidPublicKey,
        ];

        if ($sub->auth_key && $sub->p256dh_key) {
            [$encrypted, $salt, $serverPublicKey] = $this->encrypt($payload, $sub->p256dh_key, $sub->auth_key);
            $headers[] = 'Content-Encoding: aes128gcm';
            $finalPayload = $encrypted;
        } else {
            $finalPayload = $payload;
        }

        $ch = curl_init($sub->endpoint);
        curl_setopt_array($ch, [
            CURLOPT_POST           => true,
            CURLOPT_POSTFIELDS     => $finalPayload ?? $payload,
            CURLOPT_HTTPHEADER     => $headers,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT        => 10,
        ]);
        $result = curl_exec($ch);
        $code   = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if ($code >= 400) {
            throw new \RuntimeException("Push endpoint returned HTTP {$code}");
        }
    }

    private function extractAudience(string $endpoint): string
    {
        $parts = parse_url($endpoint);
        return ($parts['scheme'] ?? 'https') . '://' . ($parts['host'] ?? '') . (isset($parts['port']) ? ':' . $parts['port'] : '');
    }

    private function buildVapidJwt(string $audience, string $publicKey, string $privateKeyB64url): string
    {
        $header  = $this->base64url(json_encode(['typ' => 'JWT', 'alg' => 'ES256']));
        $payload = $this->base64url(json_encode([
            'aud' => $audience,
            'exp' => time() + 43200,
            'sub' => 'mailto:support@xcasper.space',
        ]));

        $unsigned = $header . '.' . $payload;

        $privateKeyDer = base64_decode(strtr($privateKeyB64url, '-_', '+/'));

        $pkey = openssl_pkey_new([
            'curve_name'       => 'prime256v1',
            'private_key_type' => OPENSSL_KEYTYPE_EC,
        ]);

        $keyDetail = openssl_pkey_get_details($pkey);
        openssl_free_key($pkey);

        $privKeyPem = $this->rawPrivKeyToPem($privateKeyDer);
        $pkey2 = openssl_pkey_get_private($privKeyPem);

        openssl_sign($unsigned, $derSig, $pkey2, OPENSSL_ALGO_SHA256);

        $signature = $this->derToRaw($derSig);

        return $unsigned . '.' . $this->base64url($signature);
    }

    private function rawPrivKeyToPem(string $rawKey): string
    {
        $seq = hex2bin(
            '30770201010420' .
            bin2hex($rawKey) .
            'a00a06082a8648ce3d030107a14403420004'
        );

        $pubKey = $this->dummyPublicKey();
        $der = hex2bin('30770201010420') . $rawKey . hex2bin('a00a06082a8648ce3d030107');

        $b64 = chunk_split(base64_encode($der), 64, "\n");
        return "-----BEGIN EC PRIVATE KEY-----\n{$b64}-----END EC PRIVATE KEY-----\n";
    }

    private function dummyPublicKey(): string { return ''; }

    private function derToRaw(string $der): string
    {
        $offset = 0;
        if (ord($der[$offset]) !== 0x30) throw new \RuntimeException('Invalid DER');
        $offset++;
        if (ord($der[$offset]) & 0x80) $offset += (ord($der[$offset]) & 0x7f) + 1;
        else $offset++;
        if (ord($der[$offset]) !== 0x02) throw new \RuntimeException('Invalid DER R');
        $offset++;
        $rLen = ord($der[$offset++]);
        $r = substr($der, $offset, $rLen);
        $offset += $rLen;
        if (ord($der[$offset]) !== 0x02) throw new \RuntimeException('Invalid DER S');
        $offset++;
        $sLen = ord($der[$offset++]);
        $s = substr($der, $offset, $sLen);
        $r = ltrim($r, "\x00");
        $s = ltrim($s, "\x00");
        return str_pad($r, 32, "\x00", STR_PAD_LEFT) . str_pad($s, 32, "\x00", STR_PAD_LEFT);
    }

    private function encrypt(string $payload, string $p256dhB64url, string $authB64url): array
    {
        return [$payload, '', ''];
    }

    private function base64url(string $data): string
    {
        return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
    }

    public static function generateVapidKeys(): array
    {
        $key = openssl_pkey_new([
            'curve_name'       => 'prime256v1',
            'private_key_type' => OPENSSL_KEYTYPE_EC,
        ]);

        $details = openssl_pkey_get_details($key);

        $uncompressed  = "\x04" . $details['ec']['x'] . $details['ec']['y'];
        $publicKeyB64  = rtrim(strtr(base64_encode($uncompressed), '+/', '-_'), '=');
        $privateKeyB64 = rtrim(strtr(base64_encode($details['ec']['d']), '+/', '-_'), '=');

        openssl_free_key($key);

        return [
            'public'  => $publicKeyB64,
            'private' => $privateKeyB64,
        ];
    }
}
