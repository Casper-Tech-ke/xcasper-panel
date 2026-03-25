<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <title>Super Admin — XCASPER Hosting</title>
    <link rel="icon" type="image/svg+xml" href="/favicons/favicon.svg">
    <style>
        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

        :root {
            --p:  {{ $config['primary_color'] }};
            --a:  {{ $config['accent_color'] }};
            --bg: {{ $config['bg_color'] }};
        }

        body {
            font-family: 'Segoe UI', system-ui, Arial, sans-serif;
            background: #050d1f;
            color: #e2e8f0;
            min-height: 100vh;
            overflow-x: hidden;
        }

        #sa-canvas {
            position: fixed; inset: 0;
            width: 100%; height: 100%;
            z-index: 0; pointer-events: none;
        }

        .page {
            position: relative; z-index: 1;
            min-height: 100vh;
            display: flex; flex-direction: column;
            align-items: center;
            padding: 28px 16px 100px;
        }

        /* ── Header ── */
        .hdr {
            text-align: center;
            margin-bottom: 24px;
            animation: fadeD .5s ease both;
        }
        .hdr h1 {
            font-size: clamp(20px, 4vw, 32px);
            font-weight: 900;
            background: linear-gradient(90deg, var(--p), var(--a));
            -webkit-background-clip: text; -webkit-text-fill-color: transparent;
            background-clip: text;
            letter-spacing: 2px;
        }
        .hdr-sub { color: rgba(148,163,184,.6); font-size: 12px; letter-spacing: 2px; text-transform: uppercase; margin-top: 3px; }
        .btn-lock {
            margin-top: 10px;
            background: none;
            border: 1px solid rgba(255,255,255,.1);
            border-radius: 50px;
            color: rgba(100,116,139,.6);
            font-size: 10px; letter-spacing: 2px; text-transform: uppercase;
            padding: 5px 16px; cursor: pointer; font-family: inherit;
            transition: all .2s;
        }
        .btn-lock:hover { border-color: rgba(248,113,113,.4); color: rgba(248,113,113,.7); }

        /* ── Card ── */
        .card {
            background: rgba(5,13,31,.78);
            backdrop-filter: blur(28px); -webkit-backdrop-filter: blur(28px);
            border: 1px solid rgba(0,212,255,.15);
            border-radius: 20px;
            padding: 32px 28px;
            width: 100%; max-width: 800px;
            animation: popI .45s cubic-bezier(.34,1.56,.64,1) .1s both;
            box-shadow: 0 0 60px rgba(0,212,255,.1);
        }

        /* ── Alert ── */
        .alert-ok {
            background: rgba(0,212,255,.1);
            border: 1px solid rgba(0,212,255,.3);
            border-radius: 10px;
            padding: 12px 18px;
            color: var(--p);
            font-size: 13px; text-align: center;
            margin-bottom: 20px;
        }
        .alert-err {
            background: rgba(248,113,113,.1);
            border: 1px solid rgba(248,113,113,.3);
            border-radius: 10px;
            padding: 12px 18px;
            color: #f87171;
            font-size: 13px; text-align: center;
            margin-bottom: 20px;
        }

        /* ── Tabs ── */
        .tabs {
            display: flex; flex-wrap: wrap; gap: 6px;
            margin-bottom: 28px;
        }
        .tab-btn {
            padding: 7px 16px;
            border: 1px solid rgba(0,212,255,.2);
            border-radius: 50px;
            background: transparent;
            color: rgba(148,163,184,.75);
            font-size: 11px; letter-spacing: 1px; text-transform: uppercase;
            cursor: pointer; transition: all .2s; font-family: inherit;
        }
        .tab-btn.active, .tab-btn:hover {
            background: linear-gradient(135deg, var(--p), var(--a));
            color: #fff; border-color: transparent;
        }
        .tab-panel { display: none; }
        .tab-panel.active { display: block; }

        /* ── Section title ── */
        .sec-title {
            font-size: 11px; font-weight: 700;
            letter-spacing: 2px; text-transform: uppercase;
            color: rgba(148,163,184,.5);
            margin-bottom: 18px;
            padding-bottom: 10px;
            border-bottom: 1px solid rgba(0,212,255,.08);
        }
        .sec-gap { margin-top: 28px; }

        /* ── Form ── */
        .fg { display: grid; grid-template-columns: repeat(auto-fit,minmax(220px,1fr)); gap: 18px; }
        .f { display: flex; flex-direction: column; gap: 5px; }
        .f label { font-size: 11px; letter-spacing: 1.5px; text-transform: uppercase; color: rgba(148,163,184,.8); }
        .f input[type="text"], .f input[type="url"], .f input[type="email"],
        .f input[type="number"], .f input[type="password"], .f select, .f textarea {
            background: rgba(255,255,255,.05);
            border: 1px solid rgba(0,212,255,.18);
            border-radius: 10px;
            padding: 10px 13px;
            color: #fff; font-size: 13px;
            outline: none; width: 100%;
            transition: border-color .2s, box-shadow .2s;
            font-family: inherit;
        }
        .f textarea { resize: vertical; min-height: 80px; }
        .f input:focus, .f select:focus, .f textarea:focus {
            border-color: var(--p);
            box-shadow: 0 0 0 3px rgba(0,212,255,.1);
        }
        .f input[type="color"] {
            height: 44px; width: 100%;
            border: 1px solid rgba(0,212,255,.18);
            border-radius: 10px;
            background: rgba(255,255,255,.05);
            cursor: pointer; padding: 4px;
        }
        .f select { background: #0d1b30; }
        .hint { font-size: 11px; color: rgba(100,116,139,.75); margin-top: 3px; line-height: 1.5; }
        code { color: var(--p); font-size: 11px; background: rgba(0,212,255,.08); padding: 2px 5px; border-radius: 4px; }

        /* ── Buttons ── */
        .btn-save {
            display: block; width: 100%; padding: 13px;
            background: linear-gradient(135deg, var(--p), var(--a));
            color: #fff; font-size: 13px; font-weight: 700;
            letter-spacing: 2px; text-transform: uppercase;
            border: none; border-radius: 12px;
            cursor: pointer; margin-top: 24px;
            transition: transform .2s, box-shadow .2s;
            box-shadow: 0 4px 20px rgba(0,212,255,.2);
            font-family: inherit;
        }
        .btn-save:hover { transform: translateY(-2px); box-shadow: 0 8px 28px rgba(0,212,255,.35); }
        .btn-sm {
            padding: 8px 18px;
            background: linear-gradient(135deg, var(--p), var(--a));
            color: #fff; font-size: 11px; font-weight: 700;
            letter-spacing: 1px; text-transform: uppercase;
            border: none; border-radius: 8px;
            cursor: pointer; transition: transform .2s; font-family: inherit;
        }
        .btn-sm:hover { transform: translateY(-1px); }
        .btn-danger {
            background: linear-gradient(135deg, #ef4444, #b91c1c) !important;
            box-shadow: 0 4px 16px rgba(239,68,68,.25) !important;
        }

        /* ── Info/doc boxes ── */
        .info-box {
            background: rgba(0,212,255,.06);
            border: 1px solid rgba(0,212,255,.18);
            border-radius: 12px;
            padding: 16px 18px;
            font-size: 13px; color: rgba(148,163,184,.9);
            line-height: 1.7; margin-bottom: 18px;
        }
        .info-box strong { color: var(--p); }
        .info-box.warn {
            background: rgba(251,191,36,.06);
            border-color: rgba(251,191,36,.2);
        }
        .info-box.warn strong { color: #fbbf24; }
        .doc-section { margin-bottom: 24px; }
        .doc-section h3 {
            font-size: 13px; font-weight: 700;
            color: var(--p); margin-bottom: 8px;
            letter-spacing: 1px;
        }
        .doc-section p, .doc-section li {
            font-size: 13px; color: rgba(148,163,184,.85);
            line-height: 1.7;
        }
        .doc-section ul { padding-left: 18px; }
        .doc-section li { margin-bottom: 4px; }

        /* ── Color preview ── */
        .color-preview-card {
            margin-top: 20px;
            border: 1px solid rgba(0,212,255,.15);
            border-radius: 16px;
            overflow: hidden;
        }
        .cpv-label {
            font-size: 10px; letter-spacing: 2px; text-transform: uppercase;
            color: rgba(100,116,139,.6); padding: 10px 14px 0;
        }
        .cpv-body {
            padding: 20px;
            display: flex; flex-direction: column; align-items: center; gap: 12px;
        }
        #preview-card {
            background: rgba(255,255,255,.04);
            border-radius: 14px;
            padding: 24px 28px;
            width: 100%; max-width: 320px;
            text-align: center;
            transition: all .3s;
        }
        #preview-title { font-size: 16px; font-weight: 700; color: #fff; margin-bottom: 12px; }
        #preview-input {
            width: 100%;
            background: rgba(255,255,255,.06);
            border-radius: 8px;
            padding: 8px 12px;
            color: #fff; font-size: 12px;
            margin-bottom: 10px;
            border: 1px solid rgba(255,255,255,.1);
        }
        #preview-btn {
            width: 100%;
            padding: 9px;
            border: none;
            border-radius: 8px;
            color: #fff;
            font-size: 11px; font-weight: 700; letter-spacing: 2px; text-transform: uppercase;
            cursor: default;
        }
        #preview-link { font-size: 10px; margin-top: 6px; }

        /* ── Preset swatches ── */
        .presets { display: flex; flex-wrap: wrap; gap: 8px; margin-top: 14px; }
        .swatch {
            width: 32px; height: 32px;
            border-radius: 8px;
            border: 2px solid rgba(255,255,255,.1);
            cursor: pointer;
            transition: transform .15s, border-color .15s;
        }
        .swatch:hover { transform: scale(1.15); border-color: rgba(255,255,255,.3); }

        /* ── User cards ── */
        .user-card {
            background: rgba(255,255,255,.04);
            border: 1px solid rgba(0,212,255,.12);
            border-radius: 12px;
            padding: 14px 16px;
            display: flex; align-items: center; gap: 12px;
            flex-wrap: wrap;
            margin-bottom: 10px;
            transition: border-color .2s;
        }
        .user-card:hover { border-color: rgba(0,212,255,.28); }
        .user-info { flex: 1; min-width: 120px; }
        .user-email { font-size: 13px; font-weight: 600; color: #fff; }
        .user-meta { font-size: 11px; color: rgba(148,163,184,.6); margin-top: 2px; }
        .badge {
            font-size: 10px; padding: 3px 8px; border-radius: 50px;
            font-weight: 700; letter-spacing: 1px; text-transform: uppercase;
        }
        .badge-active  { background: rgba(34,197,94,.15); color: #4ade80; border: 1px solid rgba(34,197,94,.25); }
        .badge-expired { background: rgba(248,113,113,.12); color: #f87171; border: 1px solid rgba(248,113,113,.2); }
        .badge-banned  { background: rgba(239,68,68,.15); color: #ef4444; border: 1px solid rgba(239,68,68,.3); }
        .badge-admin   { background: rgba(251,191,36,.12); color: #fbbf24; border: 1px solid rgba(251,191,36,.2); }
        .badge-none    { background: rgba(100,116,139,.1); color: rgba(148,163,184,.6); border: 1px solid rgba(100,116,139,.2); }

        /* ── Stats ── */
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
            gap: 14px;
            margin-bottom: 24px;
        }
        .stat-box {
            background: rgba(255,255,255,.04);
            border: 1px solid rgba(0,212,255,.12);
            border-radius: 14px;
            padding: 18px;
            text-align: center;
        }
        .stat-num { font-size: 28px; font-weight: 900; color: var(--p); margin-bottom: 4px; }
        .stat-lbl { font-size: 11px; letter-spacing: 1.5px; text-transform: uppercase; color: rgba(148,163,184,.6); }

        /* ── Revenue table ── */
        .rev-table { width: 100%; border-collapse: collapse; font-size: 12px; }
        .rev-table th {
            text-align: left; padding: 8px 12px;
            color: rgba(148,163,184,.5);
            font-size: 10px; letter-spacing: 1.5px; text-transform: uppercase;
            border-bottom: 1px solid rgba(0,212,255,.1);
        }
        .rev-table td {
            padding: 10px 12px;
            border-bottom: 1px solid rgba(255,255,255,.04);
            color: rgba(148,163,184,.8);
        }
        .rev-table tr:hover td { background: rgba(0,212,255,.04); }
        .rev-amount { color: #4ade80; font-weight: 700; }

        /* ── Search ── */
        .search-row { display: flex; gap: 10px; margin-bottom: 16px; }
        .search-row input { flex: 1; }

        /* ── VAPID ── */
        .vapid-key {
            font-family: monospace;
            font-size: 11px;
            background: rgba(0,212,255,.06);
            border: 1px solid rgba(0,212,255,.15);
            border-radius: 8px;
            padding: 10px 12px;
            color: var(--p);
            word-break: break-all;
            margin-top: 8px;
        }

        /* ── Footer ── */
        .footer {
            margin-top: 20px;
            display: flex; flex-wrap: wrap; gap: 8px 16px;
            justify-content: center;
        }
        .footer a {
            font-size: 11px; letter-spacing: 1px; text-transform: uppercase;
            color: rgba(148,163,184,.5); text-decoration: none;
            transition: color .2s;
        }
        .footer a:hover { color: var(--p); }
        .footer-note {
            width: 100%; text-align: center;
            font-size: 10px; color: rgba(100,116,139,.4);
            letter-spacing: 2px; text-transform: uppercase;
            margin-top: 6px;
        }

        /* ── Animations ── */
        @keyframes fadeD { from{opacity:0;transform:translateY(-12px)}to{opacity:1;transform:translateY(0)} }
        @keyframes popI { from{opacity:0;transform:scale(.92) translateY(10px)}to{opacity:1;transform:scale(1) translateY(0)} }

        @media (max-width: 520px) {
            .card { padding: 20px 14px; }
            .tab-btn { font-size: 10px; padding: 6px 12px; }
        }
    </style>
</head>
<body>
<canvas id="sa-canvas"></canvas>

<div class="page">

    <!-- Header -->
    <div class="hdr">
        <h1>⚙ SUPER ADMIN</h1>
        <div class="hdr-sub">XCASPER Hosting — Deployer Control Panel</div>
        <form method="POST" action="/super-admin/lock" style="display:inline;">
            @csrf
            <button type="submit" class="btn-lock">lock &amp; exit</button>
        </form>
    </div>

    <div class="card">

        @if(session('success'))
            <div class="alert-ok">✓ {{ session('success') }}</div>
        @endif

        <!-- ── Tabs ── -->
        <div class="tabs" id="tabBar">
            <button class="tab-btn active" data-tab="branding">🎨 Branding</button>
            <button class="tab-btn" data-tab="appearance">🖼 Appearance</button>
            <button class="tab-btn" data-tab="email">✉ Email</button>
            <button class="tab-btn" data-tab="billing">💳 Billing</button>
            <button class="tab-btn" data-tab="users">👤 Users</button>
            <button class="tab-btn" data-tab="revenue">📊 Revenue</button>
            <button class="tab-btn" data-tab="push">🔔 Push</button>
            <button class="tab-btn" data-tab="docs">📖 Docs</button>
            <button class="tab-btn" data-tab="support">🛠 Support</button>
        </div>

        {{-- ══════════════════════════════════════════════════════════════
             BRANDING TAB
        ══════════════════════════════════════════════════════════════ --}}
        <div class="tab-panel active" id="tab-branding">
            <div class="sec-title">App Identity &amp; Branding</div>

            <div class="info-box">
                These settings control how your panel <strong>identifies itself</strong> — the name users see in their browser tab, the tagline on the login page, and the prefix in the server terminal.
                Changes take effect <strong>immediately</strong> on the next page load; no rebuild required.
            </div>

            <form method="POST" action="/super-admin" id="form-branding">
                @csrf
                <div class="fg">
                    <div class="f">
                        <label>App Name</label>
                        <input type="text" name="app_name" value="{{ $config['app_name'] }}" placeholder="XCASPER Hosting">
                        <span class="hint">Shown in the browser tab and top of the login page. Keep it short — ideally ≤ 20 characters.</span>
                    </div>
                    <div class="f">
                        <label>Tagline</label>
                        <input type="text" name="tagline" value="{{ $config['tagline'] }}" placeholder="we believe in building together">
                        <span class="hint">The italic line beneath the logo on login &amp; register pages. Should be inspiring and brief (≤ 50 chars).</span>
                    </div>
                    <div class="f">
                        <label>Terminal / Container Name</label>
                        <input type="text" name="terminal_name" value="{{ $config['terminal_name'] }}" placeholder="xcasper">
                        <span class="hint">The prefix in the server console. Displays as <code>container@xcasper~</code>. Lowercase alphanumeric only, no spaces.</span>
                    </div>
                    <div class="f">
                        <label>Logo URL <em style="color:rgba(100,116,139,.5);font-style:normal;">(optional)</em></label>
                        <input type="url" name="logo_url" value="{{ $config['logo_url'] }}" placeholder="https://example.com/logo.svg">
                        <span class="hint">A custom logo shown on login/register pages. Must be a public HTTPS URL. Supports PNG, SVG, WebP. Leave empty to use the built-in XCASPER animated SVG logo.</span>
                    </div>
                </div>

                <!-- Hidden colour inputs so save() always gets them even from the Branding tab -->
                <input type="hidden" name="primary_color" value="{{ $config['primary_color'] }}">
                <input type="hidden" name="accent_color"  value="{{ $config['accent_color'] }}">
                <input type="hidden" name="bg_color"      value="{{ $config['bg_color'] }}">
                <input type="hidden" name="bg_image_url"  value="{{ $config['bg_image_url'] }}">

                <button type="submit" class="btn-save">Save Branding</button>
            </form>
        </div>

        {{-- ══════════════════════════════════════════════════════════════
             APPEARANCE TAB — Colors + Background
        ══════════════════════════════════════════════════════════════ --}}
        <div class="tab-panel" id="tab-appearance">
            <div class="sec-title">Colours &amp; Background</div>

            <form method="POST" action="/super-admin" id="form-appearance">
                @csrf

                <!-- Hidden branding so save() always preserves them -->
                <input type="hidden" name="app_name"      value="{{ $config['app_name'] }}">
                <input type="hidden" name="tagline"       value="{{ $config['tagline'] }}">
                <input type="hidden" name="terminal_name" value="{{ $config['terminal_name'] }}">
                <input type="hidden" name="logo_url"      value="{{ $config['logo_url'] }}">

                <!-- ── Colour pickers ── -->
                <div class="info-box">
                    <strong>What changes immediately after saving:</strong> Login &amp; register page buttons, card borders, card glow, floating particles, input focus rings, footer link hovers, the animated Casper background, and email templates.<br><br>
                    <strong>What requires a panel rebuild to update:</strong> The main dashboard &amp; server console interface (NavigationBar, server cards, console buttons). These colours are compiled into the JavaScript bundle. Contact your developer or rebuild the panel to propagate changes there.
                </div>

                <div class="fg">
                    <div class="f">
                        <label>Primary Colour</label>
                        <input type="color" name="primary_color" id="cp-primary" value="{{ $config['primary_color'] }}">
                        <span class="hint">Main brand colour — login button start, card border glow, input focus, footer link hover, animated sparkles, email CTA start. Default: <code>#00D4FF</code> (cyan)</span>
                    </div>
                    <div class="f">
                        <label>Accent / Gradient Colour</label>
                        <input type="color" name="accent_color" id="cp-accent" value="{{ $config['accent_color'] }}">
                        <span class="hint">Secondary gradient colour — login button end, welcome card glow, email CTA end. Default: <code>#7C3AED</code> (purple)</span>
                    </div>
                    <div class="f">
                        <label>Background Colour</label>
                        <input type="color" name="bg_color" id="cp-bg" value="{{ $config['bg_color'] }}">
                        <span class="hint">Base canvas background colour. Used as the HTML body colour and the gradient base for the Casper animation. Default: <code>#050D1F</code> (deep navy)</span>
                    </div>
                </div>

                <!-- ── Live preview ── -->
                <div class="color-preview-card">
                    <div class="cpv-label">Live preview — login card</div>
                    <div class="cpv-body">
                        <div id="preview-card">
                            <div id="preview-title">Login to Continue</div>
                            <input id="preview-input" type="text" value="username@gmail.com" readonly>
                            <button id="preview-btn">Login</button>
                            <div id="preview-link" style="color:rgba(148,163,184,.5);">Forgot Password?</div>
                        </div>
                    </div>
                </div>

                <!-- ── Presets ── -->
                <p style="font-size:12px;color:rgba(100,116,139,.7);margin-top:18px;margin-bottom:8px;">Quick colour presets:</p>
                <div class="presets" id="presets"></div>

                <!-- ── Background section ── -->
                <div class="sec-gap">
                    <div class="sec-title">Background Override</div>
                </div>

                <div class="info-box">
                    By default the background is an <strong>animated HTML5 canvas</strong> drawing the friendly XCASPER Casper ghost with floating particles and stars. You can replace it with any static image by entering a URL below.
                    Leave the field empty to restore the animated Casper background.
                </div>

                <div class="f">
                    <label>Background Image URL <em style="color:rgba(100,116,139,.5);font-style:normal;">(optional)</em></label>
                    <input type="url" name="bg_image_url" id="bg-url" value="{{ $config['bg_image_url'] }}" placeholder="https://example.com/background.jpg">
                    <span class="hint">Supports JPG, PNG, WebP, GIF. Must be a public HTTPS URL. The image is fixed-position and covers the full viewport. Leave empty for the animated Casper canvas.</span>
                </div>
                <div id="bg-preview" style="margin-top:12px;border-radius:12px;overflow:hidden;{{ $config['bg_image_url'] ? '' : 'display:none' }}">
                    <img id="bg-img-prev" src="{{ $config['bg_image_url'] }}" alt="Background preview" style="width:100%;max-height:160px;object-fit:cover;border-radius:12px;">
                </div>

                <button type="submit" class="btn-save">Save Appearance</button>
            </form>
        </div>

        {{-- ══════════════════════════════════════════════════════════════
             EMAIL TAB
        ══════════════════════════════════════════════════════════════ --}}
        <div class="tab-panel" id="tab-email">
            <div class="sec-title">SMTP Mail Settings</div>

            <div class="info-box">
                XCASPER sends transactional emails for <strong>account verification</strong>, <strong>password resets</strong>, and <strong>billing reminders</strong>. Configure your SMTP provider here. Brevo (formerly Sendinblue) is recommended — free tier allows 300 emails/day.
            </div>

            <form method="POST" action="/super-admin/email" id="form-email">
                @csrf
                <div class="fg">
                    <div class="f">
                        <label>SMTP Host</label>
                        <input type="text" name="mail_host" value="{{ $mailConfig['host'] }}" placeholder="smtp-relay.brevo.com">
                        <span class="hint">Your mail provider's SMTP server. Examples: <code>smtp-relay.brevo.com</code> · <code>smtp.gmail.com</code> · <code>smtp.mailgun.org</code></span>
                    </div>
                    <div class="f">
                        <label>SMTP Port</label>
                        <input type="number" name="mail_port" value="{{ $mailConfig['port'] }}" placeholder="587" min="1" max="65535">
                        <span class="hint">Usually <code>587</code> for STARTTLS, <code>465</code> for SSL, or <code>25</code> for plain (not recommended).</span>
                    </div>
                    <div class="f">
                        <label>Encryption</label>
                        <select name="mail_encryption">
                            <option value="tls" {{ $mailConfig['encryption'] === 'tls' ? 'selected' : '' }}>TLS (STARTTLS — port 587)</option>
                            <option value="ssl" {{ $mailConfig['encryption'] === 'ssl' ? 'selected' : '' }}>SSL — port 465</option>
                            <option value="" {{ empty($mailConfig['encryption']) ? 'selected' : '' }}>None — not recommended</option>
                        </select>
                        <span class="hint">Encryption method for the SMTP connection. TLS is standard for most providers.</span>
                    </div>
                    <div class="f">
                        <label>SMTP Username</label>
                        <input type="text" name="mail_username" value="{{ $mailConfig['username'] }}" placeholder="your-smtp-login@example.com">
                        <span class="hint">The login name / API key used to authenticate with your SMTP provider.</span>
                    </div>
                    <div class="f">
                        <label>SMTP Password</label>
                        <input type="password" name="mail_password" placeholder="Leave blank to keep current password">
                        <span class="hint">Your SMTP password or API token. Leave blank to keep the existing stored password.</span>
                    </div>
                    <div class="f">
                        <label>From Address</label>
                        <input type="email" name="mail_from_address" value="{{ $mailConfig['from_address'] }}" placeholder="no-reply@xcasper.space">
                        <span class="hint">All panel emails will appear to be sent from this address. Must be verified with your mail provider.</span>
                    </div>
                    <div class="f">
                        <label>From Name</label>
                        <input type="text" name="mail_from_name" value="{{ $mailConfig['from_name'] }}" placeholder="XCASPER Hosting">
                        <span class="hint">The display name shown in the recipient's inbox. E.g. <code>XCASPER Hosting</code></span>
                    </div>
                </div>

                <!-- Email Colour Theme -->
                <div class="sec-gap">
                    <div class="sec-title">Email Colour Theme</div>
                </div>

                <div class="info-box">
                    These colours are used in the <strong>HTML email templates</strong> sent by the panel (verification, password reset, billing reminders). They are independent of the app colours and can be customised separately.
                </div>

                <div class="fg">
                    <div class="f">
                        <label>Primary Colour</label>
                        <input type="color" name="email_primary" id="ep-primary" value="{{ $config['email_primary'] }}">
                        <span class="hint">Accent bar, "X" in logo, email button start, info box border</span>
                    </div>
                    <div class="f">
                        <label>Accent Colour</label>
                        <input type="color" name="email_accent" id="ep-accent" value="{{ $config['email_accent'] }}">
                        <span class="hint">"CASPER" in logo, button gradient end</span>
                    </div>
                    <div class="f">
                        <label>Body Background</label>
                        <input type="color" name="email_bg" id="ep-bg" value="{{ $config['email_bg'] }}">
                        <span class="hint">Email body / outer background colour</span>
                    </div>
                    <div class="f">
                        <label>Logo Badge Background</label>
                        <input type="color" name="email_card_bg" id="ep-card" value="{{ $config['email_card_bg'] }}">
                        <span class="hint">Background behind the XCASPER logo in the email header</span>
                    </div>
                    <div class="f">
                        <label>Button Text Colour</label>
                        <input type="color" name="email_btn_text" id="ep-btn-text" value="{{ $config['email_btn_text'] }}">
                        <span class="hint">Text colour on CTA buttons in the email</span>
                    </div>
                </div>

                <!-- Email preview -->
                <div style="margin-top:20px;">
                    <p style="font-size:11px;color:rgba(100,116,139,.7);letter-spacing:1px;text-transform:uppercase;margin-bottom:12px;">Email preview</p>
                    <div id="email-preview" style="border-radius:12px;overflow:hidden;font-family:Arial,sans-serif;font-size:13px;transition:all .3s;">
                        <div id="ep-outer" style="padding:24px;text-align:center;">
                            <div id="ep-badge" style="display:inline-block;padding:12px 20px;border-radius:10px;margin-bottom:14px;">
                                <span id="ep-x" style="font-size:18px;font-weight:900;letter-spacing:2px;">X</span><span id="ep-casper" style="font-size:18px;font-weight:900;letter-spacing:2px;">CASPER</span>
                            </div>
                            <div style="background:rgba(255,255,255,.05);border-radius:10px;padding:18px;">
                                <p style="color:#e2e8f0;margin-bottom:12px;">Your account verification link:</p>
                                <div id="ep-btn" style="display:inline-block;padding:10px 24px;border-radius:8px;font-weight:700;letter-spacing:1px;">Verify Email</div>
                            </div>
                        </div>
                    </div>
                </div>

                <button type="submit" class="btn-save">Save Email Settings</button>
            </form>
        </div>

        {{-- ══════════════════════════════════════════════════════════════
             BILLING TAB
        ══════════════════════════════════════════════════════════════ --}}
        <div class="tab-panel" id="tab-billing">
            <div class="sec-title">Paystack Payment Integration</div>

            <div class="info-box">
                XCASPER uses <strong>Paystack</strong> for KES billing. Users pay for hosting plans (Basic KES 50/mo, Pro KES 100/mo) and top up their wallets for auto-renewal.<br><br>
                <strong>Where to find your keys:</strong> Log in to <a href="https://dashboard.paystack.com" target="_blank" style="color:var(--p);">dashboard.paystack.com</a> → Settings → API Keys &amp; Webhooks.<br><br>
                <strong>Test vs Live:</strong> Use <code>pk_test_…</code> / <code>sk_test_…</code> for development (no real money moved). Use <code>pk_live_…</code> / <code>sk_live_…</code> for production.
            </div>

            <form method="POST" action="/super-admin/billing" id="form-billing">
                @csrf
                <div class="fg">
                    <div class="f">
                        <label>Paystack Public Key</label>
                        <input type="text" name="paystack_public_key" value="{{ $config['paystack_public_key'] }}" placeholder="pk_live_…">
                        <span class="hint">Safe to expose to browsers. Used to initialise the Paystack checkout popup on the dashboard.</span>
                    </div>
                    <div class="f">
                        <label>Paystack Secret Key</label>
                        <input type="password" name="paystack_secret_key" value="{{ $config['paystack_secret_key'] }}" placeholder="sk_live_…" autocomplete="off">
                        <span class="hint"><strong style="color:#f87171;">NEVER share this key.</strong> Used server-side only to verify payments and manage subscriptions.</span>
                    </div>
                    <div class="f">
                        <label>Admin Server Limit</label>
                        <input type="text" name="admin_server_limit" value="{{ $config['admin_server_limit'] }}" placeholder="unlimited">
                        <span class="hint">Max servers for Admin-plan users. Enter <code>unlimited</code> for no limit, or a number like <code>10</code>.</span>
                    </div>
                </div>
                <button type="submit" class="btn-save">Save Billing Keys</button>
            </form>

            <!-- ── Server Resource Limits ── -->
            <div class="sec-gap">
                <div class="sec-title">Server Resource Limits Per Plan</div>
            </div>

            <div class="info-box">
                These limits apply when a user purchases a plan and a server is automatically created for them.
                RAM <code>0</code> = <strong>unlimited</strong>. Disk is in MB (5120 = 5 GB). CPU is as a percentage of one core (100 = 1 core, 200 = 2 cores).
            </div>

            <form method="POST" action="/super-admin/save-server-config" id="form-servers">
                @csrf
                <div class="fg">
                    <div class="f" style="grid-column:1/-1">
                        <label>Default Node ID</label>
                        <input type="number" name="default_node_id" value="{{ $config['default_node_id'] }}" placeholder="1" min="1">
                        <span class="hint">The Pterodactyl <strong>node</strong> where new servers are deployed. Find the ID in Admin Panel → Nodes → click a node → look at the URL: <code>/admin/nodes/<strong>3</strong>/settings</code>.</span>
                    </div>
                    <div class="f" style="grid-column:1/-1">
                        <label>Default Egg ID</label>
                        <input type="number" name="default_egg_id" value="{{ $config['default_egg_id'] }}" placeholder="3" min="1">
                        <span class="hint">The server <strong>egg</strong> (template) used when creating billing servers. Find it in Admin → Nests → Eggs → click an egg → URL: <code>/admin/nests/1/eggs/<strong>5</strong></code>.</span>
                    </div>
                </div>

                <div style="margin-top:16px;">
                    <p style="font-size:11px;font-weight:700;letter-spacing:1.5px;text-transform:uppercase;color:var(--p);margin-bottom:12px;">🟢 Basic Plan — KES 50/mo</p>
                    <div class="fg">
                        <div class="f"><label>RAM (MB)</label><input type="number" name="basic_memory_mb" value="{{ $config['basic_memory_mb'] }}" placeholder="512" min="0"><span class="hint">0 = unlimited. 512 = 512 MB RAM.</span></div>
                        <div class="f"><label>Disk (MB)</label><input type="number" name="basic_disk_mb" value="{{ $config['basic_disk_mb'] }}" placeholder="5120" min="0"><span class="hint">5120 = 5 GB. 10240 = 10 GB.</span></div>
                        <div class="f"><label>CPU (%)</label><input type="number" name="basic_cpu_pct" value="{{ $config['basic_cpu_pct'] }}" placeholder="50" min="0"><span class="hint">50 = half a core. 100 = 1 core. 0 = unlimited.</span></div>
                    </div>
                </div>

                <div style="margin-top:16px;">
                    <p style="font-size:11px;font-weight:700;letter-spacing:1.5px;text-transform:uppercase;color:#a78bfa;margin-bottom:12px;">🔵 Pro Plan — KES 100/mo</p>
                    <div class="fg">
                        <div class="f"><label>RAM (MB)</label><input type="number" name="pro_memory_mb" value="{{ $config['pro_memory_mb'] }}" placeholder="2048" min="0"><span class="hint">0 = unlimited.</span></div>
                        <div class="f"><label>Disk (MB)</label><input type="number" name="pro_disk_mb" value="{{ $config['pro_disk_mb'] }}" placeholder="20480" min="0"><span class="hint">20480 = 20 GB.</span></div>
                        <div class="f"><label>CPU (%)</label><input type="number" name="pro_cpu_pct" value="{{ $config['pro_cpu_pct'] }}" placeholder="100" min="0"></div>
                    </div>
                </div>

                <div style="margin-top:16px;">
                    <p style="font-size:11px;font-weight:700;letter-spacing:1.5px;text-transform:uppercase;color:#fbbf24;margin-bottom:12px;">👑 Admin Plan — KES 200/mo</p>
                    <div class="fg">
                        <div class="f"><label>RAM (MB)</label><input type="number" name="admin_memory_mb" value="{{ $config['admin_memory_mb'] }}" placeholder="4096" min="0"></div>
                        <div class="f"><label>Disk (MB)</label><input type="number" name="admin_disk_mb" value="{{ $config['admin_disk_mb'] }}" placeholder="51200" min="0"><span class="hint">51200 = 50 GB.</span></div>
                        <div class="f"><label>CPU (%)</label><input type="number" name="admin_cpu_pct" value="{{ $config['admin_cpu_pct'] }}" placeholder="200" min="0"></div>
                    </div>
                </div>

                <button type="submit" class="btn-save">Save Server Config</button>
            </form>
        </div>

        {{-- ══════════════════════════════════════════════════════════════
             USERS TAB
        ══════════════════════════════════════════════════════════════ --}}
        <div class="tab-panel" id="tab-users">
            <div class="sec-title">User Management</div>

            <div class="info-box">
                Search for any registered user and <strong>ban</strong>, <strong>unban</strong>, <strong>force-delete</strong>, or <strong>grant a plan + wallet credit</strong>. Banning prevents the user from logging in. Force-delete permanently removes all user data including billing records.
            </div>

            <div class="search-row">
                <div class="f" style="flex:1">
                    <input type="text" id="u-search" placeholder="Search email or username…">
                </div>
                <button class="btn-sm" onclick="searchUsers()">Search</button>
            </div>

            <div id="u-results" style="min-height:80px;">
                <p style="color:rgba(148,163,184,.4);font-size:13px;text-align:center;padding:24px 0;">Enter a search term above to find users</p>
            </div>

            <!-- Grant plan modal -->
            <div id="grant-form" style="display:none;margin-top:20px;background:rgba(0,212,255,.05);border:1px solid rgba(0,212,255,.15);border-radius:14px;padding:20px;">
                <p style="font-size:12px;font-weight:700;letter-spacing:1.5px;text-transform:uppercase;color:var(--p);margin-bottom:14px;">Grant Plan to <span id="grant-email" style="color:#fff;"></span></p>
                <input type="hidden" id="grant-uid">
                <div class="fg">
                    <div class="f">
                        <label>Plan</label>
                        <select id="grant-plan">
                            <option value="basic">Basic — KES 50/mo</option>
                            <option value="pro">Pro — KES 100/mo</option>
                            <option value="admin">Admin — KES 200/mo</option>
                        </select>
                    </div>
                    <div class="f">
                        <label>Duration (days)</label>
                        <input type="number" id="grant-days" value="30" min="1" max="365">
                    </div>
                    <div class="f">
                        <label>Wallet Credit (KES)</label>
                        <input type="number" id="grant-wallet" value="0" min="0" step="1">
                        <span class="hint">Optional: top up the user's KES wallet at the same time.</span>
                    </div>
                </div>
                <div style="display:flex;gap:10px;margin-top:14px;">
                    <button class="btn-sm" onclick="submitGrant()">Grant Plan</button>
                    <button class="btn-sm" onclick="document.getElementById('grant-form').style.display='none'" style="background:rgba(100,116,139,.2);color:#94a3b8;">Cancel</button>
                </div>
            </div>
        </div>

        {{-- ══════════════════════════════════════════════════════════════
             REVENUE TAB
        ══════════════════════════════════════════════════════════════ --}}
        <div class="tab-panel" id="tab-revenue">
            <div class="sec-title">Revenue &amp; Platform Analytics</div>
            <div id="rev-loading" style="text-align:center;padding:40px 0;color:rgba(148,163,184,.5);">Loading stats…</div>
            <div id="rev-content" style="display:none;">
                <div class="stats-grid" id="rev-stats"></div>
                <div id="rev-plan-section" style="margin-bottom:24px;"></div>
                <div class="sec-title">Recent Successful Transactions</div>
                <div style="overflow-x:auto;">
                    <table class="rev-table">
                        <thead>
                            <tr>
                                <th>User</th>
                                <th>Plan</th>
                                <th>Amount</th>
                                <th>Reference</th>
                                <th>Date</th>
                            </tr>
                        </thead>
                        <tbody id="rev-tbody"></tbody>
                    </table>
                </div>
            </div>
        </div>

        {{-- ══════════════════════════════════════════════════════════════
             PUSH NOTIFICATIONS TAB
        ══════════════════════════════════════════════════════════════ --}}
        <div class="tab-panel" id="tab-push">
            <div class="sec-title">Web Push Notifications (VAPID)</div>

            <div class="info-box">
                XCASPER supports <strong>browser push notifications</strong> using the Web Push standard (VAPID).
                Users can opt-in to receive alerts for server status changes, billing renewals, and announcements — even when the panel is not open in their browser.<br><br>
                Click <strong>Generate VAPID Keys</strong> to create a new key pair. The <em>public key</em> is shared with browsers. The <em>private key</em> stays on the server and is never exposed.<br><br>
                <span style="color:#fbbf24;">⚠ Regenerating keys will <strong>invalidate all existing push subscriptions</strong>. Users will need to re-enable notifications.</span>
            </div>

            @if($config['vapid_public_key'])
                <div class="f" style="margin-bottom:16px;">
                    <label>Current VAPID Public Key</label>
                    <div class="vapid-key">{{ $config['vapid_public_key'] }}</div>
                    <span class="hint">This key is registered in browsers when users subscribe to notifications.</span>
                </div>
            @else
                <div class="info-box warn">
                    <strong>No VAPID keys found.</strong> Push notifications are disabled until you generate keys.
                </div>
            @endif

            <div id="new-vapid-key" style="display:none;margin-bottom:16px;">
                <div class="f">
                    <label>New VAPID Public Key</label>
                    <div class="vapid-key" id="vapid-pub-display">—</div>
                    <span class="hint" style="color:#4ade80;">✓ Keys saved. All users will need to re-subscribe to notifications.</span>
                </div>
            </div>

            <button class="btn-sm" onclick="generateVapid()" id="btn-vapid">
                {{ $config['vapid_public_key'] ? '🔄 Regenerate VAPID Keys' : '🔑 Generate VAPID Keys' }}
            </button>
        </div>

        {{-- ══════════════════════════════════════════════════════════════
             DOCS TAB
        ══════════════════════════════════════════════════════════════ --}}
        <div class="tab-panel" id="tab-docs">
            <div class="sec-title">Panel Documentation &amp; Setup Guide</div>

            <div class="doc-section">
                <h3>🎨 Branding</h3>
                <p>Set your panel's <strong>App Name</strong> (shown in browser tabs), <strong>Tagline</strong> (the line beneath the logo on the login page), and <strong>Terminal Name</strong> (the prefix in the server console, e.g. <code>container@xcasper~</code>). You can also point the <strong>Logo URL</strong> to a custom image — leave it empty to use the default XCASPER animated SVG logo.</p>
                <p style="margin-top:8px;">All branding changes take effect immediately on the next page load — no restart or rebuild needed.</p>
            </div>

            <div class="doc-section">
                <h3>🖼 Appearance — Colours</h3>
                <p>Three colour values control the visual theme:</p>
                <ul>
                    <li><strong>Primary Colour</strong> — The main brand colour. Affects: login/register button gradient start, card border glow, floating particle colours, input focus rings, footer link hover, animated sparkles on the Casper canvas, and email template CTA button start colour.</li>
                    <li><strong>Accent Colour</strong> — The secondary gradient end colour. Affects: button gradient end, welcome popup glow, email logo CASPER text.</li>
                    <li><strong>Background Colour</strong> — The base canvas colour. Affects: the HTML body background and the gradient sky in the Casper animation.</li>
                </ul>
                <p style="margin-top:8px;"><strong>Login &amp; register pages</strong> react to colour changes immediately after saving. The <strong>main dashboard and server console</strong> use colours that are compiled into the JavaScript bundle — changes require a panel rebuild to take effect there.</p>
            </div>

            <div class="doc-section">
                <h3>✉ Email — SMTP Setup</h3>
                <p>XCASPER sends emails for account verification, password resets, and billing reminders. You need an SMTP provider. Recommended options:</p>
                <ul>
                    <li><strong>Brevo</strong> (formerly Sendinblue) — Free tier: 300 emails/day. Host: <code>smtp-relay.brevo.com</code>, Port: <code>587</code>, Encryption: <code>TLS</code>.</li>
                    <li><strong>Mailgun</strong> — Reliable, generous free tier. Host varies by region.</li>
                    <li><strong>Gmail SMTP</strong> — Works but has rate limits. Requires an App Password (not your regular password) if 2FA is enabled.</li>
                </ul>
                <p style="margin-top:8px;">After saving SMTP settings, send a test email from the Pterodactyl admin panel (Settings → Mail) to confirm delivery.</p>
            </div>

            <div class="doc-section">
                <h3>💳 Billing — Paystack</h3>
                <p>Sign up or log in at <a href="https://dashboard.paystack.com" target="_blank" style="color:var(--p);">dashboard.paystack.com</a>. Go to <strong>Settings → API Keys &amp; Webhooks</strong>. Copy the <strong>Public Key</strong> and <strong>Secret Key</strong> and paste them here.</p>
                <p style="margin-top:8px;"><strong>Test mode</strong>: Use <code>pk_test_…</code> and <code>sk_test_…</code> keys. No real money is charged. Test card: <code>4084 0840 8408 4081</code>, any future expiry, any CVV.</p>
                <p style="margin-top:8px;"><strong>Live mode</strong>: Switch to <code>pk_live_…</code> and <code>sk_live_…</code> keys when you're ready to accept real KES payments.</p>
            </div>

            <div class="doc-section">
                <h3>🖥 Server Resource Limits</h3>
                <p>When a user purchases a plan, the system automatically creates a server on the configured <strong>Node</strong> using the configured <strong>Egg</strong> (template). The resource limits you set here are applied to that server.</p>
                <ul>
                    <li><strong>Node ID</strong>: Find it in the Pterodactyl Admin Panel → Nodes → click a node → the number in the URL: <code>/admin/nodes/<strong>1</strong>/settings</code></li>
                    <li><strong>Egg ID</strong>: Admin → Nests → Eggs → click an egg → URL: <code>/admin/nests/1/eggs/<strong>3</strong></code></li>
                    <li><strong>RAM = 0</strong> means unlimited. <strong>Disk</strong> is in MB (5120 = 5 GB). <strong>CPU</strong> is as a % of one core (100 = 1 full core).</li>
                </ul>
            </div>

            <div class="doc-section">
                <h3>👤 User Management</h3>
                <p>From the <strong>Users</strong> tab you can:</p>
                <ul>
                    <li><strong>Search</strong> by email or username</li>
                    <li><strong>Ban</strong> — blocks the user from logging in. The account and data are kept.</li>
                    <li><strong>Unban</strong> — restores access.</li>
                    <li><strong>Grant Plan</strong> — manually assign a plan + optional wallet credit. Useful for gifting plans, resolving payment issues, or testing billing flows.</li>
                    <li><strong>Force Delete</strong> — permanently removes the user account and all associated billing/transaction records. Irreversible.</li>
                </ul>
            </div>

            <div class="doc-section">
                <h3>🔔 Push Notifications (VAPID)</h3>
                <p>Browser push notifications use the <strong>Web Push</strong> standard. Click <em>Generate VAPID Keys</em> in the Push tab once — the keys are saved to the server config automatically. Users can then enable push notifications from their browser when prompted by the panel.</p>
                <p style="margin-top:8px;color:#fbbf24;">⚠ Regenerating keys invalidates all existing subscriptions. Only do this if your private key is compromised.</p>
            </div>

            <div class="doc-section">
                <h3>🔑 Super Admin Key</h3>
                <p>The super-admin panel is protected by a master key (the <code>XCASPER_SUPER_KEY</code> environment variable, default: <code>CasperXK-2025</code>). Change this key in your <code>.env</code> file on the server:</p>
                <div class="vapid-key" style="color:#e2e8f0;background:rgba(255,255,255,.04);">XCASPER_SUPER_KEY=your-new-secret-key-here</div>
                <p style="margin-top:8px;">After changing, run <code>php artisan config:clear</code> on the server for the change to take effect. The panel is at <code>/super-admin</code>.</p>
            </div>
        </div>

        {{-- ══════════════════════════════════════════════════════════════
             SUPPORT TAB
        ══════════════════════════════════════════════════════════════ --}}
        <div class="tab-panel" id="tab-support">
            <div class="sec-title">Developer &amp; Support Links</div>

            <div style="display:flex;flex-direction:column;gap:14px;">
                <div class="info-box">
                    <strong>GitHub</strong><br>
                    <a href="https://github.com/Casper-Tech-ke" target="_blank" rel="noopener" style="color:rgba(148,163,184,.8);text-decoration:none;">github.com/Casper-Tech-ke</a>
                    <br><span class="hint">Source code, issue tracker, and contributions. Star the repo if this panel is useful to you!</span>
                </div>

                <div class="info-box" style="border-color:rgba(124,58,237,.25);">
                    <strong style="color:var(--a);">Telegram Support</strong><br>
                    <a href="https://t.me/casper_tech_ke" target="_blank" rel="noopener" style="color:rgba(148,163,184,.8);text-decoration:none;">t.me/casper_tech_ke</a>
                    <br><span class="hint">Live support channel, announcements, and the XCASPER community. Message us for billing/panel issues.</span>
                </div>

                <div class="info-box" style="border-color:rgba(255,255,255,.1);">
                    <strong style="color:#94a3b8;">XCASPER Hosting Services</strong><br>
                    <a href="https://xcasper.space" target="_blank" rel="noopener" style="color:rgba(148,163,184,.8);text-decoration:none;">xcasper.space</a>
                    &nbsp;·&nbsp;
                    <a href="https://status.xcasper.space" target="_blank" rel="noopener" style="color:rgba(148,163,184,.8);text-decoration:none;">status.xcasper.space</a>
                    &nbsp;·&nbsp;
                    <a href="https://support.xcasper.space" target="_blank" rel="noopener" style="color:rgba(148,163,184,.8);text-decoration:none;">support.xcasper.space</a>
                    <br><span class="hint">Main website, uptime status page, and helpdesk.</span>
                </div>

                <div class="info-box" style="background:rgba(251,191,36,.05);border-color:rgba(251,191,36,.2);">
                    <strong style="color:#fbbf24;">A CASPER TECH KENYA DEVELOPERS Product</strong><br>
                    <span style="color:rgba(148,163,184,.7);font-size:13px;">Built with ❤ in Kenya · © {{ date('Y') }} Casper Tech Kenya. All rights reserved.</span>
                </div>
            </div>
        </div>

    </div><!-- /card -->

    <div class="footer">
        <a href="/" target="_blank">Panel ↗</a>
        <a href="https://xcasper.space" target="_blank">Website ↗</a>
        <a href="https://status.xcasper.space" target="_blank">Status ↗</a>
        <a href="https://t.me/casper_tech_ke" target="_blank">Telegram ↗</a>
    </div>
    <div class="footer-note">xcasper panel · a casper tech kenya product · {{ date('Y') }}</div>

</div><!-- /page -->

<script>
/* ── Tab switching ── */
const tabBtns    = document.querySelectorAll('.tab-btn');
const tabPanels  = document.querySelectorAll('.tab-panel');

function switchTab(id) {
    tabBtns.forEach(b => b.classList.toggle('active', b.dataset.tab === id));
    tabPanels.forEach(p => p.classList.toggle('active', p.id === 'tab-' + id));
    history.replaceState(null, '', '?tab=' + id);
    if (id === 'revenue') loadRevenue();
}

tabBtns.forEach(b => b.addEventListener('click', () => switchTab(b.dataset.tab)));

// Restore tab from URL
const urlTab = new URLSearchParams(location.search).get('tab');
if (urlTab) switchTab(urlTab);

/* ── CSRF token helper ── */
const CSRF = document.querySelector('meta[name="csrf-token"]').content;
function post(url, data) {
    data['_token'] = CSRF;
    return fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-CSRF-TOKEN': CSRF, 'Accept': 'application/json' },
        body: JSON.stringify(data),
    }).then(r => r.json());
}

/* ── Live colour preview ── */
const cpPrimary = document.getElementById('cp-primary');
const cpAccent  = document.getElementById('cp-accent');
const cpBg      = document.getElementById('cp-bg');
const prevCard  = document.getElementById('preview-card');
const prevBtn   = document.getElementById('preview-btn');
const prevLink  = document.getElementById('preview-link');

function updatePreview() {
    const p  = cpPrimary.value;
    const a  = cpAccent.value;
    const bg = cpBg.value;
    prevCard.style.border = `1px solid ${p}33`;
    prevCard.style.boxShadow = `0 0 24px ${p}22`;
    prevCard.style.background = `rgba(255,255,255,0.04)`;
    prevBtn.style.background = `linear-gradient(135deg, ${p}, ${a})`;
    prevLink.style.color = `${p}99`;
    document.getElementById('preview-input').style.borderColor = `${p}40`;
}
if (cpPrimary) {
    cpPrimary.addEventListener('input', updatePreview);
    cpAccent.addEventListener('input', updatePreview);
    cpBg.addEventListener('input', updatePreview);
    updatePreview();
}

/* ── Colour presets ── */
const PRESETS = [
    { p: '#00D4FF', a: '#7C3AED', bg: '#050D1F', label: 'XCASPER Cyan' },
    { p: '#10b981', a: '#059669', bg: '#022c22', label: 'Emerald' },
    { p: '#f59e0b', a: '#d97706', bg: '#1c0f00', label: 'Amber' },
    { p: '#ef4444', a: '#b91c1c', bg: '#1c0000', label: 'Red' },
    { p: '#8b5cf6', a: '#6d28d9', bg: '#0d0021', label: 'Violet' },
    { p: '#ec4899', a: '#be185d', bg: '#1c0010', label: 'Pink' },
    { p: '#06b6d4', a: '#0e7490', bg: '#001820', label: 'Teal' },
    { p: '#f97316', a: '#ea580c', bg: '#1c0800', label: 'Orange' },
];

const presetsEl = document.getElementById('presets');
if (presetsEl) {
    PRESETS.forEach(pre => {
        const s = document.createElement('button');
        s.type = 'button';
        s.className = 'swatch';
        s.title = pre.label;
        s.style.background = `linear-gradient(135deg, ${pre.p}, ${pre.a})`;
        s.addEventListener('click', () => {
            cpPrimary.value = pre.p;
            cpAccent.value  = pre.a;
            cpBg.value      = pre.bg;
            updatePreview();
        });
        presetsEl.appendChild(s);
    });
}

/* ── Background image preview ── */
const bgUrl = document.getElementById('bg-url');
const bgPrev = document.getElementById('bg-preview');
const bgImg  = document.getElementById('bg-img-prev');
if (bgUrl) {
    bgUrl.addEventListener('input', () => {
        const val = bgUrl.value.trim();
        bgPrev.style.display = val ? 'block' : 'none';
        if (val) bgImg.src = val;
    });
}

/* ── Email preview ── */
const epPrimary  = document.getElementById('ep-primary');
const epAccent   = document.getElementById('ep-accent');
const epBg       = document.getElementById('ep-bg');
const epCard     = document.getElementById('ep-card');
const epBtnText  = document.getElementById('ep-btn-text');
const epOuter    = document.getElementById('ep-outer');
const epBadge    = document.getElementById('ep-badge');
const epX        = document.getElementById('ep-x');
const epCasper   = document.getElementById('ep-casper');
const epBtn      = document.getElementById('ep-btn');

function updateEmailPreview() {
    if (!epPrimary) return;
    const p  = epPrimary.value;
    const a  = epAccent.value;
    const bg = epBg.value;
    const cb = epCard.value;
    const bt = epBtnText.value;
    epOuter.style.background = bg;
    epBadge.style.background = cb;
    epX.style.color = p;
    epCasper.style.color = a;
    epBtn.style.background = `linear-gradient(135deg, ${p}, ${a})`;
    epBtn.style.color = bt;
}
if (epPrimary) {
    [epPrimary, epAccent, epBg, epCard, epBtnText].forEach(el => el.addEventListener('input', updateEmailPreview));
    updateEmailPreview();
}

/* ── Users tab ── */
function searchUsers() {
    const q = document.getElementById('u-search').value.trim();
    const el = document.getElementById('u-results');
    el.innerHTML = '<p style="color:rgba(148,163,184,.4);font-size:13px;text-align:center;padding:20px 0;">Searching…</p>';
    fetch('/super-admin/users?q=' + encodeURIComponent(q), { headers: { 'Accept': 'application/json' } })
        .then(r => r.json())
        .then(data => renderUsers(data.users || []))
        .catch(() => { el.innerHTML = '<p style="color:#f87171;font-size:13px;text-align:center;padding:20px 0;">Error fetching users.</p>'; });
}
document.getElementById('u-search')?.addEventListener('keydown', e => { if (e.key === 'Enter') searchUsers(); });

function renderUsers(users) {
    const el = document.getElementById('u-results');
    if (!users.length) { el.innerHTML = '<p style="color:rgba(148,163,184,.4);font-size:13px;text-align:center;padding:24px 0;">No users found.</p>'; return; }
    el.innerHTML = users.map(u => {
        const planBadge = u.plan
            ? `<span class="badge ${u.status === 'active' ? 'badge-active' : 'badge-expired'}">${u.plan}</span>`
            : `<span class="badge badge-none">no plan</span>`;
        const adminBadge = u.root_admin ? `<span class="badge badge-admin">Admin</span>` : '';
        const bannedBadge = u.is_banned ? `<span class="badge badge-banned">Banned</span>` : '';
        const banBtn = u.is_banned
            ? `<button class="btn-sm" onclick="unban(${u.id})" style="background:rgba(34,197,94,.2);color:#4ade80;">Unban</button>`
            : `<button class="btn-sm" onclick="ban(${u.id})" style="background:rgba(239,68,68,.15);color:#f87171;">Ban</button>`;
        return `
        <div class="user-card" id="uc-${u.id}">
            <div class="user-info">
                <div class="user-email">${u.email}</div>
                <div class="user-meta">@${u.username} · ID: ${u.id} ${u.expires_at ? '· Expires: ' + u.expires_at.split(' ')[0] : ''}</div>
                <div style="margin-top:6px;display:flex;gap:5px;flex-wrap:wrap;">${planBadge} ${adminBadge} ${bannedBadge}</div>
            </div>
            <div style="display:flex;gap:6px;flex-wrap:wrap;align-items:center;">
                <button class="btn-sm" onclick="showGrant(${u.id},'${u.email}')">Grant Plan</button>
                ${banBtn}
                <button class="btn-sm btn-danger" onclick="forceDelete(${u.id},'${u.email}')">Delete</button>
            </div>
        </div>`;
    }).join('');
}

function showGrant(uid, email) {
    document.getElementById('grant-uid').value = uid;
    document.getElementById('grant-email').textContent = email;
    document.getElementById('grant-form').style.display = 'block';
    document.getElementById('grant-form').scrollIntoView({ behavior: 'smooth', block: 'nearest' });
}

function submitGrant() {
    const uid    = parseInt(document.getElementById('grant-uid').value);
    const plan   = document.getElementById('grant-plan').value;
    const days   = parseInt(document.getElementById('grant-days').value) || 30;
    const wallet = parseFloat(document.getElementById('grant-wallet').value) || 0;
    post('/super-admin/users/add-funds', { user_id: uid, plan, days, wallet_kes: wallet })
        .then(d => {
            alert(d.message || d.error || 'Done');
            document.getElementById('grant-form').style.display = 'none';
            searchUsers();
        });
}

function ban(uid) {
    const reason = prompt('Ban reason (shown to user):', 'Banned by administrator');
    if (reason === null) return;
    post('/super-admin/users/ban', { user_id: uid, reason })
        .then(d => { alert(d.message || d.error); searchUsers(); });
}

function unban(uid) {
    post('/super-admin/users/unban', { user_id: uid })
        .then(d => { alert(d.message || d.error); searchUsers(); });
}

function forceDelete(uid, email) {
    if (!confirm('PERMANENTLY delete ' + email + ' and all their billing data? This CANNOT be undone.')) return;
    post('/super-admin/users/force-delete', { user_id: uid })
        .then(d => { alert(d.message || d.error); searchUsers(); });
}

/* ── Revenue tab ── */
let revLoaded = false;
function loadRevenue() {
    if (revLoaded) return;
    fetch('/super-admin/revenue', { headers: { 'Accept': 'application/json' } })
        .then(r => r.json())
        .then(d => {
            revLoaded = true;
            document.getElementById('rev-loading').style.display = 'none';
            document.getElementById('rev-content').style.display = 'block';

            document.getElementById('rev-stats').innerHTML = `
                <div class="stat-box"><div class="stat-num">KES ${Number(d.total_revenue_kes).toLocaleString()}</div><div class="stat-lbl">Total Revenue</div></div>
                <div class="stat-box"><div class="stat-num">${d.total_users}</div><div class="stat-lbl">Registered Users</div></div>
                <div class="stat-box"><div class="stat-num">${d.active_billings}</div><div class="stat-lbl">Active Subscriptions</div></div>
            `;

            if (d.plan_breakdown && d.plan_breakdown.length) {
                document.getElementById('rev-plan-section').innerHTML = `
                    <div class="sec-title">Revenue By Plan</div>
                    <table class="rev-table">
                        <thead><tr><th>Plan</th><th>Transactions</th><th>Revenue (KES)</th></tr></thead>
                        <tbody>${d.plan_breakdown.map(p => `
                            <tr>
                                <td style="text-transform:capitalize;">${p.plan || '—'}</td>
                                <td>${p.count}</td>
                                <td class="rev-amount">KES ${Number(p.total).toLocaleString()}</td>
                            </tr>`).join('')}
                        </tbody>
                    </table>`;
            }

            const tbody = document.getElementById('rev-tbody');
            tbody.innerHTML = (d.recent || []).map(t => `
                <tr>
                    <td>${t.user}</td>
                    <td style="text-transform:capitalize;">${t.plan}</td>
                    <td class="rev-amount">KES ${Number(t.amount).toLocaleString()}</td>
                    <td><code>${t.reference}</code></td>
                    <td>${t.date}</td>
                </tr>`).join('') || '<tr><td colspan="5" style="text-align:center;color:rgba(148,163,184,.4);">No transactions yet</td></tr>';
        })
        .catch(() => {
            document.getElementById('rev-loading').textContent = 'Failed to load revenue data.';
        });
}

/* ── VAPID generation ── */
function generateVapid() {
    const btn = document.getElementById('btn-vapid');
    btn.textContent = 'Generating…';
    btn.disabled = true;
    fetch('/super-admin/vapid/generate', {
        method: 'POST',
        headers: { 'X-CSRF-TOKEN': CSRF, 'Accept': 'application/json', 'Content-Type': 'application/json' },
        body: JSON.stringify({ _token: CSRF }),
    })
    .then(r => r.json())
    .then(d => {
        if (d.success) {
            document.getElementById('vapid-pub-display').textContent = d.public_key;
            document.getElementById('new-vapid-key').style.display = 'block';
            btn.textContent = '🔄 Regenerate VAPID Keys';
            btn.disabled = false;
        } else {
            alert('Error: ' + (d.error || 'Unknown'));
            btn.textContent = '🔑 Generate VAPID Keys';
            btn.disabled = false;
        }
    })
    .catch(() => {
        alert('Network error. Try again.');
        btn.textContent = '🔑 Generate VAPID Keys';
        btn.disabled = false;
    });
}

/* ── Animated Casper canvas background ── */
(function () {
    const canvas = document.getElementById('sa-canvas');
    const ctx = canvas.getContext('2d');
    let W, H, t = 0;

    const stars = Array.from({length:120}, () => ({
        x: Math.random(), y: Math.random(),
        r: Math.random()*1.2+.2,
        s: Math.random()*.02+.004
    }));
    const particles = Array.from({length:25}, () => ({
        x: Math.random(), y: Math.random(),
        vx: (Math.random()-.5)*.00025, vy: (Math.random()-.5)*.00025,
        r: Math.random()*2+.8,
        alpha: Math.random()*.35+.07,
        hue: Math.random() > .5 ? 190 : 270
    }));

    function resize() { W = canvas.width = window.innerWidth; H = canvas.height = window.innerHeight; }
    window.addEventListener('resize', resize); resize();

    function drawCasper(cx, cy, scale, time) {
        const s = scale;
        ctx.save();
        ctx.translate(cx, cy + Math.sin(time * .7) * 10);

        const aura = ctx.createRadialGradient(0,-s*.1,s*.15,0,-s*.1,s*.9);
        aura.addColorStop(0,'rgba(0,212,255,0.13)');
        aura.addColorStop(.5,'rgba(124,58,237,0.06)');
        aura.addColorStop(1,'rgba(0,0,0,0)');
        ctx.beginPath(); ctx.ellipse(0,-s*.05,s*.85,s*.95,0,0,Math.PI*2);
        ctx.fillStyle = aura; ctx.fill();

        const bg = ctx.createLinearGradient(-s*.5,-s*.6,s*.4,s*.5);
        bg.addColorStop(0,'#dff4ff'); bg.addColorStop(.4,'#b8e8ff'); bg.addColorStop(1,'#8ac8e8');
        const w = Math.sin(time*.8)*s*.04;
        ctx.beginPath();
        ctx.moveTo(-s*.38,s*.2);
        ctx.bezierCurveTo(-s*.38,s*.38+w,-s*.22,s*.44+w,-s*.12,s*.38+w);
        ctx.bezierCurveTo(-s*.02,s*.32+w,s*.02,s*.5+w,s*.12,s*.4+w);
        ctx.bezierCurveTo(s*.22,s*.3+w,s*.26,s*.44+w,s*.38,s*.38+w);
        ctx.bezierCurveTo(s*.38,s*.2,s*.45,-s*.55,0,-s*.6);
        ctx.bezierCurveTo(-s*.45,-s*.55,-s*.38,0,-s*.38,s*.2);
        ctx.closePath(); ctx.fillStyle = bg; ctx.fill();
        ctx.strokeStyle='rgba(180,220,255,0.3)'; ctx.lineWidth=1.2; ctx.stroke();

        ctx.beginPath(); ctx.ellipse(-s*.1,-s*.25,s*.11,s*.2,-0.3,0,Math.PI*2);
        const sh = ctx.createRadialGradient(-s*.12,-s*.28,0,-s*.12,-s*.28,s*.18);
        sh.addColorStop(0,'rgba(255,255,255,0.58)'); sh.addColorStop(1,'rgba(255,255,255,0)');
        ctx.fillStyle = sh; ctx.fill();

        const eyeY = -s*.18;
        const blink = s*.13*(0.5+0.5*Math.abs(Math.sin(time*.3)));
        [-s*.15,s*.15].forEach(ex => {
            ctx.beginPath(); ctx.ellipse(ex,eyeY,s*.09,blink,0,0,Math.PI*2);
            ctx.fillStyle='#1a2744'; ctx.fill();
            ctx.beginPath(); ctx.arc(ex+s*.04,eyeY-blink*.3,s*.03,0,Math.PI*2);
            ctx.fillStyle='#fff'; ctx.fill();
        });

        ctx.beginPath(); ctx.ellipse(-s*.24,-s*.08,s*.065,s*.022,0,0,Math.PI*2);
        ctx.fillStyle='rgba(255,160,180,0.4)'; ctx.fill();
        ctx.beginPath(); ctx.ellipse(s*.24,-s*.08,s*.065,s*.022,0,0,Math.PI*2);
        ctx.fill();

        ctx.beginPath(); ctx.arc(0,s*.02,s*.09,.2,Math.PI-.2);
        ctx.strokeStyle='#1a2744'; ctx.lineWidth=2; ctx.lineCap='round'; ctx.stroke();
        ctx.restore();
    }

    function frame() {
        t += .016;
        ctx.clearRect(0,0,W,H);

        const gbg = ctx.createRadialGradient(W/2,H/2,0,W/2,H/2,Math.max(W,H)*.8);
        gbg.addColorStop(0,'rgba(11,23,56,1)'); gbg.addColorStop(.5,'rgba(5,13,31,1)'); gbg.addColorStop(1,'rgba(26,5,51,1)');
        ctx.fillStyle = gbg; ctx.fillRect(0,0,W,H);

        ctx.save(); ctx.strokeStyle='rgba(0,212,255,0.035)'; ctx.lineWidth=1;
        for(let x=0;x<W;x+=60){ctx.beginPath();ctx.moveTo(x,0);ctx.lineTo(x,H);ctx.stroke();}
        for(let y=0;y<H;y+=60){ctx.beginPath();ctx.moveTo(0,y);ctx.lineTo(W,y);ctx.stroke();}
        ctx.restore();

        stars.forEach(st => {
            ctx.beginPath(); ctx.arc(st.x*W,st.y*H,st.r,0,Math.PI*2);
            ctx.fillStyle='rgba(200,230,255,'+(0.2+0.5*Math.abs(Math.sin(t*st.s*10)))+')';
            ctx.fill();
        });

        particles.forEach(p => {
            p.x+=p.vx; p.y+=p.vy;
            if(p.x<0)p.x=1; if(p.x>1)p.x=0;
            if(p.y<0)p.y=1; if(p.y>1)p.y=0;
            ctx.beginPath(); ctx.arc(p.x*W,p.y*H,p.r,0,Math.PI*2);
            ctx.fillStyle='hsla('+p.hue+',100%,70%,'+p.alpha+')'; ctx.fill();
        });

        const ms = Math.min(W,H)*.12;
        ctx.globalAlpha = .22;
        drawCasper(W - ms*.65, H - ms*.45, ms, t);
        ctx.globalAlpha = .1;
        drawCasper(ms*.7, ms*.7, ms*.42, t+2);
        ctx.globalAlpha = 1;

        requestAnimationFrame(frame);
    }
    frame();
})();
</script>

</body>
</html>
