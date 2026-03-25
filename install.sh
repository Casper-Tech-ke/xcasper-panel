#!/usr/bin/env bash
# ============================================================
#   XCASPER Hosting Manager
#   Usage:  bash <(curl -s https://get.xcasper.space)
#   Repo:   https://github.com/Casper-Tech-ke/xcasper-panel
#   Docs:   https://docs.xcasper.space
# ============================================================
set -o pipefail

# ── Colours ────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ── Helpers ─────────────────────────────────────────────────
info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
step()    { echo -e "\n${PURPLE}${BOLD}▶  $*${NC}"; }
ask()     { echo -e "${YELLOW}$*${NC}"; }

divider() {
    echo -e "${DIM}────────────────────────────────────────────────────────${NC}"
}

# ── Banner ──────────────────────────────────────────────────
banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo " ██╗  ██╗ ██████╗ █████╗ ███████╗██████╗ ███████╗██████╗ "
    echo " ╚██╗██╔╝██╔════╝██╔══██╗██╔════╝██╔══██╗██╔════╝██╔══██╗"
    echo "  ╚███╔╝ ██║     ███████║███████╗██████╔╝█████╗  ██████╔╝"
    echo "  ██╔██╗ ██║     ██╔══██║╚════██║██╔═══╝ ██╔══╝  ██╔══██╗"
    echo " ██╔╝ ██╗╚██████╗██║  ██║███████║██║     ███████╗██║  ██║"
    echo " ╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝     ╚══════╝╚═╝  ╚═╝"
    echo -e "${NC}"
    echo -e "${PURPLE}${BOLD}         XCASPER Hosting — Automated Installer${NC}"
    echo -e "${DIM}         Docs: https://docs.xcasper.space${NC}"
    divider
    echo ""
}

# ── Root check ──────────────────────────────────────────────
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This installer must be run as root.\n  Try: sudo bash <(curl -s https://get.xcasper.space)"
    fi
}

# ── OS check ────────────────────────────────────────────────
check_os() {
    step "Checking Operating System"
    if [[ ! -f /etc/os-release ]]; then
        error "Cannot determine OS. Ubuntu 20.04 / 22.04 / 24.04 required."
    fi

    # shellcheck disable=SC1091
    source /etc/os-release
    OS_NAME="${ID:-}"
    OS_VERSION="${VERSION_ID:-}"

    if [[ "$OS_NAME" != "ubuntu" ]]; then
        error "Only Ubuntu is supported. Detected: $OS_NAME $OS_VERSION"
    fi

    case "$OS_VERSION" in
        20.04|22.04|24.04)
            success "Ubuntu $OS_VERSION — supported"
            ;;
        *)
            warn "Ubuntu $OS_VERSION is not officially tested. Continuing anyway..."
            ;;
    esac
}

# ── Swap check ───────────────────────────────────────────────
check_swap() {
    step "Checking Memory & Swap"

    TOTAL_RAM_MB=$(awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo)
    SWAP_MB=$(awk '/SwapTotal/ {printf "%d", $2/1024}' /proc/meminfo)

    info "RAM: ${TOTAL_RAM_MB}MB  |  Swap: ${SWAP_MB}MB"

    if [[ "$TOTAL_RAM_MB" -lt 1500 && "$SWAP_MB" -lt 1024 ]]; then
        warn "Low RAM detected (${TOTAL_RAM_MB}MB). Creating 2GB swap to prevent out-of-memory errors..."
        if [[ ! -f /swapfile ]]; then
            fallocate -l 2G /swapfile
            chmod 600 /swapfile
            mkswap /swapfile
            swapon /swapfile
            echo '/swapfile none swap sw 0 0' >> /etc/fstab
            success "2GB swap created and activated"
        else
            info "Swap file already exists — skipping"
        fi
    else
        success "Memory is sufficient — no swap needed"
    fi
}

# ── Port availability check ──────────────────────────────────
check_ports() {
    step "Checking Port Availability"

    PORTS_TO_CHECK=(80 443)
    for PORT in "${PORTS_TO_CHECK[@]}"; do
        if ss -tlnp "sport = :$PORT" 2>/dev/null | grep -q LISTEN; then
            warn "Port $PORT is already in use. Nginx may fail to start."
            warn "Run: ss -tlnp | grep :$PORT  to see what is using it."
        else
            success "Port $PORT is free"
        fi
    done
}

# ── DNS pre-flight check ─────────────────────────────────────
check_dns() {
    local domain="$1"
    step "Checking DNS for $domain"

    SERVER_IP=$(curl -s4 https://ifconfig.me 2>/dev/null || curl -s4 https://api.ipify.org 2>/dev/null || echo "unknown")
    DOMAIN_IP=$(getent hosts "$domain" 2>/dev/null | awk '{print $1}' | head -1 || echo "")

    info "This server's public IP: ${BOLD}$SERVER_IP${NC}"
    info "DNS resolves $domain to:  ${BOLD}${DOMAIN_IP:-not found}${NC}"

    if [[ "$DOMAIN_IP" == "$SERVER_IP" ]]; then
        success "DNS is pointing correctly to this server"
    elif [[ -z "$DOMAIN_IP" ]]; then
        warn "Domain does not resolve yet. DNS may still be propagating."
        warn "SSL certificate will FAIL if DNS is not pointing here."
        ask "Continue anyway? [y/N]:"
        read -r DNS_CONFIRM
        [[ "${DNS_CONFIRM,,}" != "y" ]] && error "Cancelled. Fix your DNS A record first, then re-run the installer."
    else
        warn "Domain resolves to $DOMAIN_IP but this server is $SERVER_IP."
        warn "SSL will FAIL unless DNS is updated and propagated."
        ask "Continue anyway? [y/N]:"
        read -r DNS_CONFIRM
        [[ "${DNS_CONFIRM,,}" != "y" ]] && error "Cancelled. Update your DNS A record to $SERVER_IP, then re-run."
    fi
}

# (choose_component replaced by main menu — see bottom of script)

# ── Collect Panel inputs ─────────────────────────────────────
collect_panel_inputs() {
    step "Panel Configuration"
    divider

    ask "Panel domain (e.g. panel.yourdomain.com):"
    read -r PANEL_DOMAIN
    [[ -z "$PANEL_DOMAIN" ]] && error "Domain cannot be empty."

    ask "Admin email address:"
    read -r ADMIN_EMAIL
    [[ -z "$ADMIN_EMAIL" ]] && error "Email cannot be empty."

    ask "Database password (press Enter to auto-generate):"
    read -rs DB_PASSWORD
    echo ""
    if [[ -z "$DB_PASSWORD" ]]; then
        DB_PASSWORD=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 24)
        info "Generated database password: ${BOLD}$DB_PASSWORD${NC}"
        info "Save this — you will need it if you reinstall."
    fi

    ask "App timezone (default: Africa/Nairobi — see list: https://www.php.net/timezones):"
    read -r APP_TIMEZONE
    APP_TIMEZONE="${APP_TIMEZONE:-Africa/Nairobi}"

    echo ""
    step "First Admin Account"
    divider

    ask "Admin first name:"
    read -r ADMIN_FIRST
    ADMIN_FIRST="${ADMIN_FIRST:-Admin}"

    ask "Admin last name:"
    read -r ADMIN_LAST
    ADMIN_LAST="${ADMIN_LAST:-User}"

    ask "Admin username (no spaces):"
    read -r ADMIN_USER
    ADMIN_USER="${ADMIN_USER:-admin}"

    ask "Admin password (press Enter to auto-generate):"
    read -rs ADMIN_PASSWORD
    echo ""
    if [[ -z "$ADMIN_PASSWORD" ]]; then
        ADMIN_PASSWORD=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 16)
        info "Generated admin password: ${BOLD}$ADMIN_PASSWORD${NC}"
    fi

    echo ""
    step "Cloudflare (Optional — Recommended)"
    divider
    echo -e "  ${DIM}Automates DNS records, SSL/TLS settings, HTTPS redirect, and security.${NC}"
    echo ""
    ask "Do you use Cloudflare for this domain? [y/N]:"
    read -r USE_CF
    USE_CF="${USE_CF,,}"

    if [[ "$USE_CF" == "y" ]]; then
        echo ""
        echo -e "  ${DIM}Create an API Token at: https://dash.cloudflare.com/profile/api-tokens${NC}"
        echo -e "  ${DIM}Required permission: Zone → DNS → Edit  +  Zone → Zone Settings → Edit${NC}"
        echo ""
        ask "Cloudflare API Token:"
        read -rs CF_TOKEN
        echo ""

        ask "Cloudflare Zone ID (find it on your domain's Overview page → right sidebar):"
        read -r CF_ZONE_ID

        echo ""
        echo -e "  ${DIM}A Cloudflare Tunnel routes traffic through Cloudflare without exposing your server IP.${NC}"
        ask "Set up a Cloudflare Tunnel (cloudflared)? [y/N]:"
        read -r USE_CF_TUNNEL
        USE_CF_TUNNEL="${USE_CF_TUNNEL,,}"
    else
        CF_TOKEN=""
        CF_ZONE_ID=""
        USE_CF_TUNNEL="n"
    fi

    echo ""
    info "Panel will be installed at: ${BOLD}https://$PANEL_DOMAIN${NC}"
    ask "Continue? [y/N]:"
    read -r CONFIRM
    [[ "${CONFIRM,,}" != "y" ]] && error "Installation cancelled."
}

# ── Collect Wings inputs ─────────────────────────────────────
collect_wings_inputs() {
    step "Wings Configuration"
    divider

    ask "Panel URL — full URL including https:// (e.g. https://panel.yourdomain.com):"
    read -r PANEL_URL
    [[ -z "$PANEL_URL" ]] && error "Panel URL cannot be empty."
    PANEL_URL="${PANEL_URL%/}"

    ask "Wings token (from Panel → Admin → Nodes → Configuration — leave blank to set later):"
    read -r WINGS_TOKEN
    if [[ -z "$WINGS_TOKEN" ]]; then
        warn "Token left blank — add it to /etc/pterodactyl/config.yml before starting Wings."
        WINGS_TOKEN="REPLACE_WITH_YOUR_TOKEN"
    fi
}

# ── Install dependencies ─────────────────────────────────────
install_dependencies() {
    step "Installing System Dependencies"

    export DEBIAN_FRONTEND=noninteractive

    info "Updating package list..."
    apt-get update -y -qq

    info "Installing core packages..."
    apt-get install -y -qq \
        curl wget git unzip tar \
        software-properties-common \
        apt-transport-https ca-certificates \
        gnupg lsb-release ufw \
        nginx certbot python3-certbot-nginx \
        redis-server \
        dnsutils

    # PHP 8.3 — add repo for Ubuntu (Ondrej PPA) or Debian (SURY)
    info "Adding PHP 8.3 repository..."
    OS_ID=$(lsb_release -is 2>/dev/null | tr '[:upper:]' '[:lower:]')
    if [[ "$OS_ID" == "ubuntu" ]]; then
        PHP_LIST="/etc/apt/sources.list.d/ondrej-ubuntu-php-$(lsb_release -cs).list"
        if [[ ! -f "$PHP_LIST" ]]; then
            LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
            apt-get update -y -qq
        fi
    elif [[ "$OS_ID" == "debian" ]]; then
        if [[ ! -f "/etc/apt/sources.list.d/sury-php.list" ]]; then
            curl -fsSL https://packages.sury.org/php/apt.gpg \
                | gpg --dearmor -o /usr/share/keyrings/sury-php.gpg
            echo "deb [signed-by=/usr/share/keyrings/sury-php.gpg] https://packages.sury.org/php/ $(lsb_release -cs) main" \
                | tee /etc/apt/sources.list.d/sury-php.list > /dev/null
            apt-get update -y -qq
        fi
    fi

    info "Installing PHP 8.3 and all required extensions..."
    apt-get install -y -qq \
        php8.3 php8.3-fpm php8.3-cli php8.3-mysql \
        php8.3-mbstring php8.3-xml php8.3-curl \
        php8.3-zip php8.3-gd php8.3-bcmath \
        php8.3-intl php8.3-tokenizer php8.3-fileinfo \
        php8.3-redis php8.3-posix

    # MySQL
    info "Installing MySQL..."
    apt-get install -y -qq mysql-server

    # Composer
    info "Installing Composer..."
    if ! command -v composer &>/dev/null; then
        curl -sS https://getcomposer.org/installer \
            | php -- --install-dir=/usr/local/bin --filename=composer --quiet
    fi
    COMPOSER_VERSION=$(composer --version --no-ansi 2>/dev/null | awk '{print $3}')
    success "Composer $COMPOSER_VERSION"

    # Node.js 20
    info "Installing Node.js 20..."
    NODE_MAJOR=0
    if command -v node &>/dev/null; then
        NODE_MAJOR=$(node -v | cut -d. -f1 | tr -d 'v')
    fi
    if [[ "$NODE_MAJOR" -lt 18 ]]; then
        curl -fsSL https://deb.nodesource.com/setup_20.x | bash - >/dev/null 2>&1
        apt-get install -y -qq nodejs
    fi
    success "Node $(node -v)"

    # Yarn
    info "Installing Yarn..."
    npm install -g yarn --quiet
    success "Yarn $(yarn --version)"

    # Enable and start Redis + PHP-FPM
    info "Starting services..."
    systemctl enable redis-server && systemctl start redis-server
    systemctl enable php8.3-fpm  && systemctl start php8.3-fpm

    success "All dependencies installed and services running"
}

# ── Setup MySQL ──────────────────────────────────────────────
setup_database() {
    step "Setting Up Database"

    info "Starting MySQL..."
    systemctl enable mysql
    systemctl start mysql

    # Wait for MySQL socket to be ready
    for i in {1..15}; do
        mysqladmin ping --socket=/var/run/mysqld/mysqld.sock --silent 2>/dev/null && break
        info "Waiting for MySQL to be ready... ($i/15)"
        sleep 2
    done

    info "Creating database and user..."
    mysql -u root --socket=/var/run/mysqld/mysqld.sock << SQL
CREATE DATABASE IF NOT EXISTS xcasper_panel CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
DROP USER IF EXISTS 'xcasper'@'localhost';
CREATE USER 'xcasper'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON xcasper_panel.* TO 'xcasper'@'localhost';
FLUSH PRIVILEGES;
SQL

    success "Database 'xcasper_panel' ready with user 'xcasper'"
}

# ── Clone & Install Panel ─────────────────────────────────────
install_panel_files() {
    step "Installing XCASPER Panel"

    PANEL_DIR="/var/www/xcasper-panel"
    PTERO_VERSION="v1.12.1"   # Latest stable Pterodactyl base

    # ── Step 1: Clone Pterodactyl base (public repo, no auth needed) ──
    if [[ -d "$PANEL_DIR/.git" ]]; then
        info "Panel directory already exists — pulling latest base..."
        git -C "$PANEL_DIR" pull origin release/${PTERO_VERSION} 2>/dev/null || true
    else
        info "Cloning Pterodactyl base (${PTERO_VERSION}) from GitHub..."
        git clone \
            --branch "${PTERO_VERSION}" \
            --depth 1 \
            https://github.com/pterodactyl/panel.git \
            "$PANEL_DIR"
    fi

    # ── Step 2: Apply XCASPER customizations on top ──────────────────
    info "Applying XCASPER customizations..."
    CUSTOM_DIR=$(mktemp -d)

    git clone --depth 1 \
        https://github.com/Casper-Tech-ke/xcasper-panel.git \
        "$CUSTOM_DIR" --quiet

    # Overlay XCASPER custom files onto the Pterodactyl base
    for src_dir in app database/migrations resources; do
        if [[ -d "$CUSTOM_DIR/$src_dir" ]]; then
            cp -r "$CUSTOM_DIR/$src_dir/." "$PANEL_DIR/$src_dir/"
        fi
    done

    rm -rf "$CUSTOM_DIR"
    success "XCASPER customizations applied (billing, super-admin, custom UI, push notifications)"

    # ── Step 3: Install dependencies & build ─────────────────────────
    cd "$PANEL_DIR"

    info "Installing PHP dependencies with Composer..."
    COMPOSER_ALLOW_SUPERUSER=1 composer install \
        --no-dev --optimize-autoloader --no-interaction --quiet

    info "Installing Node.js dependencies..."
    yarn install --silent

    info "Building XCASPER frontend..."
    yarn build

    success "XCASPER Panel ready at $PANEL_DIR"
}

# ── Configure Environment ─────────────────────────────────────
configure_env() {
    step "Configuring Environment"

    cd /var/www/xcasper-panel

    cp .env.example .env

    # Generate app key
    php artisan key:generate --force --no-interaction

    # Smart env setter — replaces existing key or appends new one
    set_env() {
        local key="$1" val="$2"
        if grep -q "^${key}=" .env 2>/dev/null; then
            sed -i "s|^${key}=.*|${key}=${val}|" .env
        else
            echo "${key}=${val}" >> .env
        fi
    }

    set_env "APP_URL"          "https://${PANEL_DOMAIN}"
    set_env "APP_TIMEZONE"     "${APP_TIMEZONE}"
    set_env "DB_HOST"          "127.0.0.1"
    set_env "DB_PORT"          "3306"
    set_env "DB_DATABASE"      "xcasper_panel"
    set_env "DB_USERNAME"      "xcasper"
    set_env "DB_PASSWORD"      "${DB_PASSWORD}"
    set_env "CACHE_DRIVER"     "redis"
    set_env "SESSION_DRIVER"   "redis"
    set_env "QUEUE_CONNECTION" "redis"
    set_env "REDIS_HOST"       "127.0.0.1"
    set_env "REDIS_PORT"       "6379"

    info "Running database migrations..."
    php artisan migrate --force --no-interaction

    info "Seeding database..."
    php artisan db:seed --force --no-interaction

    info "Caching configuration..."
    php artisan config:cache
    php artisan route:cache
    php artisan view:cache

    success "Environment configured"
}

# ── Set Permissions ───────────────────────────────────────────
set_permissions() {
    step "Setting File Permissions"

    chown -R www-data:www-data /var/www/xcasper-panel
    chmod -R 755 /var/www/xcasper-panel
    chmod -R 700 /var/www/xcasper-panel/storage /var/www/xcasper-panel/bootstrap/cache

    success "Permissions set"
}

# ── Create Admin User ─────────────────────────────────────────
create_admin_user() {
    step "Creating Admin Account"

    cd /var/www/xcasper-panel

    php artisan p:user:make \
        --email="$ADMIN_EMAIL" \
        --username="$ADMIN_USER" \
        --name-first="$ADMIN_FIRST" \
        --name-last="$ADMIN_LAST" \
        --password="$ADMIN_PASSWORD" \
        --admin=1 \
        --no-interaction

    success "Admin account created: ${BOLD}$ADMIN_USER${NC}"
}

# ── Configure Nginx ───────────────────────────────────────────
configure_nginx() {
    step "Configuring Nginx"

    # Stop any conflicting service on port 80
    systemctl stop apache2 2>/dev/null || true

    cat > /etc/nginx/sites-available/xcasper-panel << NGINX
server {
    listen 80;
    listen [::]:80;
    server_name ${PANEL_DOMAIN};

    root /var/www/xcasper-panel/public;
    index index.php;

    access_log /var/log/nginx/xcasper-panel.access.log;
    error_log  /var/log/nginx/xcasper-panel.error.log warn;

    client_max_body_size 100m;
    client_body_timeout  120s;
    send_timeout         300s;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_read_timeout 300;
        fastcgi_buffers 16 16k;
        fastcgi_buffer_size 32k;
    }

    location ~ /\.ht {
        deny all;
    }
}
NGINX

    ln -sf /etc/nginx/sites-available/xcasper-panel /etc/nginx/sites-enabled/xcasper-panel
    rm -f /etc/nginx/sites-enabled/default

    nginx -t && systemctl enable nginx && systemctl reload nginx
    success "Nginx configured for $PANEL_DOMAIN"
}

# ── Obtain SSL ────────────────────────────────────────────────
obtain_ssl() {
    step "Obtaining SSL Certificate"

    info "Requesting Let's Encrypt certificate for $PANEL_DOMAIN ..."
    certbot --nginx \
        --non-interactive \
        --agree-tos \
        --email "$ADMIN_EMAIL" \
        --domains "$PANEL_DOMAIN" \
        --redirect

    # Ensure certbot auto-renewal timer is running
    systemctl enable certbot.timer 2>/dev/null || true
    systemctl start  certbot.timer 2>/dev/null || true

    success "SSL certificate installed — auto-renewal enabled"
}

# ── Setup Queue Worker ────────────────────────────────────────
setup_queue_worker() {
    step "Setting Up Queue Worker (systemd)"

    cat > /etc/systemd/system/xcasper-queue.service << SERVICE
[Unit]
Description=XCASPER Panel Queue Worker
After=network.target mysql.service redis.service

[Service]
User=www-data
Group=www-data
WorkingDirectory=/var/www/xcasper-panel
ExecStart=/usr/bin/php /var/www/xcasper-panel/artisan queue:work --sleep=3 --tries=3 --max-time=3600
Restart=always
RestartSec=5
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=xcasper-queue

[Install]
WantedBy=multi-user.target
SERVICE

    systemctl daemon-reload
    systemctl enable xcasper-queue
    systemctl start xcasper-queue

    success "Queue worker running"
}

# ── Setup Cron ────────────────────────────────────────────────
setup_cron() {
    step "Setting Up Scheduled Tasks (Cron)"

    CRON_LINE="* * * * * php /var/www/xcasper-panel/artisan schedule:run >> /dev/null 2>&1"
    EXISTING_CRON=$(crontab -l -u www-data 2>/dev/null || true)

    if echo "$EXISTING_CRON" | grep -qF "artisan schedule:run"; then
        info "Cron job already present — skipping"
    else
        printf '%s\n%s\n' "$EXISTING_CRON" "$CRON_LINE" | crontab -u www-data -
        success "Cron job added for www-data"
    fi
}

# ── Configure Firewall ────────────────────────────────────────
configure_firewall() {
    step "Configuring Firewall (UFW)"

    ufw allow 22/tcp   comment "SSH"         2>/dev/null || true
    ufw allow 80/tcp   comment "HTTP"        2>/dev/null || true
    ufw allow 443/tcp  comment "HTTPS"       2>/dev/null || true
    ufw allow 8080/tcp comment "Wings HTTP"  2>/dev/null || true
    ufw allow 2022/tcp comment "Wings SFTP"  2>/dev/null || true
    ufw --force enable

    success "Firewall rules applied"
}

# ── Cloudflare DNS + Zone configuration ───────────────────────
setup_cloudflare() {
    [[ "${USE_CF:-n}" != "y" ]] && return 0

    step "Configuring Cloudflare"

    CF_API="https://api.cloudflare.com/client/v4"

    # ── Validate token ────────────────────────────────────────
    info "Verifying Cloudflare API token..."
    TOKEN_CHECK=$(curl -sf -H "Authorization: Bearer $CF_TOKEN" \
        "${CF_API}/user/tokens/verify" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)

    if [[ "$TOKEN_CHECK" != "active" ]]; then
        warn "Cloudflare token invalid or inactive — skipping CF setup."
        return 0
    fi
    success "API token: active"

    # ── Detect server public IP ───────────────────────────────
    SERVER_IP=$(curl -s4 https://ifconfig.me || curl -s4 https://api.ipify.org || curl -s4 https://ipv4.icanhazip.com)
    [[ -z "$SERVER_IP" ]] && { warn "Could not detect server IP — skipping DNS creation."; SERVER_IP=""; }

    # ── Helper: create or update a DNS A record ───────────────
    cf_upsert_dns() {
        local NAME="$1" PROXIED="$2"
        [[ -z "$SERVER_IP" ]] && return

        # Check for existing record
        EXISTING_ID=$(curl -sf \
            -H "Authorization: Bearer $CF_TOKEN" \
            "${CF_API}/zones/${CF_ZONE_ID}/dns_records?type=A&name=${NAME}" \
            | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

        PAYLOAD="{\"type\":\"A\",\"name\":\"${NAME}\",\"content\":\"${SERVER_IP}\",\"ttl\":1,\"proxied\":${PROXIED}}"

        if [[ -n "$EXISTING_ID" ]]; then
            curl -sf -X PUT \
                -H "Authorization: Bearer $CF_TOKEN" \
                -H "Content-Type: application/json" \
                "${CF_API}/zones/${CF_ZONE_ID}/dns_records/${EXISTING_ID}" \
                --data "$PAYLOAD" > /dev/null
            success "DNS A record updated: ${NAME} → ${SERVER_IP} (proxied=${PROXIED})"
        else
            curl -sf -X POST \
                -H "Authorization: Bearer $CF_TOKEN" \
                -H "Content-Type: application/json" \
                "${CF_API}/zones/${CF_ZONE_ID}/dns_records" \
                --data "$PAYLOAD" > /dev/null
            success "DNS A record created: ${NAME} → ${SERVER_IP} (proxied=${PROXIED})"
        fi
    }

    # ── Helper: patch a zone setting ─────────────────────────
    cf_zone_set() {
        local SETTING="$1" VALUE="$2"
        curl -sf -X PATCH \
            -H "Authorization: Bearer $CF_TOKEN" \
            -H "Content-Type: application/json" \
            "${CF_API}/zones/${CF_ZONE_ID}/settings/${SETTING}" \
            --data "{\"value\":\"${VALUE}\"}" > /dev/null \
        && success "CF setting ${SETTING}: ${VALUE}" \
        || warn "Could not set ${SETTING} (check token Zone Settings permission)"
    }

    # ── DNS records ───────────────────────────────────────────
    # Panel: proxied (orange cloud — traffic routes via CF)
    # Wings: NOT proxied (grey cloud — game traffic must be direct)
    info "Creating DNS records..."
    cf_upsert_dns "$PANEL_DOMAIN" "true"

    if [[ "${INSTALL_WINGS:-false}" == true ]]; then
        WINGS_DOMAIN="${WINGS_NODE_DOMAIN:-$PANEL_DOMAIN}"
        if [[ "$WINGS_DOMAIN" != "$PANEL_DOMAIN" ]]; then
            # Separate Wings subdomain — grey cloud (game ports can't go through CF proxy)
            cf_upsert_dns "$WINGS_DOMAIN" "false"
        fi
    fi

    # ── SSL/TLS mode: Full (we generate our own cert with certbot) ──
    info "Applying Cloudflare zone settings..."
    cf_zone_set "ssl" "full"

    # ── Security & performance ────────────────────────────────
    cf_zone_set "always_use_https" "on"
    cf_zone_set "min_tls_version" "1.2"
    cf_zone_set "tls_1_3" "zrt"              # TLS 1.3 + 0-RTT
    cf_zone_set "automatic_https_rewrites" "on"
    cf_zone_set "security_level" "medium"
    cf_zone_set "brotli" "on"
    cf_zone_set "http2" "on"
    cf_zone_set "http3" "on"
    cf_zone_set "0rtt" "on"
    cf_zone_set "minify" "{\"js\":\"on\",\"css\":\"on\",\"html\":\"off\"}" 2>/dev/null || true
    cf_zone_set "browser_cache_ttl" "14400"

    # ── Cloudflare Tunnel (cloudflared) ──────────────────────
    if [[ "${USE_CF_TUNNEL:-n}" == "y" ]]; then
        step "Setting Up Cloudflare Tunnel"
        divider

        # Install cloudflared
        info "Installing cloudflared..."
        if ! command -v cloudflared &>/dev/null; then
            curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg \
                | tee /usr/share/keyrings/cloudflare-main.gpg > /dev/null
            echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] \
https://pkg.cloudflare.com/cloudflared jammy main" \
                | tee /etc/apt/sources.list.d/cloudflared.list > /dev/null
            apt-get update -qq
            apt-get install -y -q cloudflared
        fi
        success "cloudflared $(cloudflared --version 2>&1 | head -1 | awk '{print $3}')"

        # Create the tunnel via API
        info "Creating Cloudflare Tunnel 'xcasper-panel'..."
        TUNNEL_RESPONSE=$(curl -sf -X POST \
            -H "Authorization: Bearer $CF_TOKEN" \
            -H "Content-Type: application/json" \
            "${CF_API}/accounts/$(curl -sf -H "Authorization: Bearer $CF_TOKEN" \
                ${CF_API}/accounts | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)/cfd_tunnel" \
            --data '{"name":"xcasper-panel","config_src":"cloudflare"}')

        TUNNEL_ID=$(echo "$TUNNEL_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
        TUNNEL_TOKEN=$(echo "$TUNNEL_RESPONSE" | grep -o '"token":"[^"]*"' | head -1 | cut -d'"' -f4)

        if [[ -n "$TUNNEL_ID" && -n "$TUNNEL_TOKEN" ]]; then
            success "Tunnel created: $TUNNEL_ID"

            # Install as a system service with the token
            cloudflared service install "$TUNNEL_TOKEN" > /dev/null 2>&1 || true
            systemctl enable cloudflared 2>/dev/null || true
            systemctl start cloudflared 2>/dev/null || true
            success "cloudflared service started"

            # Update the DNS record to point at the tunnel
            cf_upsert_dns "$PANEL_DOMAIN" "true"

            info "Panel traffic now routing through Cloudflare Tunnel"
            info "Tunnel ID: ${BOLD}$TUNNEL_ID${NC}"
        else
            warn "Could not create tunnel via API. Run manually:"
            warn "  cloudflared tunnel login"
            warn "  cloudflared tunnel create xcasper-panel"
            warn "  cloudflared tunnel route dns xcasper-panel $PANEL_DOMAIN"
        fi
    fi

    success "Cloudflare setup complete"
}

# ── Wings system user ─────────────────────────────────────────
create_wings_user() {
    if ! id "pterodactyl" &>/dev/null; then
        info "Creating 'pterodactyl' system user..."
        useradd -r -d /var/lib/pterodactyl -s /usr/sbin/nologin pterodactyl
    fi
    mkdir -p /var/lib/pterodactyl/{volumes,archives,backups}
    mkdir -p /var/log/pterodactyl
    chown -R pterodactyl:pterodactyl /var/lib/pterodactyl /var/log/pterodactyl
    success "Wings system user ready"
}

# ── Install Wings ─────────────────────────────────────────────
install_wings() {
    step "Installing Wings Daemon"

    create_wings_user

    info "Installing Docker..."
    if ! command -v docker &>/dev/null; then
        curl -fsSL https://get.docker.com | bash >/dev/null 2>&1
        systemctl enable docker
        systemctl start docker
    fi
    DOCKER_VER=$(docker --version | awk '{print $3}' | tr -d ',')
    success "Docker $DOCKER_VER"

    info "Adding pterodactyl user to docker group..."
    usermod -aG docker pterodactyl 2>/dev/null || true

    info "Downloading latest Wings binary..."
    mkdir -p /etc/pterodactyl

    WINGS_VERSION=$(curl -s "https://api.github.com/repos/pterodactyl/wings/releases/latest" \
        | grep '"tag_name"' | cut -d '"' -f4)
    curl -fsSL \
        "https://github.com/pterodactyl/wings/releases/download/${WINGS_VERSION}/wings_linux_amd64" \
        -o /usr/local/bin/wings
    chmod +x /usr/local/bin/wings
    success "Wings $WINGS_VERSION installed at /usr/local/bin/wings"

    WINGS_UUID=$(cat /proc/sys/kernel/random/uuid)

    cat > /etc/pterodactyl/config.yml << WCONF
debug: false
uuid: "${WINGS_UUID}"
token_id: ""
token: "${WINGS_TOKEN}"
remote: "${PANEL_URL}"
api:
  host: "0.0.0.0"
  port: 8080
  ssl:
    enabled: false
  upload_limit: 100
system:
  root_directory: /var/lib/pterodactyl
  logs_directory: /var/log/pterodactyl
  data: /var/lib/pterodactyl/volumes
  archive_directory: /var/lib/pterodactyl/archives
  backup_directory: /var/lib/pterodactyl/backups
  username: pterodactyl
  timezone: "${APP_TIMEZONE:-Africa/Nairobi}"
  sftp:
    bind_port: 2022
docker:
  socket: /var/run/docker.sock
  network:
    interface: "172.18.0.1"
    name: pterodactyl_nw
    dns:
      - "1.1.1.1"
      - "1.0.0.1"
    ispn: false
    driver: bridge
    is_internal: false
    enable_icc: true
    network_mtu: 1500
    interfaces:
      v4:
        subnet: "172.18.0.0/16"
        gateway: "172.18.0.1"
      v6:
        subnet: "fdba:17c8:6c94::/64"
        gateway: "fdba:17c8:6c94::1011"
  domainname: ""
throttles:
  enabled: true
  lines: 2000
  line_reset_interval: 100
cache:
  packages: 1440
  disk: 0
allowed_mounts: []
allowed_origins: []
WCONF

    success "Wings configuration written to /etc/pterodactyl/config.yml"

    cat > /etc/systemd/system/wings.service << SERVICE
[Unit]
Description=XCASPER Wings Daemon
After=docker.service
Requires=docker.service

[Service]
User=root
WorkingDirectory=/etc/pterodactyl
ExecStart=/usr/local/bin/wings
Restart=on-failure
RestartSec=5
StartLimitInterval=180
StartLimitBurst=30
LimitNOFILE=4096
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=wings

[Install]
WantedBy=multi-user.target
SERVICE

    systemctl daemon-reload
    systemctl enable wings

    if [[ "$WINGS_TOKEN" != "REPLACE_WITH_YOUR_TOKEN" ]]; then
        systemctl start wings
        success "Wings daemon started"
    else
        warn "Wings NOT started — add your real token to /etc/pterodactyl/config.yml"
        warn "Then run: systemctl start wings"
    fi
}

# ── Summary ───────────────────────────────────────────────────
show_summary() {
    echo ""
    divider
    echo -e "${GREEN}${BOLD}"
    echo "  ██████╗  ██████╗ ███╗   ██╗███████╗██╗"
    echo "  ██╔══██╗██╔═══██╗████╗  ██║██╔════╝██║"
    echo "  ██║  ██║██║   ██║██╔██╗ ██║█████╗  ██║"
    echo "  ██║  ██║██║   ██║██║╚██╗██║██╔══╝  ╚═╝"
    echo "  ██████╔╝╚██████╔╝██║ ╚████║███████╗██╗"
    echo "  ╚═════╝  ╚═════╝ ╚═╝  ╚═══╝╚══════╝╚═╝"
    echo -e "${NC}"
    echo -e "${GREEN}${BOLD}  Installation Complete!${NC}"
    echo ""
    divider

    if [[ "${INSTALL_PANEL:-false}" == true ]]; then
        echo -e "${CYAN}  Panel URL:${NC}       ${BOLD}https://$PANEL_DOMAIN${NC}"
        echo -e "${CYAN}  Admin Email:${NC}     ${BOLD}$ADMIN_EMAIL${NC}"
        echo -e "${CYAN}  Admin Username:${NC}  ${BOLD}$ADMIN_USER${NC}"
        echo -e "${CYAN}  Admin Password:${NC}  ${BOLD}$ADMIN_PASSWORD${NC}"
        echo -e "${CYAN}  DB Password:${NC}     ${BOLD}$DB_PASSWORD${NC}"
        echo ""
    fi

    if [[ "${INSTALL_WINGS:-false}" == true ]]; then
        echo -e "${CYAN}  Wings Config:${NC}    /etc/pterodactyl/config.yml"
        echo -e "${CYAN}  Wings Binary:${NC}    /usr/local/bin/wings"
        echo -e "${CYAN}  Wings Status:${NC}    $(systemctl is-active wings 2>/dev/null || echo 'not started')"
        echo ""
    fi

    if [[ "${USE_CF:-n}" == "y" ]]; then
        echo -e "${CYAN}  Cloudflare:${NC}      ${GREEN}${BOLD}Configured ✓${NC}"
        echo -e "${CYAN}  CF Zone ID:${NC}      $CF_ZONE_ID"
        if [[ "${USE_CF_TUNNEL:-n}" == "y" ]]; then
            echo -e "${CYAN}  CF Tunnel:${NC}       ${GREEN}${BOLD}Active ✓${NC}"
        fi
        echo ""
    fi

    divider
    echo -e "${YELLOW}${BOLD}  Important — Save Before Closing:${NC}"
    echo -e "  • These credentials will not be shown again"
    if [[ "${INSTALL_PANEL:-false}" == true ]]; then
        echo -e "  • Configure SMTP:  ${CYAN}https://$PANEL_DOMAIN/admin/settings/mail${NC}"
        echo -e "  • Super Admin tab: Billing, plans, push notifications"
    fi
    if [[ "${USE_CF:-n}" == "y" ]]; then
        echo -e "  • Wings nodes: keep DNS ${BOLD}grey cloud (not proxied)${NC} in Cloudflare"
        echo -e "    Game ports (25565 etc.) cannot route through the CF proxy"
    fi
    if [[ "${INSTALL_WINGS:-false}" == true && "$WINGS_TOKEN" == "REPLACE_WITH_YOUR_TOKEN" ]]; then
        echo -e "  • Set Wings token: ${CYAN}nano /etc/pterodactyl/config.yml${NC}"
        echo -e "    Then start Wings: ${CYAN}systemctl start wings${NC}"
    fi
    divider
    echo ""
    echo -e "${DIM}  Docs:   https://docs.xcasper.space"
    echo -e "  GitHub: https://github.com/Casper-Tech-ke${NC}"
    echo ""
}

# ════════════════════════════════════════════════════════════
#   MENU ACTIONS
# ════════════════════════════════════════════════════════════

# ── 1) Panel submenu ─────────────────────────────────────────
menu_install_panel() {
    while true; do
        clear
        banner
        echo -e "  ${CYAN}${BOLD}🐲  XCASPER Panel Control Center${NC}"
        echo ""
        echo -e "  ${CYAN}1)${NC}  Install Panel (fresh)"
        echo -e "  ${CYAN}2)${NC}  Create Panel User"
        echo -e "  ${CYAN}3)${NC}  Update Panel (in-place upgrade)"
        echo -e "  ${CYAN}4)${NC}  Uninstall Panel"
        echo -e "  ${CYAN}0)${NC}  Back to main menu"
        echo ""
        divider
        ask "Choose [0-4]:"
        read -r PANEL_CHOICE

        case "$PANEL_CHOICE" in
            1) _panel_install   ;;
            2) _panel_create_user ;;
            3) _panel_update    ;;
            4) _panel_uninstall ;;
            0) return 0         ;;
            *) warn "Invalid choice."; sleep 1 ;;
        esac
    done
}

# ── Panel: fresh install ──────────────────────────────────────
_panel_install() {
    check_os
    check_swap
    check_ports

    INSTALL_PANEL=true
    INSTALL_WINGS=false

    collect_panel_inputs

    if [[ "${USE_CF:-n}" == "y" ]]; then
        info "Cloudflare mode — DNS record will be auto-created. Skipping pre-flight DNS check."
    else
        check_dns "$PANEL_DOMAIN"
    fi

    install_dependencies
    setup_database
    install_panel_files
    configure_env
    set_permissions
    create_admin_user
    configure_nginx
    obtain_ssl
    setup_cloudflare
    setup_queue_worker
    setup_cron
    configure_firewall
    show_summary

    echo ""
    read -rp "$(echo -e "${YELLOW}Press Enter to return to menu...${NC}")"
}

# ── Panel: create user ────────────────────────────────────────
_panel_create_user() {
    clear
    banner
    step "Create Panel User"
    divider

    PANEL_DIR="/var/www/xcasper-panel"
    if [[ ! -d "$PANEL_DIR" ]]; then
        warn "Panel not found at $PANEL_DIR — please install the panel first."
        echo ""
        read -rp "$(echo -e "${YELLOW}Press Enter to continue...${NC}")"
        return
    fi

    info "Running artisan user creation wizard..."
    echo ""
    cd "$PANEL_DIR"
    sudo -u www-data php artisan p:user:make

    success "User created successfully"
    echo ""
    read -rp "$(echo -e "${YELLOW}Press Enter to return to menu...${NC}")"
}

# ── Panel: update in-place ────────────────────────────────────
_panel_update() {
    clear
    banner
    step "Update XCASPER Panel"
    divider

    PANEL_DIR="/var/www/xcasper-panel"
    if [[ ! -d "$PANEL_DIR" ]]; then
        warn "Panel not found at $PANEL_DIR — please install first."
        echo ""
        read -rp "$(echo -e "${YELLOW}Press Enter to continue...${NC}")"
        return
    fi

    LATEST=$(curl -s "https://api.github.com/repos/pterodactyl/panel/releases/latest" \
        | grep '"tag_name"' | cut -d'"' -f4)
    info "Latest Pterodactyl base: ${BOLD}$LATEST${NC}"

    ask "Continue with update? This will put the panel briefly into maintenance mode. [y/N]:"
    read -r UP_CONFIRM
    [[ "${UP_CONFIRM,,}" != "y" ]] && { warn "Update cancelled."; read -rp "Press Enter..."; return; }

    cd "$PANEL_DIR"

    info "Enabling maintenance mode..."
    sudo -u www-data php artisan down

    info "Pulling latest Pterodactyl base ($LATEST)..."
    curl -fsSL "https://github.com/pterodactyl/panel/releases/download/${LATEST}/panel.tar.gz" \
        | tar -xz --strip-components=1

    info "Re-applying XCASPER customizations..."
    CUSTOM_DIR=$(mktemp -d)
    git clone --depth 1 https://github.com/Casper-Tech-ke/xcasper-panel.git "$CUSTOM_DIR" --quiet
    for src_dir in app database/migrations resources; do
        if [[ -d "$CUSTOM_DIR/$src_dir" ]]; then
            cp -r "$CUSTOM_DIR/$src_dir/." "$PANEL_DIR/$src_dir/"
        fi
    done
    rm -rf "$CUSTOM_DIR"
    success "XCASPER customizations re-applied"

    info "Running composer install..."
    COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader --quiet

    info "Clearing caches..."
    sudo -u www-data php artisan view:clear
    sudo -u www-data php artisan config:clear
    sudo -u www-data php artisan route:clear

    info "Running migrations..."
    sudo -u www-data php artisan migrate --seed --force

    info "Setting permissions..."
    chmod -R 755 storage/* bootstrap/cache/
    chown -R www-data:www-data "$PANEL_DIR"

    info "Restarting queue worker..."
    sudo -u www-data php artisan queue:restart
    systemctl restart xcasper-queue 2>/dev/null || true

    info "Taking panel out of maintenance mode..."
    sudo -u www-data php artisan up

    success "Panel updated to $LATEST with XCASPER customizations"
    echo ""
    read -rp "$(echo -e "${YELLOW}Press Enter to return to menu...${NC}")"
}

# ── Panel: uninstall ──────────────────────────────────────────
_panel_uninstall() {
    clear
    banner
    echo -e "  ${RED}${BOLD}⚠  This will permanently remove the XCASPER Panel${NC}"
    echo ""
    ask "Type 'yes' to confirm panel removal:"
    read -r CONF
    if [[ "$CONF" != "yes" ]]; then
        warn "Cancelled."
        read -rp "$(echo -e "${YELLOW}Press Enter to continue...${NC}")"
        return
    fi

    step "Removing XCASPER Panel"
    systemctl stop xcasper-queue 2>/dev/null || true
    systemctl disable xcasper-queue 2>/dev/null || true
    rm -f /etc/systemd/system/xcasper-queue.service
    systemctl daemon-reload

    crontab -l -u www-data 2>/dev/null \
        | grep -v 'artisan schedule:run' \
        | crontab -u www-data - 2>/dev/null || true

    rm -rf /var/www/xcasper-panel
    success "Panel files removed"

    mysql -u root -e "DROP DATABASE IF EXISTS panel;" 2>/dev/null || true
    mysql -u root -e "DROP USER IF EXISTS 'xcasper'@'127.0.0.1';" 2>/dev/null || true
    mysql -u root -e "FLUSH PRIVILEGES;" 2>/dev/null || true
    success "Database dropped"

    rm -f /etc/nginx/sites-enabled/xcasper-panel.conf
    rm -f /etc/nginx/sites-available/xcasper-panel.conf
    nginx -t 2>/dev/null && systemctl reload nginx 2>/dev/null || true
    success "Nginx config removed"

    success "Panel fully uninstalled"
    echo ""
    read -rp "$(echo -e "${YELLOW}Press Enter to return to menu...${NC}")"
}

# ── 2) Install Wings ─────────────────────────────────────────
menu_install_wings() {
    check_os
    check_swap

    INSTALL_PANEL=false
    INSTALL_WINGS=true

    collect_wings_inputs
    install_dependencies
    install_wings
    configure_firewall
    show_summary

    echo ""
    read -rp "$(echo -e "${YELLOW}Press Enter to return to menu...${NC}")"
}

# ── 3) Uninstall ─────────────────────────────────────────────
menu_uninstall() {
    while true; do
        clear
        banner
        echo -e "  ${RED}${BOLD}⚠  XCASPER Uninstaller — actions cannot be undone${NC}"
        echo ""
        echo -e "  ${CYAN}1)${NC} Uninstall Panel only"
        echo -e "  ${CYAN}2)${NC} Uninstall Wings only"
        echo -e "  ${CYAN}3)${NC} Uninstall Panel + Wings (full removal)"
        echo -e "  ${CYAN}0)${NC} Back to main menu"
        echo ""
        ask "Choose [0-3]:"
        read -r UNSUB

        _do_uninstall_panel() {
            step "Removing XCASPER Panel"
            systemctl stop xcasper-queue 2>/dev/null || true
            systemctl disable xcasper-queue 2>/dev/null || true
            rm -f /etc/systemd/system/xcasper-queue.service
            systemctl daemon-reload

            crontab -l -u www-data 2>/dev/null \
                | grep -v 'artisan schedule:run' \
                | crontab -u www-data - 2>/dev/null || true

            rm -rf /var/www/xcasper-panel
            success "Panel files removed"

            mysql -u root -e "DROP DATABASE IF EXISTS panel;" 2>/dev/null || true
            mysql -u root -e "DROP USER IF EXISTS 'xcasper'@'127.0.0.1';" 2>/dev/null || true
            mysql -u root -e "FLUSH PRIVILEGES;" 2>/dev/null || true
            success "Database dropped"

            rm -f /etc/nginx/sites-enabled/xcasper-panel.conf
            rm -f /etc/nginx/sites-available/xcasper-panel.conf
            nginx -t 2>/dev/null && systemctl reload nginx 2>/dev/null || true
            success "Nginx config removed"
        }

        _do_uninstall_wings() {
            step "Removing Wings Daemon"
            systemctl stop wings 2>/dev/null || true
            systemctl disable wings 2>/dev/null || true
            rm -f /etc/systemd/system/wings.service
            systemctl daemon-reload

            rm -rf /etc/pterodactyl
            rm -rf /var/lib/pterodactyl
            rm -rf /var/log/pterodactyl
            rm -f /usr/local/bin/wings
            success "Wings removed"
        }

        case "$UNSUB" in
            1)
                ask "Type 'yes' to confirm panel removal:"
                read -r CONF
                if [[ "$CONF" == "yes" ]]; then _do_uninstall_panel
                else warn "Cancelled."; fi
                ;;
            2)
                ask "Type 'yes' to confirm Wings removal:"
                read -r CONF
                if [[ "$CONF" == "yes" ]]; then _do_uninstall_wings
                else warn "Cancelled."; fi
                ;;
            3)
                ask "Type 'yes' to confirm FULL removal (panel + wings):"
                read -r CONF
                if [[ "$CONF" == "yes" ]]; then
                    _do_uninstall_panel
                    _do_uninstall_wings
                    success "Full removal complete"
                else warn "Cancelled."; fi
                ;;
            0) return 0 ;;
            *) warn "Invalid choice." ;;
        esac
        echo ""
        read -rp "$(echo -e "${YELLOW}Press Enter to continue...${NC}")"
    done
}

# ── 4) Cloudflare Setup ───────────────────────────────────────
menu_cloudflare() {
    while true; do
        clear
        banner
        echo -e "  ${CYAN}${BOLD}☁  Cloudflare Tunnel Manager${NC}"
        echo ""
        echo -e "  ${CYAN}1)${NC} Install / Setup Tunnel"
        echo -e "  ${CYAN}2)${NC} Uninstall Completely"
        echo -e "  ${CYAN}0)${NC} Back to main menu"
        echo ""
        ask "Choose [0-2]:"
        read -r CF_CHOICE

        case "$CF_CHOICE" in
            1)
                clear
                step "Installing cloudflared"

                # Add repo and install
                mkdir -p --mode=0755 /usr/share/keyrings
                curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg \
                    | tee /usr/share/keyrings/cloudflare-main.gpg > /dev/null
                echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] \
https://pkg.cloudflare.com/cloudflared any main" \
                    | tee /etc/apt/sources.list.d/cloudflared.list > /dev/null
                apt-get update -qq
                apt-get install -y cloudflared
                success "cloudflared $(cloudflared --version 2>&1 | head -1 | awk '{print $3}')"

                # Remove any stale service
                if systemctl list-units --type=service 2>/dev/null | grep -q cloudflared; then
                    warn "Existing cloudflared service found — removing before reinstall..."
                    cloudflared service uninstall 2>/dev/null || true
                    success "Old service removed"
                fi

                echo ""
                echo -e "  ${DIM}Get your tunnel token from:${NC}"
                echo -e "  ${DIM}Cloudflare Dashboard → Zero Trust → Networks → Tunnels${NC}"
                echo -e "  ${DIM}Create tunnel → copy the 'cloudflared service install <TOKEN>' command${NC}"
                echo ""
                ask "Paste your tunnel token (or the full 'cloudflared service install ...' command):"
                read -r USER_INPUT

                # Strip the command prefix if user pasted the full command
                CF_TUNNEL_TOKEN=$(echo "$USER_INPUT" \
                    | sed 's/sudo cloudflared service install //g' \
                    | sed 's/cloudflared service install //g' \
                    | xargs)

                if [[ -z "$CF_TUNNEL_TOKEN" ]]; then
                    warn "Empty token — skipping service install."
                else
                    cloudflared service install "$CF_TUNNEL_TOKEN"
                    sleep 2
                    if systemctl is-active --quiet cloudflared; then
                        success "Cloudflare Tunnel is running"
                    else
                        warn "Tunnel installed but not running. Check: systemctl status cloudflared"
                    fi
                fi

                echo ""
                read -rp "$(echo -e "${YELLOW}Press Enter to continue...${NC}")"
                ;;
            2)
                clear
                step "Uninstalling cloudflared"
                cloudflared service uninstall 2>/dev/null || true
                apt-get remove -y cloudflared 2>/dev/null || true
                rm -f /etc/apt/sources.list.d/cloudflared.list
                rm -f /usr/share/keyrings/cloudflare-main.gpg
                success "cloudflared completely removed"
                echo ""
                read -rp "$(echo -e "${YELLOW}Press Enter to continue...${NC}")"
                ;;
            0) return 0 ;;
            *) warn "Invalid choice."; sleep 1 ;;
        esac
    done
}

# ── 5) System Information ────────────────────────────────────
menu_system_info() {
    clear
    banner
    step "System Information"
    divider

    CPU_MODEL=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)
    CPU_CORES=$(nproc)
    RAM_USED=$(free -h | awk '/Mem:/ {print $3}')
    RAM_TOTAL=$(free -h | awk '/Mem:/ {print $2}')
    SWAP_USED=$(free -h | awk '/Swap:/ {print $3}')
    SWAP_TOTAL=$(free -h | awk '/Swap:/ {print $2}')
    DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
    DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
    DISK_PCT=$(df -h / | awk 'NR==2 {print $5}')
    UPTIME=$(uptime -p | sed 's/up //')
    OS=$(lsb_release -d 2>/dev/null | cut -d: -f2 | xargs || uname -sr)
    KERNEL=$(uname -r)
    PUB_IP=$(curl -s4 https://ifconfig.me 2>/dev/null || echo "unknown")
    HOSTNAME=$(hostname)

    echo -e "  ${CYAN}Hostname:${NC}      $HOSTNAME"
    echo -e "  ${CYAN}Public IP:${NC}     $PUB_IP"
    echo -e "  ${CYAN}OS:${NC}            $OS"
    echo -e "  ${CYAN}Kernel:${NC}        $KERNEL"
    echo -e "  ${CYAN}Uptime:${NC}        $UPTIME"
    divider
    echo -e "  ${CYAN}CPU:${NC}           $CPU_MODEL ($CPU_CORES cores)"
    echo -e "  ${CYAN}RAM:${NC}           ${RAM_USED} / ${RAM_TOTAL} used"
    echo -e "  ${CYAN}Swap:${NC}          ${SWAP_USED} / ${SWAP_TOTAL} used"
    echo -e "  ${CYAN}Disk (/):${NC}      ${DISK_USED} / ${DISK_TOTAL} (${DISK_PCT} used)"
    divider

    # Service statuses
    for SVC in nginx mysql mariadb redis php8.3-fpm wings cloudflared tailscaled; do
        STATUS=$(systemctl is-active "$SVC" 2>/dev/null || echo "not installed")
        if [[ "$STATUS" == "active" ]]; then
            echo -e "  ${CYAN}${SVC}:${NC} ${GREEN}running${NC}"
        elif [[ "$STATUS" == "inactive" ]]; then
            echo -e "  ${CYAN}${SVC}:${NC} ${YELLOW}stopped${NC}"
        else
            echo -e "  ${CYAN}${SVC}:${NC} ${DIM}not installed${NC}"
        fi
    done

    divider
    echo ""
    read -rp "$(echo -e "${YELLOW}Press Enter to return to menu...${NC}")"
}

# ── 6) Tailscale VPN ─────────────────────────────────────────
menu_tailscale() {
    while true; do
        clear
        banner
        TS_STATUS=$(systemctl is-active tailscaled 2>/dev/null || echo "not installed")
        if [[ "$TS_STATUS" == "active" ]]; then
            echo -e "  ${GREEN}${BOLD}Tailscale: RUNNING${NC}"
        else
            echo -e "  ${YELLOW}${BOLD}Tailscale: $TS_STATUS${NC}"
        fi
        echo ""
        echo -e "  ${CYAN}1)${NC} Install Tailscale & Connect"
        echo -e "  ${CYAN}2)${NC} Uninstall Tailscale"
        echo -e "  ${CYAN}0)${NC} Back to main menu"
        echo ""
        ask "Choose [0-2]:"
        read -r TS_CHOICE

        case "$TS_CHOICE" in
            1)
                clear
                step "Installing Tailscale"
                curl -fsSL https://tailscale.com/install.sh | sh
                systemctl enable --now tailscaled 2>/dev/null || true
                success "Tailscale installed"
                echo ""
                info "Connecting to Tailscale network..."
                echo -e "  ${DIM}Authenticate in your browser when prompted${NC}"
                echo ""
                tailscale up
                echo ""
                read -rp "$(echo -e "${YELLOW}Press Enter to continue...${NC}")"
                ;;
            2)
                clear
                step "Uninstalling Tailscale"
                ask "Type 'yes' to confirm:"
                read -r CONF
                if [[ "$CONF" == "yes" ]]; then
                    systemctl stop tailscaled 2>/dev/null || true
                    systemctl disable tailscaled 2>/dev/null || true
                    apt-get purge -y tailscale 2>/dev/null || true
                    rm -rf /var/lib/tailscale /etc/tailscale /var/cache/tailscale
                    apt-get autoremove -y 2>/dev/null || true
                    success "Tailscale completely removed"
                else
                    warn "Cancelled."
                fi
                echo ""
                read -rp "$(echo -e "${YELLOW}Press Enter to continue...${NC}")"
                ;;
            0) return 0 ;;
            *) warn "Invalid choice."; sleep 1 ;;
        esac
    done
}

# ── 7) Database Setup ─────────────────────────────────────────
menu_database() {
    clear
    banner
    step "Database Setup — Add Remote MySQL User"
    divider
    echo -e "  ${DIM}Creates a MySQL user with remote access and opens port 3306.${NC}"
    echo -e "  ${DIM}Useful for connecting an external panel or database manager.${NC}"
    echo ""

    ask "New database username:"
    read -r DB_NEW_USER
    [[ -z "$DB_NEW_USER" ]] && { warn "Username cannot be empty."; return; }

    ask "Password for ${DB_NEW_USER}:"
    read -rs DB_NEW_PASS
    echo ""
    [[ -z "$DB_NEW_PASS" ]] && { warn "Password cannot be empty."; return; }

    info "Creating user '$DB_NEW_USER'..."
    mysql -u root <<MYSQL_EOF
CREATE USER IF NOT EXISTS '${DB_NEW_USER}'@'%' IDENTIFIED BY '${DB_NEW_PASS}';
GRANT ALL PRIVILEGES ON *.* TO '${DB_NEW_USER}'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
MYSQL_EOF
    success "User '${DB_NEW_USER}' created with remote access"

    # Open remote bind-address
    for CONF_FILE in \
        /etc/mysql/mariadb.conf.d/50-server.cnf \
        /etc/mysql/mysql.conf.d/mysqld.cnf \
        /etc/mysql/my.cnf; do
        if [[ -f "$CONF_FILE" ]]; then
            sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' "$CONF_FILE"
            success "bind-address → 0.0.0.0 in $CONF_FILE"
            break
        fi
    done

    systemctl restart mysql 2>/dev/null || systemctl restart mariadb 2>/dev/null || true
    success "MySQL/MariaDB restarted"

    ufw allow 3306/tcp comment "MySQL Remote" 2>/dev/null || true
    success "Port 3306 opened in firewall"

    divider
    echo -e "  ${CYAN}Host:${NC}      $(curl -s4 https://ifconfig.me 2>/dev/null || echo 'your-server-ip')"
    echo -e "  ${CYAN}Port:${NC}      3306"
    echo -e "  ${CYAN}User:${NC}      $DB_NEW_USER"
    echo -e "  ${CYAN}Password:${NC}  (as entered above)"
    divider
    echo ""
    read -rp "$(echo -e "${YELLOW}Press Enter to return to menu...${NC}")"
}

# ════════════════════════════════════════════════════════════
#   MAIN MENU + ENTRY POINT
# ════════════════════════════════════════════════════════════
show_main_menu() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo " ██╗  ██╗ ██████╗ █████╗ ███████╗██████╗ ███████╗██████╗ "
    echo " ╚██╗██╔╝██╔════╝██╔══██╗██╔════╝██╔══██╗██╔════╝██╔══██╗"
    echo "  ╚███╔╝ ██║     ███████║███████╗██████╔╝█████╗  ██████╔╝"
    echo "  ██╔██╗ ██║     ██╔══██║╚════██║██╔═══╝ ██╔══╝  ██╔══██╗"
    echo " ██╔╝ ██╗╚██████╗██║  ██║███████║██║     ███████╗██║  ██║"
    echo " ╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝     ╚══════╝╚═╝  ╚═╝"
    echo -e "${NC}"
    echo -e "${PURPLE}${BOLD}           XCASPER Hosting Manager${NC}"
    echo -e "${DIM}           Docs: https://docs.xcasper.space${NC}"
    echo -e "${DIM}           Repo: https://github.com/Casper-Tech-ke/xcasper-panel${NC}"
    divider
    echo ""
    echo -e "  ${CYAN}${BOLD}1)${NC}  Panel Installation"
    echo -e "  ${CYAN}${BOLD}2)${NC}  Wings Installation"
    echo -e "  ${CYAN}${BOLD}3)${NC}  Uninstall Tools"
    echo -e "  ${CYAN}${BOLD}4)${NC}  Cloudflare Setup"
    echo -e "  ${CYAN}${BOLD}5)${NC}  System Information"
    echo -e "  ${CYAN}${BOLD}6)${NC}  Tailscale VPN"
    echo -e "  ${CYAN}${BOLD}7)${NC}  Database Setup (remote access)"
    echo -e "  ${CYAN}${BOLD}0)${NC}  Exit"
    echo ""
    divider
}

# ── Entry point ───────────────────────────────────────────────
check_root

while true; do
    show_main_menu
    ask "Select an option [0-7]:"
    read -r MAIN_CHOICE

    case "$MAIN_CHOICE" in
        1) menu_install_panel  ;;
        2) menu_install_wings  ;;
        3) menu_uninstall      ;;
        4) menu_cloudflare     ;;
        5) menu_system_info    ;;
        6) menu_tailscale      ;;
        7) menu_database       ;;
        0)
            echo ""
            echo -e "${GREEN}${BOLD}  Goodbye from XCASPER Hosting!${NC}"
            divider
            exit 0
            ;;
        *)
            warn "Invalid option — choose 0–7."
            sleep 1
            ;;
    esac
done
