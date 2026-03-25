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
