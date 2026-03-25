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
     */
    public function createForUser(User $user, string $plan): ?int
    {
        try {
            $cfg = SuperAdminController::getConfig();

            $eggId  = (int) ($cfg['default_egg_id']  ?? 3);
            $nodeId = (int) ($cfg['default_node_id'] ?? 1);

            $egg = Egg::find($eggId);
            if (!$egg) {
                \Log::warning("[XcasperBilling] Egg #{$eggId} not found, skipping auto-create.");
                return null;
            }

            $allocation = Allocation::query()
                ->where('node_id', $nodeId)
                ->whereNull('server_id')
                ->first();

            if (!$allocation) {
                \Log::warning("[XcasperBilling] No free allocation on node #{$nodeId}, skipping auto-create.");
                return null;
            }

            [$memory, $disk, $cpu] = $this->resourcesForPlan($plan, $cfg);

            $startup = $egg->startup ?? 'npm start';

            $server = $this->serverCreationService->handle([
                'user_id'          => $user->id,
                'name'             => $this->serverName($user, $plan),
                'description'      => strtoupper($plan) . ' plan server — XCASPER Hosting',
                'egg_id'           => $eggId,
                'nest_id'          => $egg->nest_id,
                'node_id'          => $nodeId,
                'allocation_id'    => $allocation->id,
                'memory'           => $memory,
                'swap'             => 0,
                'disk'             => $disk,
                'io'               => 500,
                'cpu'              => $cpu,
                'threads'          => null,
                'oom_killer'       => false,
                'startup'          => $startup,
                'image'            => $this->dockerImage($egg),
                'environment'      => ['CMD_RUN' => 'npm start'],
                'allocation_limit' => 0,
                'database_limit'   => 0,
                'backup_limit'     => 0,
                'skip_scripts'     => false,
                'start_on_completion' => false,
            ]);

            return $server->id;
        } catch (\Throwable $e) {
            \Log::error("[XcasperBilling] Server auto-create failed for user {$user->id}: " . $e->getMessage());
            return null;
        }
    }

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
            'pro'  => [
                0, // 0 = unlimited RAM in Pterodactyl
                (int) ($cfg['pro_disk_mb'] ?? 20480),
                (int) ($cfg['pro_cpu_pct'] ?? 100),
            ],
            default => [512, 5120, 50],
        };
    }

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