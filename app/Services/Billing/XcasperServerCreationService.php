<?php

namespace Pterodactyl\Services\Billing;

use Illuminate\Support\Str;
use Pterodactyl\Models\Egg;
use Pterodactyl\Models\User;
use Pterodactyl\Models\Allocation;
use Pterodactyl\Services\Servers\ServerCreationService;
use Pterodactyl\Http\Controllers\SuperAdminController;
use Pterodactyl\Models\XcasperBilling;

class XcasperServerCreationService
{
    public function __construct(
        private ServerCreationService $serverCreationService,
    ) {}

    /**
     * Auto-create a server for a user on their first plan purchase.
     * Egg is chosen per-plan from config (basic_egg_id / pro_egg_id / admin_egg_id).
     * Environment variables are built from the egg's own variable defaults — no hardcoding.
     */
    public function createForUser(User $user, string $plan): ?int
    {
        try {
            $cfg = SuperAdminController::getConfig();

            // ── Per-plan egg lookup ──────────────────────────────────────────
            $planEggKey = $plan . '_egg_id';                          // e.g. 'basic_egg_id'
            $eggId  = (int) ($cfg[$planEggKey] ?? $cfg['default_egg_id'] ?? 3);
            $nodeId = (int) ($cfg['default_node_id'] ?? 1);

            $egg = Egg::with('variables')->find($eggId);
            if (!$egg) {
                \Log::warning("[XcasperBilling] Egg #{$eggId} not found for plan '{$plan}', skipping auto-create.");
                return null;
            }

            // ── Pick a free allocation ───────────────────────────────────────
            $allocation = Allocation::query()
                ->where('node_id', $nodeId)
                ->whereNull('server_id')
                ->first();

            if (!$allocation) {
                \Log::warning("[XcasperBilling] No free allocation on node #{$nodeId}, skipping auto-create.");
                return null;
            }

            [$memory, $disk, $cpu] = $this->resourcesForPlan($plan, $cfg);

            // ── Build environment from the egg's own variable defaults ───────
            // This works for ANY egg type: Node.js (CMD_RUN), Python (PY_FILE),
            // Minecraft (SERVER_JARFILE), etc. — no hardcoding needed.
            $environment = [];
            foreach ($egg->variables as $var) {
                $environment[$var->env_variable] = $var->default_value ?? '';
            }

            \Log::info("[XcasperBilling] Creating '{$plan}' server for user {$user->id} with egg #{$eggId} ({$egg->name})");

            $server = $this->serverCreationService->handle([
                'user_id'             => $user->id,
                'name'                => $this->serverName($user, $plan),
                'description'         => strtoupper($plan) . ' plan server — XCASPER Hosting',
                'egg_id'              => $eggId,
                'nest_id'             => $egg->nest_id,
                'node_id'             => $nodeId,
                'allocation_id'       => $allocation->id,
                'memory'              => $memory,
                'swap'                => 0,
                'disk'                => $disk,
                'io'                  => 500,
                'cpu'                 => $cpu,
                'threads'             => null,
                'oom_killer'          => false,
                'startup'             => $egg->startup ?? '',
                'image'               => $this->dockerImage($egg),
                'environment'         => $environment,
                'allocation_limit'    => 0,
                'database_limit'      => 0,
                'backup_limit'        => 0,
                'skip_scripts'        => false,
                'start_on_completion' => false,
            ]);

            return $server->id;

        } catch (\Throwable $e) {
            \Log::error("[XcasperBilling] Server auto-create failed for user {$user->id}: " . $e->getMessage());
            return null;
        }
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private function serverName(User $user, string $plan): string
    {
        $name   = $user->name_first ?: explode('@', $user->email)[0];
        $suffix = strtolower(Str::random(4));
        return Str::slug($name . '-' . $plan . '-' . $suffix, '-');
    }

    private function resourcesForPlan(string $plan, array $cfg): array
    {
        return match ($plan) {
            'basic' => [
                (int) ($cfg['basic_memory_mb'] ?? 512),
                (int) ($cfg['basic_disk_mb']   ?? 5120),
                (int) ($cfg['basic_cpu_pct']   ?? 50),
            ],
            'pro' => [
                (int) ($cfg['pro_memory_mb']   ?? 2048),
                (int) ($cfg['pro_disk_mb']     ?? 20480),
                (int) ($cfg['pro_cpu_pct']     ?? 100),
            ],
            'admin' => [
                (int) ($cfg['admin_memory_mb'] ?? 4096),
                (int) ($cfg['admin_disk_mb']   ?? 51200),
                (int) ($cfg['admin_cpu_pct']   ?? 200),
            ],
            default => [512, 5120, 50],
        };
    }

    /**
     * Pick the first Docker image from the egg's docker_images map.
     * Falls back to Node.js 18 if the egg has no images defined.
     */
    private function dockerImage(Egg $egg): string
    {
        $images = $egg->docker_images ?? '{}';
        if (is_string($images)) {
            $decoded = json_decode($images, true);
            if (is_array($decoded) && !empty($decoded)) {
                return reset($decoded);
            }
        }
        return 'ghcr.io/parkervcp/yolks:nodejs_18';
    }
}
