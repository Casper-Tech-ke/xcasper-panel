# XCASPER Hosting — Full Project Documentation

> **Product**: XCASPER Hosting Panel (Pterodactyl fork)  
> **Domain**: [panel.xcasper.space](https://panel.xcasper.space)  
> **Installer**: `bash <(curl -s https://get.xcasper.space)`  
> **Company**: CASPER TECH KENYA DEVELOPERS  
> **GitHub**: [Casper-Tech-ke/xcasper-panel](https://github.com/Casper-Tech-ke/xcasper-panel)

---

## Table of Contents

1. [Server Information](#1-server-information)
2. [Architecture Overview](#2-architecture-overview)
3. [XCASPER Custom Features](#3-xcasper-custom-features)
   - [3.1 Dark XCASPER Theme](#31-dark-xcasper-theme)
   - [3.2 Paystack Billing (KES)](#32-paystack-billing-kes)
   - [3.3 KES Wallet & Auto-Renewal](#33-kes-wallet--auto-renewal)
   - [3.4 Super Admin Panel](#34-super-admin-panel)
   - [3.5 Push Notifications (VAPID)](#35-push-notifications-vapid)
   - [3.6 Custom Eggs (Node.js & Python)](#36-custom-eggs-nodejs--python)
   - [3.7 Git Clone Button (File Manager)](#37-git-clone-button-file-manager)
4. [Email Setup — Brevo (SMTP)](#4-email-setup--brevo-smtp)
5. [Environment Variables Reference](#5-environment-variables-reference)
6. [Database](#6-database)
7. [File Structure (Key Files)](#7-file-structure-key-files)
8. [Wings (Daemon) Setup](#8-wings-daemon-setup)
9. [Installer Script](#9-installer-script)
10. [Maintenance & Troubleshooting](#10-maintenance--troubleshooting)

---

## 1. Server Information

| Item | Value |
|------|-------|
| VPS IP | `95.111.247.5` |
| Panel path | `/var/www/xcasper-panel` |
| Panel URL | `https://panel.xcasper.space` |
| Installer URL | `https://get.xcasper.space` |
| Installer path | `/var/www/xcasper-get/install.sh` |
| Database | SQLite at `/var/www/xcasper-panel/database/database.sqlite` |
| Web server | Nginx |
| PHP version | 8.4 (FPM) |
| Node.js | v20.20.1 |
| OS | Ubuntu (on Contabo VPS) |

**SSH Access:**
```bash
ssh root@95.111.247.5
```

---

## 2. Architecture Overview

```
User Browser
     │
     ▼
Nginx (HTTPS :443 / HTTP :80 → 301 redirect)
     │
     ▼
PHP-FPM 8.4  ←→  Laravel 11 (Pterodactyl + XCASPER customisations)
     │
     ├──▶ SQLite DB  (users, servers, eggs, billing, wallets, transactions)
     ├──▶ Wings Daemon (Docker containers on the same VPS)
     └──▶ External APIs:
          ├── Paystack  (payments — KES)
          ├── Brevo     (transactional email — SMTP)
          └── VAPID     (push notifications)
```

**Frontend**: React 16 + TypeScript, compiled to `/var/www/xcasper-panel/public/assets/` via Webpack.  
The compiled JS is served as static files — no build step needed at runtime.

---

## 3. XCASPER Custom Features

### 3.1 Dark XCASPER Theme

A custom dark UI theme with XCASPER branding applied throughout the panel.

**Key files:**
- `resources/views/templates/wrapper.blade.php` — global layout wrapper, meta tags, OG tags, custom scripts
- `resources/views/layouts/xcasper-bg.blade.php` — animated background component
- `public/assets/svgs/xcasper.svg` — XCASPER logo SVG
- `public/favicons/` — Custom favicons for all platforms
- `public/og-image.png` — OG/Twitter card image

**Brand colours:**
- Primary: `#00D4FF` (cyan/blue)
- Background: `#0f131c` → `#1a1f2b`
- Accent gradient: `#00D4FF` → `#007ACC`

---

### 3.2 Paystack Billing (KES)

Full Paystack integration for subscription billing in Kenyan Shillings.

**Plans:**

| Plan | Monthly Price | Egg Used |
|------|--------------|----------|
| Basic | KES 50 | Egg ID 3 (XCASPER Node.js) |
| Pro | KES 100 | Egg ID 3 (XCASPER Node.js) |
| Admin | KES 200 | Egg ID 4 (XCASPER Python) |

**How it works:**
1. User selects a plan on the billing page
2. Paystack popup opens (KES currency)
3. On success, the webhook at `/api/billing/paystack/webhook` fires
4. Panel creates/upgrades the server via `XcasperServerCreationService`
5. Balance is added to user's KES wallet for auto-renewal

**Key files:**
- `app/Http/Controllers/Api/Client/BillingController.php` — Paystack initialise, verify, webhook
- `app/Services/Billing/XcasperServerCreationService.php` — server provisioning per plan
- `resources/scripts/components/billing/` — React billing UI components

**Paystack keys** (stored in `.env`):
```
PAYSTACK_PUBLIC_KEY=pk_live_561d2b09...
PAYSTACK_SECRET_KEY=sk_live_9dcf3d47...
```

**Paystack Dashboard:** [dashboard.paystack.com](https://dashboard.paystack.com)  
**Webhook URL to configure in Paystack:** `https://panel.xcasper.space/api/billing/paystack/webhook`

---

### 3.3 KES Wallet & Auto-Renewal

Every user has a KES wallet. Payments top up the wallet; monthly auto-renewal deducts from it.

**Wallet fields** (on the `users` table):
- `wallet_balance` — current balance in KES
- `subscription_plan` — `basic` / `pro` / `admin` / `null`
- `subscription_expires_at` — next renewal date
- `subscription_server_id` — linked server ID

**Auto-renewal logic** (scheduled command):
```bash
php artisan xcasper:renew-subscriptions
```
Runs daily. Deducts plan cost from wallet; suspends server if balance is insufficient.

**Admin top-up** (Super Admin panel → user card → "Top Up Wallet" button):
- Can top up by user ID, email, or username
- Transaction type logged as `admin_topup`

---

### 3.4 Super Admin Panel

A dedicated admin interface accessible at `/super-admin` (requires `XCASPER_SUPER_KEY`).

**URL:** `https://panel.xcasper.space/super-admin`  
**Default key:** stored in `.env` as `XCASPER_SUPER_KEY`

**Features:**
- View all users with wallet balances and subscription status
- **Top Up Wallet** — add KES balance to any user (by ID, email, or username)
- **Upgrade Plan** — change a user's subscription plan directly
- **Ban / Unban** users
- **Force Delete** users
- **Email settings** — update SMTP config from UI
- **Billing settings** — update Paystack keys from UI
- **Server config** — configure per-plan egg IDs:
  - `basic_egg_id` (default: 3)
  - `pro_egg_id` (default: 3)
  - `admin_egg_id` (default: 4)
- **VAPID key generation** — one-click generate push notification keys
- **Revenue dashboard** — total revenue, transactions list

**Key file:** `app/Http/Controllers/SuperAdminController.php`  
**Blade view:** `resources/views/super-admin.blade.php`

---

### 3.5 Push Notifications (VAPID)

Web push notifications using the VAPID protocol.

**Setup:**
1. Go to `/super-admin`
2. Click **"Generate VAPID Keys"**
3. Keys are saved to `.env` as `VAPID_PUBLIC_KEY` and `VAPID_PRIVATE_KEY`
4. Service worker at `public/xcasper-sw.js` handles push subscription on the client

**Environment variables:**
```
VAPID_PUBLIC_KEY=<generated>
VAPID_PRIVATE_KEY=<generated>
VAPID_SUBJECT=mailto:admin@xcasper.space
```

---

### 3.6 Custom Eggs (Node.js & Python)

Two custom XCASPER-branded eggs pre-installed in the panel database.

| ID | Name | UUID | Description |
|----|------|------|-------------|
| 3 | XCASPER Modified Node.js | `950379e0-...` | Node.js servers, CMD_RUN variable, XCASPER prompt |
| 4 | XCASPER Modified Python | `b4c2d1e0-5f63-43d8-bbfd-e22e02dd1ecc` | Python 3.8–3.13, PY_FILE variable, XCASPER prompt |

**Egg JSON files** (pushed to [Casper-Tech-ke/xcasper-eggs](https://github.com/Casper-Tech-ke/xcasper-eggs)):
- `generic/egg-xcasper-nodejs.json`
- `generic/egg-xcasper-python.json`

**Import an egg** (if re-installing):
```
Pterodactyl Admin → Nests → Import Egg → paste JSON
```

**Server creation service** (`XcasperServerCreationService.php`):
- Reads per-plan egg ID from `xcasper-config.json`
- Builds environment variables dynamically from each egg's own variable defaults
- Node.js gets `CMD_RUN`, Python gets `PY_FILE` — no hardcoding

---

### 3.7 Git Clone Button (File Manager)

A **"🔀 Clone Repo"** button injected into every server's file manager toolbar.

**How to use:**
1. Navigate to any server → **Files** tab
2. The "🔀 Clone Repo" button appears in the toolbar
3. Click it to open the Clone modal
4. Fill in:
   - **Repository URL** (required) — `https://github.com/user/repo.git`, `git@github.com:...`, etc.
   - **Target Directory** — pre-filled with your current directory; leave `/` to clone to server root
   - **Branch** — optional; blank = default branch
   - **Username** — optional; for private repos (GitHub username, GitLab username, etc.)
   - **Access Token / PAT** — optional; GitHub Personal Access Token or GitLab token for private repos
5. Click **"🚀 Clone Repository"**

**Behaviour:**
- If **server is online**: clone script runs immediately in the console — watch progress in the console tab with `[XCASPER-GIT]` prefix logs
- If **server is offline**: the script `.xcasper-git-clone.sh` is written to your target directory. Start the server then run:
  ```bash
  bash .xcasper-git-clone.sh
  ```
  The script self-deletes after running.

**Private repo example (GitHub PAT):**
```
URL:    https://github.com/MyOrg/private-repo.git
Branch: main
User:   myghusername
Token:  ghp_xxxxxxxxxxxxxxxxxxxx
```

**API endpoint:** `POST /api/client/servers/{server}/files/git-clone`

**Key files:**
- `app/Http/Controllers/Api/Client/Servers/GitCloneController.php` — backend logic
- `routes/api-client.php` — route registration
- `resources/views/templates/wrapper.blade.php` — MutationObserver frontend injection

---

## 4. Email Setup — Brevo (SMTP)

XCASPER uses **Brevo** (formerly Sendinblue) for all transactional emails — password resets, server notifications, billing receipts, etc.

### 4.1 Brevo Account

| Item | Details |
|------|---------|
| Provider | Brevo (formerly Sendinblue) |
| Website | [app.brevo.com](https://app.brevo.com) |
| Pricing page | [brevo.com/pricing](https://www.brevo.com/pricing/) |
| Free tier | 300 emails/day (no credit card needed) |
| SMTP docs | [developers.brevo.com/docs/send-a-transactional-email](https://developers.brevo.com/docs/send-a-transactional-email) |

### 4.2 How to Get Your SMTP Credentials

1. Sign up / log in at [app.brevo.com](https://app.brevo.com)
2. Go to **Settings → SMTP & API → SMTP**  
   Direct link: [app.brevo.com/settings/keys/smtp](https://app.brevo.com/settings/keys/smtp)
3. Note your **SMTP login** (looks like `a59db1001@smtp-brevo.com`)
4. Click **"Generate a new SMTP key"** — copy the password immediately (shown once)
5. Your SMTP details are:

| Setting | Value |
|---------|-------|
| Host | `smtp-relay.brevo.com` |
| Port | `587` (TLS) or `465` (SSL) |
| Username | Your Brevo SMTP login (e.g. `xxxx@smtp-brevo.com`) |
| Password | The SMTP key you generated |
| Encryption | `tls` |

### 4.3 Current XCASPER Brevo Configuration

The panel is already configured with Brevo. These values live in `/var/www/xcasper-panel/.env`:

```env
MAIL_MAILER=smtp
MAIL_HOST=smtp-relay.brevo.com
MAIL_PORT=587
MAIL_USERNAME=a59db1001@smtp-brevo.com
MAIL_PASSWORD=<your-brevo-smtp-key>
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS=no-reply@xcasper.space
MAIL_FROM_NAME="XCASPER Hosting"
```

> **Important:** The `MAIL_FROM_ADDRESS` domain (`xcasper.space`) must be verified in Brevo.

### 4.4 Domain Verification in Brevo

For emails to land in inbox (not spam), verify your sending domain:

1. In Brevo go to **Settings → Senders & IPs → Domains**  
   Direct link: [app.brevo.com/senders/domain/list](https://app.brevo.com/senders/domain/list)
2. Click **"Add a domain"** → enter `xcasper.space`
3. Brevo will give you DNS records to add (TXT records for SPF/DKIM)
4. Add them in your DNS provider (where `xcasper.space` is registered)
5. Click **"Verify"** — can take up to 24h for DNS to propagate

**Recommended DNS records:**

| Type | Name | Value |
|------|------|-------|
| TXT | `@` or `xcasper.space` | `v=spf1 include:spf.brevo.com ~all` |
| TXT | `mail._domainkey` | *(DKIM key provided by Brevo)* |
| TXT | `_dmarc` | `v=DMARC1; p=none; rua=mailto:admin@xcasper.space` |

### 4.5 Update Email Config from Super Admin

You can update SMTP settings without SSH:

1. Go to `https://panel.xcasper.space/super-admin`
2. Scroll to **"Email Settings"** section
3. Update SMTP host, port, username, password, from address
4. Click **"Save Email Settings"**

Changes apply immediately (no server restart needed).

### 4.6 Test Email Delivery

From the VPS, test Brevo SMTP directly:

```bash
cd /var/www/xcasper-panel
php artisan tinker
```

Then in the tinker shell:
```php
Mail::raw('Test from XCASPER panel', function($m) {
    $m->to('your@email.com')->subject('XCASPER Test Email');
});
```

Or test via artisan:
```bash
php artisan xcasper:test-mail your@email.com
```

### 4.7 Brevo Useful Links

| Resource | URL |
|----------|-----|
| Dashboard | [app.brevo.com](https://app.brevo.com) |
| SMTP Settings | [app.brevo.com/settings/keys/smtp](https://app.brevo.com/settings/keys/smtp) |
| API Keys | [app.brevo.com/settings/keys/api](https://app.brevo.com/settings/keys/api) |
| Domain Verification | [app.brevo.com/senders/domain/list](https://app.brevo.com/senders/domain/list) |
| Email Logs | [app.brevo.com/email-logs/view](https://app.brevo.com/email-logs/view) |
| Transactional Templates | [app.brevo.com/templates](https://app.brevo.com/templates) |
| Pricing | [brevo.com/pricing](https://www.brevo.com/pricing/) |
| SMTP Docs | [developers.brevo.com/docs/send-a-transactional-email](https://developers.brevo.com/docs/send-a-transactional-email) |
| Support | [help.brevo.com](https://help.brevo.com) |

---

## 5. Environment Variables Reference

Key variables in `/var/www/xcasper-panel/.env`:

```env
# App
APP_NAME="XCASPER Hosting"
APP_URL=https://panel.xcasper.space
APP_KEY=<laravel-app-key>
APP_DEBUG=false

# Database (SQLite)
DB_CONNECTION=sqlite
DB_DATABASE=/var/www/xcasper-panel/database/database.sqlite

# Mail (Brevo)
MAIL_MAILER=smtp
MAIL_HOST=smtp-relay.brevo.com
MAIL_PORT=587
MAIL_USERNAME=<brevo-smtp-login>
MAIL_PASSWORD=<brevo-smtp-key>
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS=no-reply@xcasper.space
MAIL_FROM_NAME="XCASPER Hosting"

# Paystack
PAYSTACK_PUBLIC_KEY=pk_live_...
PAYSTACK_SECRET_KEY=sk_live_...

# Push Notifications
VAPID_PUBLIC_KEY=<generated>
VAPID_PRIVATE_KEY=<generated>
VAPID_SUBJECT=mailto:admin@xcasper.space

# XCASPER Super Admin
XCASPER_SUPER_KEY=<your-secret-key>

# Cache / Queue / Session
CACHE_DRIVER=file
QUEUE_CONNECTION=sync
SESSION_DRIVER=file
```

---

## 6. Database

**Engine:** SQLite (file-based, no external server needed)  
**Location:** `/var/www/xcasper-panel/database/database.sqlite`

**Connect via SQLite CLI:**
```bash
sqlite3 /var/www/xcasper-panel/database/database.sqlite
```

**Useful queries:**
```sql
-- List all users with wallet balances
SELECT id, username, email, wallet_balance, subscription_plan, subscription_expires_at FROM users;

-- View recent transactions
SELECT * FROM xcasper_transactions ORDER BY created_at DESC LIMIT 20;

-- Check servers
SELECT id, name, uuid, suspended FROM servers;

-- Check eggs
SELECT id, name, uuid FROM eggs;
```

**Run migrations:**
```bash
cd /var/www/xcasper-panel
php artisan migrate
```

**Backup the database:**
```bash
cp /var/www/xcasper-panel/database/database.sqlite /root/xcasper-db-backup-$(date +%Y%m%d).sqlite
```

---

## 7. File Structure (Key Files)

```
/var/www/xcasper-panel/
├── .env                                        ← All secrets & config
├── database/database.sqlite                    ← SQLite database
├── storage/
│   ├── logs/laravel.log                        ← Application logs
│   └── app/xcasper-config.json                 ← Per-plan egg IDs & billing config
│
├── app/
│   ├── Http/Controllers/
│   │   ├── SuperAdminController.php            ← Super admin all routes
│   │   └── Api/Client/
│   │       ├── BillingController.php           ← Paystack billing
│   │       └── Servers/
│   │           ├── FileController.php          ← File manager API
│   │           └── GitCloneController.php      ← Git clone feature ← NEW
│   └── Services/Billing/
│       └── XcasperServerCreationService.php    ← Auto-provision servers per plan
│
├── routes/
│   ├── api-client.php                          ← Client API routes (incl. git-clone)
│   └── base.php                                ← Web routes
│
├── resources/views/
│   ├── super-admin.blade.php                   ← Super admin UI
│   ├── super-admin-lock.blade.php              ← Locked state view
│   └── templates/
│       └── wrapper.blade.php                   ← Global layout (theme, scripts, git-clone injection)
│
└── public/
    ├── xcasper-sw.js                           ← Push notification service worker
    ├── assets/                                 ← Compiled React JS/CSS
    └── favicons/                               ← All favicon sizes
```

---

## 8. Wings (Daemon) Setup

Wings runs as a service on the same VPS, managing Docker containers for each server.

**Check Wings status:**
```bash
systemctl status wings
```

**Restart Wings:**
```bash
systemctl restart wings
```

**Wings config:** `/etc/pterodactyl/config.yml`

**Wings logs:**
```bash
journalctl -u wings -f
```

---

## 9. Installer Script

The automated installer at `https://get.xcasper.space` sets up a full XCASPER hosting stack.

**Run the installer:**
```bash
bash <(curl -s https://get.xcasper.space)
```

**Installer location on VPS:** `/var/www/xcasper-get/install.sh`

**What it installs:**
- PHP 8.4 + required extensions
- Nginx with SSL (Let's Encrypt)
- SQLite
- Wings (Pterodactyl daemon)
- XCASPER panel (from GitHub)
- All required systemd services

---

## 10. Maintenance & Troubleshooting

### Clear all Laravel caches
```bash
cd /var/www/xcasper-panel
php artisan view:clear
php artisan config:clear
php artisan route:clear
php artisan cache:clear
```

### Fix storage permissions (run if 500 errors appear)
```bash
chown -R www-data:www-data /var/www/xcasper-panel/storage /var/www/xcasper-panel/bootstrap/cache
chmod -R 775 /var/www/xcasper-panel/storage /var/www/xcasper-panel/bootstrap/cache
```

### Restart Nginx
```bash
systemctl restart nginx
```

### Restart PHP-FPM
```bash
systemctl restart php8.4-fpm
```

### View Laravel error logs
```bash
tail -f /var/www/xcasper-panel/storage/logs/laravel.log
```

### Check all services are running
```bash
systemctl status nginx php8.4-fpm wings
```

### Re-run subscription renewals manually
```bash
cd /var/www/xcasper-panel
php artisan xcasper:renew-subscriptions
```

### Update the panel from GitHub
```bash
cd /var/www/xcasper-panel
git pull origin main
php artisan migrate
php artisan config:clear
php artisan view:clear
systemctl restart php8.4-fpm
```

---

*Documentation maintained by CASPER TECH KENYA DEVELOPERS — [xcasper.space](https://xcasper.space)*
