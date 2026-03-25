<div align="center">

<img src="https://readme-typing-svg.demolab.com?font=Fira+Code&weight=700&size=26&duration=3000&pause=1000&color=00D4FF&center=true&vCenter=true&width=700&lines=XCASPER+Panel+—+Deployment+Guide;Production+Setup+on+Ubuntu+22.04;Casper+Tech+Kenya+🇰🇪" alt="Deploy Guide" />

[![GitHub](https://img.shields.io/badge/GitHub-Casper--Tech--ke-00D4FF?style=for-the-badge&logo=github&logoColor=white)](https://github.com/Casper-Tech-ke)
[![PHP](https://img.shields.io/badge/PHP-8.1+-7C3AED?style=for-the-badge&logo=php&logoColor=white)](https://php.net)
[![Nginx](https://img.shields.io/badge/Nginx-Web_Server-00D4FF?style=for-the-badge&logo=nginx&logoColor=white)](https://nginx.org)

</div>

---

## 📋 Prerequisites

| Requirement | Version | Notes |
|------------|---------|-------|
| Ubuntu | 22.04 LTS | Recommended OS |
| PHP | 8.1+ | cli, openssl, gd, mysql, pdo, mbstring, tokenizer, bcmath, xml, fpm, curl, zip |
| Composer | Latest | PHP dependency manager |
| Node.js | 18+ | For building the frontend |
| Yarn | 1.x | Package manager |
| MySQL | 8.0+ | Or SQLite for small installs |
| Nginx | Latest | Web server |
| Certbot | Latest | For Let's Encrypt SSL |

---

## 🏗 Step-by-Step Deployment

### 1️⃣ System Packages

```bash
apt update && apt upgrade -y
apt install -y php8.1 php8.1-cli php8.1-fpm php8.1-mysql \
  php8.1-xml php8.1-bcmath php8.1-curl php8.1-zip php8.1-gd \
  php8.1-mbstring php8.1-openssl \
  composer nginx certbot python3-certbot-nginx mysql-server curl unzip
```

### 2️⃣ Node.js & Yarn

```bash
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install -y nodejs
npm install -g yarn
```

### 3️⃣ Clone & Install

```bash
mkdir -p /var/www/xcasper-panel
cd /var/www/xcasper-panel
# Clone from GitHub or copy your files here
composer install --no-dev --optimize-autoloader
yarn install && yarn build
```

### 4️⃣ Environment Setup

```bash
cp .env.example .env
php artisan key:generate
```

Edit `.env`:

```env
APP_URL=https://panel.xcasper.space
APP_ENV=production
APP_DEBUG=false

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_DATABASE=xcasper_panel
DB_USERNAME=xcasper
DB_PASSWORD=your-secure-password

XCASPER_SUPER_KEY=your-super-admin-key

MAIL_MAILER=smtp
MAIL_HOST=smtp-relay.brevo.com
MAIL_PORT=587
MAIL_ENCRYPTION=tls
MAIL_USERNAME=your-smtp-login
MAIL_PASSWORD=your-smtp-password
MAIL_FROM_ADDRESS=no-reply@xcasper.space
MAIL_FROM_NAME="XCASPER Hosting"
```

### 5️⃣ Database

```bash
mysql -u root -p << 'SQL'
CREATE DATABASE xcasper_panel;
CREATE USER 'xcasper'@'localhost' IDENTIFIED BY 'your-secure-password';
GRANT ALL PRIVILEGES ON xcasper_panel.* TO 'xcasper'@'localhost';
FLUSH PRIVILEGES;
SQL

php artisan migrate --force
php artisan db:seed --force
```

### 6️⃣ Permissions

```bash
chown -R www-data:www-data /var/www/xcasper-panel
chmod -R 755 /var/www/xcasper-panel
chmod -R 700 storage/ bootstrap/cache/
```

### 7️⃣ Nginx Configuration

Create `/etc/nginx/sites-available/xcasper-panel`:

```nginx
server {
    listen 80;
    server_name panel.xcasper.space;

    root /var/www/xcasper-panel/public;
    index index.php;

    access_log /var/log/nginx/xcasper-panel.access.log;
    error_log  /var/log/nginx/xcasper-panel.error.log warn;

    client_max_body_size 100m;
    client_body_timeout  120s;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/run/php/php8.1-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize = 100M \n post_max_size = 100M";
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_read_timeout 300;
    }

    location ~ /\.ht {
        deny all;
    }
}
```

```bash
ln -s /etc/nginx/sites-available/xcasper-panel /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx
```

### 8️⃣ SSL Certificate

```bash
certbot --nginx -d panel.xcasper.space
```

### 9️⃣ Queue Worker (systemd)

Create `/etc/systemd/system/xcasper-queue.service`:

```ini
[Unit]
Description=XCASPER Panel Queue Worker
After=network.target

[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/xcasper-panel/artisan queue:work \
  --queue=high,standard,low --sleep=3 --tries=3

[Install]
WantedBy=multi-user.target
```

```bash
systemctl daemon-reload
systemctl enable --now xcasper-queue
```

### 🔟 Cron Job

```bash
(crontab -u www-data -l; echo "* * * * * php /var/www/xcasper-panel/artisan schedule:run >> /dev/null 2>&1") | crontab -u www-data -
```

---

## ✅ Post-Deploy Checklist

- [ ] Panel loads at `https://panel.xcasper.space`
- [ ] SSL certificate is valid (green padlock)
- [ ] Admin account created (`php artisan p:user:make`)
- [ ] Node added in Admin → Nodes
- [ ] Super Admin accessible at `/super-admin`
- [ ] Paystack keys configured in Super Admin → Billing
- [ ] Test email sent successfully
- [ ] VAPID keys generated in Super Admin → Push
- [ ] Wings node shows as online

---

## 🔄 Updating

```bash
cd /var/www/xcasper-panel
# Pull latest changes
composer install --no-dev --optimize-autoloader
yarn install && yarn build
php artisan migrate --force
php artisan view:clear && php artisan config:clear && php artisan route:clear
chown -R www-data:www-data .
systemctl restart xcasper-queue
```

---

<div align="center">

### 👻 Built with love in Kenya

[![Telegram](https://img.shields.io/badge/Telegram-Support-00D4FF?style=flat-square&logo=telegram)](https://t.me/casper_tech_ke)
[![Website](https://img.shields.io/badge/Website-xcasper.space-7C3AED?style=flat-square)](https://xcasper.space)
[![GitHub](https://img.shields.io/badge/GitHub-@Casper--Tech--ke-000?style=flat-square&logo=github)](https://github.com/Casper-Tech-ke)

**© 2025–2026 Casper Tech Kenya Developers. All rights reserved.**

*A [CASPER TECH KENYA](https://xcasper.space) product — we believe in building together.*

</div>
