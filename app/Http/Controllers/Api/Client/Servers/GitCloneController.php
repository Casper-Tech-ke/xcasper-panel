<?php

namespace Pterodactyl\Http\Controllers\Api\Client\Servers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Pterodactyl\Models\Server;
use Pterodactyl\Repositories\Wings\DaemonFileRepository;
use Pterodactyl\Repositories\Wings\DaemonCommandRepository;
use Pterodactyl\Http\Controllers\Api\Client\ClientApiController;

class GitCloneController extends ClientApiController
{
    public function __construct(
        private DaemonFileRepository $fileRepository,
        private DaemonCommandRepository $commandRepository,
    ) {
        parent::__construct();
    }

    public function clone(Request $request, Server $server): JsonResponse
    {
        $request->validate([
            'url'       => 'required|string|max:1000',
            'branch'    => 'nullable|string|max:200',
            'username'  => 'nullable|string|max:255',
            'token'     => 'nullable|string|max:500',
            'directory' => 'nullable|string|max:500',
        ]);

        $rawUrl    = trim($request->input('url'));
        $branch    = trim($request->input('branch', ''));
        $username  = trim($request->input('username', ''));
        $token     = trim($request->input('token', ''));
        $directory = trim($request->input('directory', '/'));
        $directory = $directory ?: '/';

        // Validate the URL looks like a git URL
        if (!preg_match('/^(https?:\/\/|git@|ssh:\/\/)/', $rawUrl)) {
            return new JsonResponse(['success' => false, 'message' => 'Invalid Git URL format.'], 422);
        }

        // Build authenticated HTTPS URL if credentials provided
        $gitUrl = $rawUrl;
        if ($token && preg_match('/^https?:\/\//', $rawUrl)) {
            $parsed = parse_url($rawUrl);
            $host   = $parsed['host'] ?? '';
            $path   = $parsed['path'] ?? '';
            $cred   = $username ? urlencode($username) . ':' . urlencode($token) : 'oauth2:' . urlencode($token);
            $gitUrl = 'https://' . $cred . '@' . $host . $path;
        }

        // Sanitize directory for shell use
        $dir = '/' . ltrim(str_replace(['..', '~', '`', '$', ';', '&', '|'], '', $directory), '/');

        // Build git clone command
        $branchFlag = $branch ? '--branch ' . escapeshellarg($branch) . ' --single-branch ' : '';
        $escapedUrl = escapeshellarg($gitUrl);

        $script  = "#!/bin/bash\n";
        $script .= "set -e\n";
        $script .= "echo '[XCASPER-GIT] Starting clone...'\n";
        $script .= "cd /home/container" . ($dir === '/' ? '' : $dir) . " 2>/dev/null || { echo '[XCASPER-GIT] ERROR: Directory not found'; exit 1; }\n";
        $script .= "echo '[XCASPER-GIT] Cloning repository...'\n";
        $script .= "git clone {$branchFlag}{$escapedUrl} . 2>&1 && echo '[XCASPER-GIT] Clone complete!' || echo '[XCASPER-GIT] Clone failed — check credentials and repo URL'\n";
        $script .= "rm -f \"\$0\"\n";

        $scriptPath = ltrim($dir === '/' ? '' : $dir, '/') . '/.xcasper-git-clone.sh';
        $scriptPath = ltrim($scriptPath, '/');
        if (empty($scriptPath)) {
            $scriptPath = '.xcasper-git-clone.sh';
        }

        try {
            $this->fileRepository->setServer($server)->putContent($scriptPath, $script);
        } catch (\Throwable $e) {
            return new JsonResponse([
                'success' => false,
                'message' => 'Could not write clone script to server: ' . $e->getMessage(),
            ], 500);
        }

        // Try to execute (server must be running)
        $online = false;
        try {
            $execPath = '/home/container/' . $scriptPath;
            $this->commandRepository->setServer($server)->send("bash {$execPath}");
            $online = true;
        } catch (\Throwable) {
            // Server is offline — script written, user must start server and run it manually
        }

        return new JsonResponse([
            'success' => true,
            'online'  => $online,
            'message' => $online
                ? 'Git clone started! Check the server console for progress output.'
                : 'Clone script written to your files (.xcasper-git-clone.sh). Start your server, then run: bash .xcasper-git-clone.sh',
        ]);
    }
}
