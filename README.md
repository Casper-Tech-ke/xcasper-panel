# XCASPER Hosting Panel

> Customized Pterodactyl v1.11 — built by [Casper Tech Kenya](https://xcasper.space)

A fully themed, production-ready game server hosting panel with KES billing, browser push notifications, and a 9-tab super-admin control interface.

## ✨ Features

- **Dark XCASPER Theme** — CSS variable theming (primary/accent/bg colours change instantly without rebuilding)
- **Paystack KES Billing** — Basic KES 50/mo · Pro KES 100/mo · Admin KES 200/mo
- **KES Wallet System** — auto-renewal with wallet balance
- **Browser Push Notifications** — Web Push VAPID standard
- **Super Admin Panel** — 9 tabs: Branding · Appearance · Email · Billing · Users · Revenue · Push · Docs · Support
- **Email Spam Protection** — 6-layer validation (domain allowlist, Gmail rules, 30+ fake prefix blocks, MX DNS check)
- **Live Colour Preview** — real-time login card preview with 8 colour presets
- **Add Server Button** — users provision servers directly from dashboard
- **Animated Casper Background** — friendly ghost animation with particles and stars

## 📁 Key Customized Files (in this repo)

| File | Description |
|------|-------------|
| `resources/scripts/components/auth/LoginFormContainer.tsx` | Animated login page: ghost, welcome popup, particles |
| `resources/scripts/components/auth/LoginContainer.tsx` | Login form with dynamic CSS variable theming |
| `resources/scripts/components/auth/RegisterContainer.tsx` | Register form with dynamic CSS variable theming |
| `resources/views/super-admin.blade.php` | 9-tab super-admin control panel |
| `resources/views/layouts/xcasper-bg.blade.php` | HTML5 canvas animated Casper ghost background |
| `resources/views/templates/wrapper.blade.php` | CSS variable injection wrapper |
| `app/Http/Controllers/SuperAdminController.php` | Super-admin API: config, users, revenue, VAPID |
| `app/Http/Controllers/Auth/RegisterController.php` | 6-layer email spam protection |
| `app/Providers/RouteServiceProvider.php` | All custom XCASPER routes |

## 🚀 Live Deployment

| Service | URL |
|---------|-----|
| Panel | [panel.xcasper.space](https://panel.xcasper.space) |
| Node | [node.xcasper.space:8080](https://node.xcasper.space:8080) |
| Status | [status.xcasper.space](https://status.xcasper.space) |
| Support | [t.me/casper_tech_ke](https://t.me/casper_tech_ke) |

## 🔑 Super Admin

Visit `/super-admin` — default key: `CasperXK-2025`  
Change via `XCASPER_SUPER_KEY=your-key` in `.env`

## 📦 Tech Stack

Laravel 9 · React 18 · TypeScript · styled-components · Webpack · Paystack · Web Push (VAPID) · Brevo SMTP · Nginx · Let's Encrypt

## 🛠 Quick Build

```bash
composer install --no-dev --optimize-autoloader
yarn install && yarn build
php artisan migrate --force
php artisan view:clear
```

---

*A CASPER TECH KENYA DEVELOPERS product — © 2025-2026 Casper Tech Kenya. All rights reserved.*
