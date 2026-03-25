<div align="center">

<img src="https://readme-typing-svg.demolab.com?font=Fira+Code&weight=900&size=32&duration=3000&pause=1000&color=00D4FF&center=true&vCenter=true&width=700&lines=XCASPER+Hosting+Panel;Customized+Pterodactyl+v1.11;Built+by+Casper+Tech+Kenya+🇰🇪" alt="XCASPER Panel" />

[![GitHub](https://img.shields.io/badge/GitHub-Casper--Tech--ke-00D4FF?style=for-the-badge&logo=github&logoColor=white)](https://github.com/Casper-Tech-ke)
[![PHP](https://img.shields.io/badge/PHP-8.1+-7C3AED?style=for-the-badge&logo=php&logoColor=white)](https://php.net)
[![React](https://img.shields.io/badge/React-18-00D4FF?style=for-the-badge&logo=react&logoColor=white)](https://react.dev)
[![Paystack](https://img.shields.io/badge/Paystack-KES_Billing-7C3AED?style=for-the-badge)](https://paystack.com)
[![Status](https://img.shields.io/badge/Status-Live-4ade80?style=for-the-badge)](https://status.xcasper.space)
[![License](https://img.shields.io/badge/License-MIT-00D4FF?style=for-the-badge)](LICENSE)

<br/>

> **Production-ready game server hosting panel** — KES billing, push notifications,
> live colour theming, and a 9-tab super-admin control centre.

</div>

---

## 👻 What is XCASPER Panel?

XCASPER Panel is a **heavily customized fork of [Pterodactyl v1.11](https://pterodactyl.io)** built for the African hosting market. It replaces the default UI with a dark animated XCASPER theme and adds a complete billing, wallet, and subscription system powered by **Paystack KES**.

---

## ✨ Feature Highlights

| Feature | Description |
|---------|-------------|
| 🎨 **CSS Variable Theming** | Change brand colours instantly from Super Admin — no rebuild needed |
| 💳 **Paystack KES Billing** | Basic KES 50 · Pro KES 100 · Admin KES 200 per month |
| 👛 **KES Wallet** | Top-up wallet for automatic subscription renewal |
| 🔔 **Web Push Notifications** | VAPID-based browser push — works even when the panel is closed |
| ⚙ **9-Tab Super Admin** | Branding · Appearance · Email · Billing · Users · Revenue · Push · Docs · Support |
| 🛡 **Email Spam Protection** | 6-layer validation: domain allowlist, Gmail format rules, 30+ fake prefix blocks, MX DNS |
| 🖥 **Animated Background** | Friendly Casper ghost canvas animation with particles and stars |
| 🚀 **Add Server Button** | Users provision servers directly from their dashboard |
| 🔀 **Git Clone** | Clone any Git repo directly into server files from the browser |

---

## 🗂 Key Customized Files

```
xcasper-panel/
├── app/
│   ├── Http/Controllers/
│   │   ├── Auth/RegisterController.php          ← 6-layer email spam protection
│   │   ├── Billing/                              ← Paystack, Wallet, Subscription
│   │   ├── Servers/GitCloneController.php        ← Git clone via file manager
│   │   └── SuperAdminController.php             ← 9-tab admin API
│   ├── Services/Billing/
│   │   ├── PushNotificationService.php          ← VAPID Web Push
│   │   └── XcasperServerCreationService.php     ← Auto-provision servers
│   └── Providers/RouteServiceProvider.php       ← All custom routes
├── resources/
│   ├── scripts/components/auth/
│   │   ├── LoginFormContainer.tsx               ← Animated login page
│   │   ├── LoginContainer.tsx                   ← Dynamic themed form
│   │   └── RegisterContainer.tsx                ← Dynamic themed form
│   └── views/
│       ├── super-admin.blade.php                ← 9-tab control panel
│       ├── templates/wrapper.blade.php          ← CSS variable injection + Git Clone button
│       └── layouts/xcasper-bg.blade.php         ← Casper canvas animation
└── database/migrations/
    ├── *_create_xcasper_billing_table.php
    └── *_create_xcasper_servers_table.php
```

---

## 🌐 Live Services

| Service | URL |
|---------|-----|
| 👻 Panel | [panel.xcasper.space](https://panel.xcasper.space) |
| 📚 Docs | [docs.xcasper.space](https://docs.xcasper.space) |
| 📡 Status | [status.xcasper.space](https://status.xcasper.space) |
| 🎫 Support | [support.xcasper.space](https://support.xcasper.space) |
| ☕ Buy Me a Coffee | [payments.xcasper.space](https://payments.xcasper.space) |
| 🔧 Installer | [get.xcasper.space](https://get.xcasper.space) |

---

## ☕ Support This Project

If XCASPER has been useful to you, consider buying us a coffee — KES payments via Paystack, no foreign card needed.

[![Buy Me a Coffee](https://img.shields.io/badge/☕_Buy_Me_a_Coffee-KES_via_Paystack-7C3AED?style=for-the-badge)](https://payments.xcasper.space)

---

## 🔑 Super Admin

Navigate to `/super-admin` on your panel and enter the access key.

> **Default key**: `CasperXK-2025`
> **Change via**: `XCASPER_SUPER_KEY=your-key` in `.env`

---

## 📦 Tech Stack

`Laravel 9` · `React 18` · `TypeScript` · `styled-components` · `Webpack` · `Paystack` · `Web Push (VAPID)` · `Brevo SMTP` · `Nginx` · `Let's Encrypt`

---

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [docs.xcasper.space](https://docs.xcasper.space) | Full online documentation |
| [XCASPER.md](XCASPER.md) | All custom features explained |
| [DEPLOY.md](DEPLOY.md) | Full production deployment guide |

---

## 🚀 Quick Install

```bash
bash <(curl -s https://get.xcasper.space)
```

---

<div align="center">

### 👻 Built with love in Kenya

[![Buy Me a Coffee](https://img.shields.io/badge/☕_Support_XCASPER-payments.xcasper.space-7C3AED?style=flat-square)](https://payments.xcasper.space)
[![Status](https://img.shields.io/badge/All_Services-status.xcasper.space-4ade80?style=flat-square)](https://status.xcasper.space)
[![Support](https://img.shields.io/badge/🎫_Support-support.xcasper.space-00D4FF?style=flat-square)](https://support.xcasper.space)
[![GitHub](https://img.shields.io/badge/GitHub-@Casper--Tech--ke-000?style=flat-square&logo=github)](https://github.com/Casper-Tech-ke)

**© 2025–2026 Casper Tech Kenya Developers. All rights reserved.**

*A [CASPER TECH KENYA](https://xcasper.space) product — we believe in building together.*

</div>
