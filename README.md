# XCASPER Hosting Panel

> Customized Pterodactyl v1.11 — built by [Casper Tech Kenya](https://xcasper.space)

A fully themed, production-ready game server hosting panel with KES billing, browser push notifications, and a powerful super-admin control interface.

## ✨ Features

- **Dark XCASPER Theme** — custom CSS variable theming (primary/accent/bg colours changeable without rebuild)
- **Paystack KES Billing** — Basic KES 50/mo, Pro KES 100/mo, Admin KES 200/mo
- **KES Wallet System** — auto-renewal with wallet balance
- **Browser Push Notifications** — Web Push VAPID standard
- **Super Admin Panel** — 9-tab control centre (Branding, Appearance, Email, Billing, Users, Revenue, Push, Docs, Support)
- **Email Spam Protection** — 6-layer validation (domain allowlist, Gmail format rules, 30+ fake prefix blocks, MX DNS check)
- **Live Colour Preview** — pick colours and see the login card update in real-time
- **Add Server Button** — users can provision servers directly from dashboard
- **Animated Casper Background** — friendly ghost animation on login/register

## 🎨 Custom Files

| File | Description |
|------|-------------|
| `resources/scripts/components/auth/LoginFormContainer.tsx` | Login page with animated ghost, welcome popup, particles |
| `resources/scripts/components/auth/LoginContainer.tsx` | Login form with CSS variable theming |
| `resources/scripts/components/auth/RegisterContainer.tsx` | Register form with CSS variable theming |
| `resources/views/super-admin.blade.php` | 9-tab super-admin control panel |
| `resources/views/layouts/xcasper-bg.blade.php` | Animated Casper canvas background |
| `resources/views/templates/wrapper.blade.php` | Injects CSS colour variables into every page |
| `app/Http/Controllers/SuperAdminController.php` | Full super-admin API + config management |
| `app/Http/Controllers/Auth/RegisterController.php` | 6-layer email spam protection |
| `app/Http/Controllers/Billing/` | Paystack payment, wallet, subscription controllers |
| `resources/views/billing/` | Billing dashboard, wallet, plan selection views |

## 🚀 Deployment

Deployed at: [panel.xcasper.space](https://panel.xcasper.space)  
Node: [node.xcasper.space](https://node.xcasper.space)  
Status: [status.xcasper.space](https://status.xcasper.space)

## 🔑 Super Admin

Visit `/super-admin` and enter the key `CasperXK-2025` (change via `XCASPER_SUPER_KEY` in `.env`).

## 📦 Stack

- **Framework**: Laravel 9 + Pterodactyl v1.11
- **Frontend**: React 18 + TypeScript + styled-components
- **Build**: Webpack / Yarn
- **DB**: MySQL / SQLite
- **Billing**: Paystack (KES)
- **Push**: Web Push / VAPID
- **Mail**: SMTP (Brevo)

---

*A CASPER TECH KENYA DEVELOPERS product — © 2025-2026 Casper Tech Kenya*
