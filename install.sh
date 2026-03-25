#!/usr/bin/env bash
# ============================================================
#   XCASPER Hosting — Automated Installer
#   Usage:  bash <(curl -s https://get.xcasper.space)
#   Repo:   https://github.com/Casper-Tech-ke/xcasper-panel
#   Docs:   https://docs.xcasper.space
# ============================================================
set -eo pipefail

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

# ── Menu ────────────────────────────────────────────────────
choose_component() {
    step "What would you like to install?"
    echo ""
    echo -e "  ${CYAN}1)${NC} Panel only        (web interface)"
    echo -e "  ${CYAN}2)${NC} Wings only         (game server daemon)"
    echo -e "  ${CYAN}3)${NC} Panel + Wings      (full single-server setup)"
    echo ""
    ask "Enter your choice [1/2/3]:"
    read -r INSTALL_CHOICE

    case "$INSTALL_CHOICE" in
        1) INSTALL_PANEL=true;  INSTALL_WINGS=false ;;
        2) INSTALL_PANEL=false; INSTALL_WINGS=true  ;;
        3) INSTALL_PANEL=true;  INSTALL_WINGS=true  ;;
        *) error "Invalid choice. Run the installer again and enter 1, 2, or 3." ;;
    esac
}

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

    # PHP 8.3 — add repo only if not already present
    info "Adding PHP 8.3 repository..."
    PHP_LIST="/etc/apt/sources.list.d/ondrej-ubuntu-php-$(lsb_release -cs).list"
    if [[ ! -f "$PHP_LIST" ]]; then
        LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
        apt-get update -y -qq
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

    divider
    echo -e "${YELLOW}${BOLD}  Important — Save Before Closing:${NC}"
    echo -e "  • These credentials will not be shown again"
    if [[ "${INSTALL_PANEL:-false}" == true ]]; then
        echo -e "  • Configure SMTP:  ${CYAN}https://$PANEL_DOMAIN/admin/settings/mail${NC}"
        echo -e "  • Super Admin tab: Billing, plans, push notifications"
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
#   MAIN
# ════════════════════════════════════════════════════════════
banner
check_root
check_os
check_swap
check_ports
choose_component

if [[ "${INSTALL_PANEL:-false}" == true ]]; then
    collect_panel_inputs
    check_dns "$PANEL_DOMAIN"
fi

if [[ "${INSTALL_WINGS:-false}" == true ]]; then
    collect_wings_inputs
fi

install_dependencies

if [[ "${INSTALL_PANEL:-false}" == true ]]; then
    setup_database
    install_panel_files
    configure_env
    set_permissions
    create_admin_user
    configure_nginx
    obtain_ssl
    setup_queue_worker
    setup_cron
fi

if [[ "${INSTALL_WINGS:-false}" == true ]]; then
    install_wings
fi

configure_firewall
show_summary
