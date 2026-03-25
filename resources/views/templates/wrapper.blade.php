<!DOCTYPE html>
<html>
    <head>
        <title>{{ config('app.name', 'XCASPER Hosting') }}</title>

        @section('meta')
            <meta charset="utf-8">
            <meta http-equiv="X-UA-Compatible" content="IE=edge">
            <meta content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no" name="viewport">
            <meta name="csrf-token" content="{{ csrf_token() }}">
            <meta name="robots" content="noindex">
            <meta name="description" content="XCASPER Hosting — We believe in building together. A CASPER TECH KENYA DEVELOPERS product.">
            <meta property="og:type" content="website">
            <meta property="og:site_name" content="{{ config('app.name', 'XCASPER Hosting') }}">
            <meta property="og:title" content="{{ config('app.name', 'XCASPER Hosting') }}">
            <meta property="og:description" content="Manage your game servers with ease. We believe in building together — your success is our mission.">
            <meta property="og:image" content="{{ config('app.url') }}/og-image.png">
            <meta property="og:image:width" content="1200">
            <meta property="og:image:height" content="630">
            <meta property="og:url" content="{{ config('app.url') }}">
            <meta name="twitter:card" content="summary_large_image">
            <meta name="twitter:title" content="{{ config('app.name', 'XCASPER Hosting') }}">
            <meta name="twitter:description" content="Manage your game servers with ease. We believe in building together — your success is our mission.">
            <meta name="twitter:image" content="{{ config('app.url') }}/og-image.png">
            <link rel="apple-touch-icon" sizes="180x180" href="/favicons/apple-touch-icon.png">
            <link rel="icon" type="image/svg+xml" href="/favicons/favicon.svg">
            <link rel="icon" type="image/png" href="/favicons/favicon-32x32.png" sizes="32x32">
            <link rel="icon" type="image/png" href="/favicons/favicon-16x16.png" sizes="16x16">
            <link rel="manifest" href="/favicons/manifest.json">
            <link rel="mask-icon" href="/favicons/safari-pinned-tab.svg" color="#00D4FF">
            <link rel="shortcut icon" href="/favicons/favicon.ico">
            <meta name="msapplication-config" content="/favicons/browserconfig.xml">
            <meta name="theme-color" content="#050D1F">
        @show

        @section('user-data')
            @if(!is_null(Auth::user()))
                <script>
                    window.PterodactylUser = {!! json_encode(Auth::user()->toVueObject()) !!};
                </script>
            @endif
            @if(!empty($siteConfiguration))
                <script>
                    window.SiteConfiguration = {!! json_encode($siteConfiguration) !!};
                </script>
            @endif
        @show

        @yield('assets')

        @include('layouts.scripts')
        @php
            $xcasper = \Pterodactyl\Http\Controllers\SuperAdminController::getConfig();

            // Convert hex → RGB components so styled-components can do rgba(var(--xcasper-primary-rgb), 0.3)
            function xcasperHexRgb(string $hex): string {
                $hex = ltrim($hex, '#');
                if (strlen($hex) === 3) {
                    $hex = $hex[0].$hex[0].$hex[1].$hex[1].$hex[2].$hex[2];
                }
                return hexdec(substr($hex, 0, 2)) . ',' . hexdec(substr($hex, 2, 2)) . ',' . hexdec(substr($hex, 4, 2));
            }
            $primaryRgb = xcasperHexRgb($xcasper['primary_color']);
            $accentRgb  = xcasperHexRgb($xcasper['accent_color']);
            $bgRgb      = xcasperHexRgb($xcasper['bg_color']);
        @endphp
        <style>
            :root {
                --xcasper-primary:     {{ $xcasper['primary_color'] }};
                --xcasper-primary-rgb: {{ $primaryRgb }};
                --xcasper-accent:      {{ $xcasper['accent_color'] }};
                --xcasper-accent-rgb:  {{ $accentRgb }};
                --xcasper-bg:          {{ $xcasper['bg_color'] }};
                --xcasper-bg-rgb:      {{ $bgRgb }};
            }
            body { background: transparent !important; }
        </style>
        <script>
            window.XCasperConfig = @json($xcasper);
        </script>
    </head>
    <body class="{{ $css['body'] ?? 'bg-neutral-900' }}" style="background:transparent;">
        @include('layouts.xcasper-bg')
        @section('content')
            @yield('above-container')
            @yield('container')
            @yield('below-container')
        @show
        @section('scripts')
            {!! $asset->js('main.js') !!}
        @show
        {{-- Dynamic color overrides — injected AFTER styled-components so they win on targetable elements --}}
        <style id="xcasper-dynamic-theme">
            /* ── Console cursor & selection ── */
            .xterm-cursor-layer { color: var(--xcasper-primary, #00D4FF) !important; }
            .xterm-selection-layer { background: rgba(var(--xcasper-primary-rgb, 0,212,255), 0.18) !important; }

            /* ── Scrollbars across the panel ── */
            ::-webkit-scrollbar-thumb {
                background: rgba(var(--xcasper-primary-rgb, 0,212,255), 0.25) !important;
            }
            ::-webkit-scrollbar-thumb:hover {
                background: rgba(var(--xcasper-primary-rgb, 0,212,255), 0.45) !important;
            }

            /* ── Input focus rings (not overriding styled-comp class names, but pseudo-class) ── */
            input:focus, textarea:focus, select:focus {
                border-color: rgba(var(--xcasper-primary-rgb, 0,212,255), 0.6) !important;
                box-shadow: 0 0 0 3px rgba(var(--xcasper-primary-rgb, 0,212,255), 0.12) !important;
                outline: none !important;
            }

            /* ── Progress bars ── */
            [role="progressbar"] > *, progress::-webkit-progress-value {
                background: linear-gradient(90deg, var(--xcasper-primary, #00D4FF), var(--xcasper-accent, #7C3AED)) !important;
            }

            /* ── reCAPTCHA badge positioning ── */
            .grecaptcha-badge {
                bottom: 80px !important;
                opacity: 0.5 !important;
                transition: opacity 0.3s !important;
                z-index: 10 !important;
            }
            .grecaptcha-badge:hover { opacity: 1 !important; }
        </style>
    </body>
</html>

{{-- XCASPER Git Clone Button Injection --}}
<style>
#xcasper-git-btn {
    display: inline-flex; align-items: center; gap: 6px;
    padding: 6px 14px; border-radius: 4px; font-size: 13px; font-weight: 600;
    cursor: pointer; border: none; transition: all .2s;
    background: linear-gradient(135deg, #00d4ff 0%, #007acc 100%);
    color: #fff; white-space: nowrap;
}
#xcasper-git-btn:hover { transform: translateY(-1px); box-shadow: 0 4px 16px rgba(0,212,255,.4); }
#xcasper-git-overlay {
    position: fixed; inset: 0; background: rgba(0,0,0,.75); z-index: 9999;
    display: flex; align-items: center; justify-content: center;
}
#xcasper-git-modal {
    background: #1a1f2b; border: 1px solid #2d3a50; border-radius: 10px;
    width: 480px; max-width: 96vw; padding: 28px 32px; color: #e2e8f0;
    box-shadow: 0 20px 60px rgba(0,0,0,.6);
}
#xcasper-git-modal h3 { margin: 0 0 6px; font-size: 18px; color: #00d4ff; display: flex; align-items: center; gap: 8px; }
#xcasper-git-modal p.sub { margin: 0 0 20px; font-size: 12px; color: #718096; }
#xcasper-git-modal label { display: block; font-size: 12px; color: #a0aec0; margin-bottom: 4px; font-weight: 600; }
#xcasper-git-modal input {
    width: 100%; box-sizing: border-box; padding: 9px 12px; border-radius: 5px;
    border: 1px solid #2d3a50; background: #0f131c; color: #e2e8f0; font-size: 13px;
    margin-bottom: 14px; outline: none; transition: border .2s;
}
#xcasper-git-modal input:focus { border-color: #00d4ff; }
#xcasper-git-modal .row { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
.xcasper-git-actions { display: flex; gap: 10px; margin-top: 8px; }
.xcasper-git-actions button {
    flex: 1; padding: 10px; border-radius: 5px; font-size: 14px; font-weight: 600;
    cursor: pointer; border: none; transition: all .2s;
}
#xcasper-git-cancel { background: #2d3a50; color: #a0aec0; }
#xcasper-git-cancel:hover { background: #374357; }
#xcasper-git-submit { background: linear-gradient(135deg, #00d4ff, #007acc); color: #fff; }
#xcasper-git-submit:hover { transform: translateY(-1px); box-shadow: 0 4px 16px rgba(0,212,255,.4); }
#xcasper-git-submit:disabled { opacity: .5; cursor: wait; }
#xcasper-git-result {
    margin-top: 14px; padding: 10px 14px; border-radius: 6px; font-size: 13px;
    display: none; word-break: break-word; line-height: 1.5;
}
#xcasper-git-result.ok  { background: rgba(72,187,120,.15); border: 1px solid rgba(72,187,120,.4); color: #68d391; }
#xcasper-git-result.err { background: rgba(252,129,74,.15);  border: 1px solid rgba(252,129,74,.4);  color: #fc8b4e; }
</style>

<div id="xcasper-git-overlay" style="display:none">
  <div id="xcasper-git-modal">
    <h3>🔀 Clone Git Repository</h3>
    <p class="sub">Clones the repo into your server's file system. The server must be running for auto-execution.</p>
    <label>Repository URL *</label>
    <input id="xcg-url" type="text" placeholder="https://github.com/user/repo.git" autocomplete="off">
    <label>Target Directory (leave blank for current)</label>
    <input id="xcg-dir" type="text" placeholder="/ (root)">
    <label>Branch (optional)</label>
    <input id="xcg-branch" type="text" placeholder="main">
    <p class="sub" style="margin:0 0 6px">Private repo? Provide credentials below.</p>
    <div class="row">
      <div>
        <label>Username (optional)</label>
        <input id="xcg-user" type="text" placeholder="github-username" autocomplete="off">
      </div>
      <div>
        <label>Access Token / PAT</label>
        <input id="xcg-token" type="password" placeholder="ghp_xxxxxxxx" autocomplete="off">
      </div>
    </div>
    <div class="xcasper-git-actions">
      <button id="xcasper-git-cancel">Cancel</button>
      <button id="xcasper-git-submit">🚀 Clone Repository</button>
    </div>
    <div id="xcasper-git-result"></div>
  </div>
</div>

<script>
(function () {
    var INJECTED_KEY = 'xcasper-git-injected';
    var overlay   = document.getElementById('xcasper-git-overlay');
    var cancelBtn = document.getElementById('xcasper-git-cancel');
    var submitBtn = document.getElementById('xcasper-git-submit');
    var result    = document.getElementById('xcasper-git-result');
    var urlInput  = document.getElementById('xcg-url');
    var dirInput  = document.getElementById('xcg-dir');
    var branchInp = document.getElementById('xcg-branch');
    var userInp   = document.getElementById('xcg-user');
    var tokenInp  = document.getElementById('xcg-token');

    function getCsrf() {
        var m = document.querySelector('meta[name="csrf-token"]');
        return m ? m.content : '';
    }

    function getServerShortId() {
        var m = window.location.pathname.match(/\/server\/([a-z0-9]+)\//i);
        return m ? m[1] : null;
    }

    function getCurrentDirectory() {
        var path = window.location.pathname;
        var m = path.match(/\/server\/[a-z0-9]+\/files\/?(.*)$/i);
        if (m && m[1]) {
            var decoded = decodeURIComponent(m[1]);
            return decoded.startsWith('/') ? decoded : '/' + decoded;
        }
        return '/';
    }

    function openModal() {
        var dir = getCurrentDirectory();
        dirInput.value = dir;
        result.style.display = 'none';
        result.className = '';
        result.textContent = '';
        urlInput.value = '';
        branchInp.value = '';
        userInp.value = '';
        tokenInp.value = '';
        submitBtn.disabled = false;
        overlay.style.display = 'flex';
        setTimeout(function() { urlInput.focus(); }, 50);
    }

    function closeModal() { overlay.style.display = 'none'; }

    cancelBtn.addEventListener('click', closeModal);
    overlay.addEventListener('click', function(e) { if (e.target === overlay) closeModal(); });
    document.addEventListener('keydown', function(e) { if (e.key === 'Escape') closeModal(); });

    submitBtn.addEventListener('click', function () {
        var url = urlInput.value.trim();
        if (!url) { urlInput.focus(); return; }

        var shortId = getServerShortId();
        if (!shortId) {
            result.textContent = 'Could not detect server ID from URL. Navigate to the file manager first.';
            result.className = 'err';
            result.style.display = 'block';
            return;
        }

        submitBtn.disabled = true;
        result.style.display = 'none';
        submitBtn.textContent = '⏳ Cloning...';

        fetch('/api/client/servers/' + shortId + '/files/git-clone', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'X-CSRF-TOKEN': getCsrf(),
            },
            body: JSON.stringify({
                url:       url,
                directory: dirInput.value.trim() || '/',
                branch:    branchInp.value.trim(),
                username:  userInp.value.trim(),
                token:     tokenInp.value.trim(),
            })
        })
        .then(function(r) { return r.json(); })
        .then(function(data) {
            submitBtn.disabled = false;
            submitBtn.textContent = '🚀 Clone Repository';
            var msg = data.message || (data.success ? 'Done!' : 'Unknown error');
            result.textContent = msg;
            result.className = data.success ? 'ok' : 'err';
            result.style.display = 'block';
            if (data.success && data.online) {
                setTimeout(closeModal, 4000);
            }
        })
        .catch(function(err) {
            submitBtn.disabled = false;
            submitBtn.textContent = '🚀 Clone Repository';
            result.textContent = 'Request failed: ' + (err.message || err);
            result.className = 'err';
            result.style.display = 'block';
        });
    });

    // MutationObserver: inject button into file manager toolbar when it renders
    function injectButton() {
        if (!window.location.pathname.match(/\/server\/[a-z0-9]+\/files/i)) return;
        if (document.getElementById('xcasper-git-btn')) return;

        // Find the file manager action buttons area (look for "Create Directory" or "Upload Files" button text)
        var allBtns = document.querySelectorAll('button, [role="button"]');
        var toolbarParent = null;
        for (var i = 0; i < allBtns.length; i++) {
            var t = allBtns[i].textContent || '';
            if (t.includes('Create Directory') || t.includes('Upload Files') || t.includes('New Directory')) {
                toolbarParent = allBtns[i].parentNode;
                break;
            }
        }
        if (!toolbarParent) return;

        var btn = document.createElement('button');
        btn.id = 'xcasper-git-btn';
        btn.innerHTML = '🔀 Clone Repo';
        btn.addEventListener('click', openModal);
        toolbarParent.appendChild(btn);
    }

    var observer = new MutationObserver(function() { injectButton(); });
    observer.observe(document.body, { childList: true, subtree: true });

    // Also try immediately + on navigation
    injectButton();
    window.addEventListener('popstate', function() { setTimeout(injectButton, 300); });

    // Watch URL changes in SPA (hashchange / pushState)
    var lastPath = location.pathname;
    setInterval(function() {
        if (location.pathname !== lastPath) {
            lastPath = location.pathname;
            var existing = document.getElementById('xcasper-git-btn');
            if (existing) existing.remove();
            setTimeout(injectButton, 500);
        }
    }, 500);
})();
</script>
