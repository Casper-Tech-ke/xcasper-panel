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

# ── OS detection + check ────────────────────────────────────
check_os() {
    step "Checking Operating System"

    if [[ ! -f /etc/os-release ]]; then
        error "Cannot read /etc/os-release. Supported: Ubuntu 20-24, Debian 11-12."
    fi

    # shellcheck disable=SC1091
    source /etc/os-release
    OS_NAME="${ID:-unknown}"
    OS_VERSION="${VERSION_ID:-unknown}"
    OS_CODENAME="${VERSION_CODENAME:-}"
    OS_PRETTY="${PRETTY_NAME:-$OS_NAME $OS_VERSION}"

    # Determine package manager family
    if command -v apt-get &>/dev/null; then
        PKG_FAMILY="apt"
    elif command -v dnf &>/dev/null; then
        PKG_FAMILY="dnf"
    elif command -v yum &>/dev/null; then
        PKG_FAMILY="yum"
    else
        PKG_FAMILY="unknown"
    fi

    export OS_NAME OS_VERSION OS_CODENAME OS_PRETTY PKG_FAMILY

    case "$OS_NAME" in
        ubuntu)
            case "$OS_VERSION" in
                20.04|22.04|24.04)
                    success "Ubuntu $OS_VERSION ($OS_CODENAME) — fully supported ✓"
                    ;;
                *)
                    warn "Ubuntu $OS_VERSION is not officially tested. Proceeding..."
                    ;;
            esac
            ;;
        debian)
            case "$OS_VERSION" in
                11|12)
                    success "Debian $OS_VERSION ($OS_CODENAME) — fully supported ✓"
                    ;;
                10)
                    warn "Debian 10 (Buster) is end-of-life. Upgrade to Debian 12 is recommended."
                    warn "Proceeding — some packages may be outdated."
                    ;;
                *)
                    warn "Debian $OS_VERSION is not officially tested. Proceeding..."
                    ;;
            esac
            ;;
        almalinux|rocky|centos|rhel|ol)
            warn "Detected: $OS_PRETTY"
            warn "Pterodactyl does NOT officially support RPM-based distros."
            warn "The installer will attempt to proceed using the Remi PHP repo."
            ask "Continue anyway? [y/N]:"
            read -r OS_CONFIRM
            [[ "${OS_CONFIRM,,}" != "y" ]] && \
                error "Cancelled. Use Ubuntu 22.04 or Debian 12 for guaranteed compatibility."
            ;;
        fedora)
            warn "Fedora detected. Community-supported only. Proceeding..."
            ;;
        *)
            warn "Unknown OS: $OS_PRETTY (PKG family: $PKG_FAMILY)"
            warn "Only Ubuntu 20-24 and Debian 11-12 are officially supported."
            if [[ "$PKG_FAMILY" == "unknown" ]]; then
                error "No supported package manager found (apt/dnf/yum). Cannot continue."
            fi
            ask "Continue at your own risk? [y/N]:"
            read -r OS_CONFIRM
            [[ "${OS_CONFIRM,,}" != "y" ]] && error "Cancelled."
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

# ── Collect Wings inputs (kept for compatibility — prompts moved to post-install)
collect_wings_inputs() {
    : # All prompts now happen in wings_post_install after the binary is installed
}

# ── Install dependencies ─────────────────────────────────────
install_dependencies() {
    step "Installing System Dependencies"

    # ── APT-based (Ubuntu / Debian) ──────────────────────────
    if [[ "${PKG_FAMILY:-apt}" == "apt" ]]; then
        export DEBIAN_FRONTEND=noninteractive
        CODENAME="${OS_CODENAME:-$(lsb_release -cs 2>/dev/null)}"

        info "Updating package list..."
        apt-get update -y -qq

        info "Installing core packages..."
        apt-get install -y -qq \
            curl wget git unzip tar \
            software-properties-common \
            apt-transport-https ca-certificates \
            gnupg lsb-release ufw \
            nginx certbot python3-certbot-nginx \
            redis-server dnsutils

        # PHP 8.3 repo
        info "Adding PHP 8.3 repository..."
        case "$OS_NAME" in
            ubuntu)
                PHP_LIST="/etc/apt/sources.list.d/ondrej-ubuntu-php-${CODENAME}.list"
                if [[ ! -f "$PHP_LIST" ]]; then
                    LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
                    apt-get update -y -qq
                fi
                ;;
            debian|*)
                if [[ ! -f "/etc/apt/sources.list.d/sury-php.list" ]]; then
                    curl -fsSL https://packages.sury.org/php/apt.gpg \
                        | gpg --dearmor -o /usr/share/keyrings/sury-php.gpg
                    echo "deb [signed-by=/usr/share/keyrings/sury-php.gpg] \
https://packages.sury.org/php/ ${CODENAME} main" \
                        | tee /etc/apt/sources.list.d/sury-php.list > /dev/null
                    apt-get update -y -qq
                fi
                ;;
        esac

        info "Installing PHP 8.3 and extensions..."
        apt-get install -y -qq \
            php8.3 php8.3-fpm php8.3-cli php8.3-mysql \
            php8.3-mbstring php8.3-xml php8.3-curl \
            php8.3-zip php8.3-gd php8.3-bcmath \
            php8.3-intl php8.3-tokenizer php8.3-fileinfo \
            php8.3-redis php8.3-posix
        success "PHP $(php -r 'echo PHP_VERSION;')"

        # Database — prefer mysql-server, fall back to mariadb-server
        info "Installing database server..."
        if apt-cache show mysql-server &>/dev/null 2>&1; then
            apt-get install -y -qq mysql-server
            DB_SERVICE="mysql"
            success "MySQL installed"
        else
            apt-get install -y -qq mariadb-server
            DB_SERVICE="mariadb"
            success "MariaDB installed"
        fi
        export DB_SERVICE

        # Node.js 20
        info "Installing Node.js 20..."
        NODE_MAJOR=0
        command -v node &>/dev/null && NODE_MAJOR=$(node -v | cut -d. -f1 | tr -d 'v')
        if [[ "$NODE_MAJOR" -lt 18 ]]; then
            curl -fsSL https://deb.nodesource.com/setup_20.x | bash - >/dev/null 2>&1
            apt-get install -y -qq nodejs
        fi

        # Services
        info "Starting core services..."
        systemctl enable redis-server 2>/dev/null && systemctl start redis-server 2>/dev/null || \
            { systemctl enable redis 2>/dev/null && systemctl start redis 2>/dev/null; } || true
        systemctl enable php8.3-fpm && systemctl start php8.3-fpm

    # ── DNF/YUM-based (AlmaLinux / Rocky / CentOS / RHEL) ────
    elif [[ "${PKG_FAMILY}" == "dnf" || "${PKG_FAMILY}" == "yum" ]]; then
        PM="${PKG_FAMILY}"
        export RHEL_MAJOR
        RHEL_MAJOR=$(rpm -E '%{rhel}' 2>/dev/null || echo "9")

        info "Updating packages..."
        $PM update -y -q

        info "Installing EPEL and core tools..."
        $PM install -y epel-release 2>/dev/null || \
            $PM install -y \
                "https://dl.fedoraproject.org/pub/epel/epel-release-latest-${RHEL_MAJOR}.noarch.rpm" \
                2>/dev/null || true
        $PM install -y curl wget git unzip tar gnupg2 \
            ca-certificates ufw nginx certbot python3-certbot-nginx \
            redis dnsutils 2>/dev/null || true

        # PHP 8.3 via Remi
        info "Adding Remi PHP 8.3 repository..."
        if ! rpm -q remi-release &>/dev/null; then
            $PM install -y \
                "https://rpms.remirepo.net/enterprise/remi-release-${RHEL_MAJOR}.rpm" \
                2>/dev/null || \
            $PM install -y \
                "https://rpms.remirepo.net/fedora/remi-release-$(rpm -E '%{fedora}').rpm" \
                2>/dev/null || true
        fi
        $PM module reset php -y 2>/dev/null || true
        $PM module enable php:remi-8.3 -y 2>/dev/null || true
        $PM install -y php php-fpm php-mysqlnd php-mbstring php-xml \
            php-curl php-zip php-gd php-bcmath php-intl \
            php-tokenizer php-json php-redis 2>/dev/null || true
        success "PHP $(php -r 'echo PHP_VERSION;' 2>/dev/null || echo 'installed')"

        # MariaDB
        info "Installing MariaDB..."
        $PM install -y mariadb-server 2>/dev/null || true
        DB_SERVICE="mariadb"
        export DB_SERVICE
        systemctl enable mariadb && systemctl start mariadb || true

        # Node.js 20
        info "Installing Node.js 20..."
        curl -fsSL https://rpm.nodesource.com/setup_20.x | bash - >/dev/null 2>&1
        $PM install -y nodejs 2>/dev/null || true

        # Services
        info "Starting core services..."
        systemctl enable redis 2>/dev/null && systemctl start redis 2>/dev/null || true
        systemctl enable php-fpm 2>/dev/null && systemctl start php-fpm 2>/dev/null || true
    fi

    # ── Universal: Composer ───────────────────────────────────
    info "Installing Composer..."
    if ! command -v composer &>/dev/null; then
        curl -sS https://getcomposer.org/installer \
            | php -- --install-dir=/usr/local/bin --filename=composer --quiet
    fi
    success "Composer $(composer --version --no-ansi 2>/dev/null | awk '{print $3}')"

    # ── Universal: Yarn ───────────────────────────────────────
    info "Installing Yarn..."
    npm install -g yarn --quiet
    success "Yarn $(yarn --version 2>/dev/null)"

    success "All dependencies installed"
}

# ── Setup Database (MySQL or MariaDB) ────────────────────────
setup_database() {
    step "Setting Up Database"

    # Use the DB_SERVICE detected during install_dependencies
    # Fall back to auto-detect if install_dependencies wasn't called
    if [[ -z "${DB_SERVICE:-}" ]]; then
        if systemctl list-unit-files 2>/dev/null | grep -q "^mysql.service"; then
            DB_SERVICE="mysql"
        elif systemctl list-unit-files 2>/dev/null | grep -q "^mariadb.service"; then
            DB_SERVICE="mariadb"
        else
            DB_SERVICE="mysql"
        fi
        export DB_SERVICE
    fi

    info "Starting ${DB_SERVICE}..."
    systemctl enable "$DB_SERVICE" 2>/dev/null || true
    systemctl start  "$DB_SERVICE" 2>/dev/null || true

    # Wait for the DB to be ready (try multiple socket paths)
    DB_READY=false
    for i in {1..20}; do
        if mysqladmin ping --silent 2>/dev/null; then
            DB_READY=true; break
        fi
        for SOCK in /var/run/mysqld/mysqld.sock /run/mysqld/mysqld.sock \
                    /var/lib/mysql/mysql.sock /run/mysql/mysql.sock; do
            if [[ -S "$SOCK" ]] && mysqladmin ping --socket="$SOCK" --silent 2>/dev/null; then
                DB_READY=true; break 2
            fi
        done
        info "Waiting for ${DB_SERVICE} to be ready... ($i/20)"
        sleep 2
    done

    if [[ "$DB_READY" != "true" ]]; then
        warn "Database did not respond in time — attempting to continue anyway..."
    fi

    info "Creating database and user..."
    mysql -u root 2>/dev/null << SQL || \
    mysql -u root -e "
CREATE DATABASE IF NOT EXISTS xcasper_panel CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
DROP USER IF EXISTS 'xcasper'@'localhost';
CREATE USER 'xcasper'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON xcasper_panel.* TO 'xcasper'@'localhost';
FLUSH PRIVILEGES;" 2>/dev/null || true
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

# ── Detect web server user (www-data on Debian/Ubuntu, nginx on RPM)
detect_web_user() {
    if id "www-data" &>/dev/null; then
        WEB_USER="www-data"
    elif id "nginx" &>/dev/null; then
        WEB_USER="nginx"
    elif id "apache" &>/dev/null; then
        WEB_USER="apache"
    else
        WEB_USER="www-data"  # fallback, create if needed
        useradd -r -s /sbin/nologin www-data 2>/dev/null || true
    fi
    export WEB_USER
}

# ── Set Permissions ───────────────────────────────────────────
set_permissions() {
    step "Setting File Permissions"
    detect_web_user

    chown -R "${WEB_USER}:${WEB_USER}" /var/www/xcasper-panel
    chmod -R 755 /var/www/xcasper-panel
    chmod -R 700 /var/www/xcasper-panel/storage /var/www/xcasper-panel/bootstrap/cache

    success "Permissions set (owner: ${WEB_USER})"
}

# ── Create Admin User ─────────────────────────────────────────
create_admin_user() {
    step "Creating Admin Account"
    detect_web_user

    cd /var/www/xcasper-panel

    sudo -u "${WEB_USER}" php artisan p:user:make \
        --email="$ADMIN_EMAIL" \
        --username="$ADMIN_USER" \
        --name-first="$ADMIN_FIRST" \
        --name-last="$ADMIN_LAST" \
        --password="$ADMIN_PASSWORD" \
        --admin=1 \
        --no-interaction

    success "Admin account created: ${BOLD}$ADMIN_USER${NC}"
}

# ── Setup Super Admin Key ─────────────────────────────────────
setup_super_admin_key() {
    step "Super Admin Key Setup"
    detect_web_user

    PANEL_DIR="/var/www/xcasper-panel"

    # Suggest a key or let the user pick one
    SUGGESTED_KEY="CasperXK-$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 12)"
    echo ""
    echo -e "  ${DIM}The super admin key protects the ${BOLD}/super-admin${DIM} control panel.${NC}"
    echo -e "  ${DIM}Keep this key secret — it grants full billing, plan, and user control.${NC}"
    echo ""
    ask "Super admin key (press Enter to auto-generate: ${BOLD}$SUGGESTED_KEY${NC}):"
    read -r SUPER_KEY
    SUPER_KEY="${SUPER_KEY:-$SUGGESTED_KEY}"

    # Write / replace in .env
    if grep -q "^XCASPER_SUPER_KEY=" "$PANEL_DIR/.env" 2>/dev/null; then
        sed -i "s|^XCASPER_SUPER_KEY=.*|XCASPER_SUPER_KEY=${SUPER_KEY}|" "$PANEL_DIR/.env"
    else
        echo "XCASPER_SUPER_KEY=${SUPER_KEY}" >> "$PANEL_DIR/.env"
    fi

    # Clear cached config so the new key takes effect immediately
    cd "$PANEL_DIR"
    sudo -u "${WEB_USER}" php artisan config:clear --quiet 2>/dev/null || true

    success "Super admin key saved: ${BOLD}$SUPER_KEY${NC}"
    echo ""
    echo -e "  ${CYAN}Super Admin URL:${NC}  ${BOLD}https://${PANEL_DOMAIN}/super-admin${NC}"
    echo -e "  ${DIM}Enter the key above when prompted on that page to access billing,${NC}"
    echo -e "  ${DIM}plans (Basic KES 50 / Pro KES 100 / Admin KES 200), wallets, and${NC}"
    echo -e "  ${DIM}push notification settings.${NC}"
    echo ""
}

# ── Mail Config (standalone helper — also used by menu) ───────
_do_mail_config() {
    PANEL_DIR="/var/www/xcasper-panel"
    if [[ ! -d "$PANEL_DIR" ]]; then
        warn "Panel not found at $PANEL_DIR — install the panel first."
        echo ""
        read -rp "$(echo -e "${YELLOW}Press Enter to continue...${NC}")"
        return
    fi
    detect_web_user

    echo ""
    echo -e "  ${DIM}Common providers:${NC}"
    echo -e "  ${DIM}  Gmail   → smtp.gmail.com         port 587  encryption: tls${NC}"
    echo -e "  ${DIM}  Outlook → smtp.office365.com     port 587  encryption: tls${NC}"
    echo -e "  ${DIM}  Brevo   → smtp-relay.brevo.com   port 587  encryption: tls${NC}"
    echo -e "  ${DIM}  Mailgun → smtp.mailgun.org        port 587  encryption: tls${NC}"
    echo ""

    ask "SMTP Host (e.g. smtp.gmail.com):"
    read -r MAIL_HOST
    [[ -z "$MAIL_HOST" ]] && { warn "Host cannot be empty."; read -rp "Press Enter..."; return; }

    ask "SMTP Port [default: 587]:"
    read -r MAIL_PORT
    MAIL_PORT="${MAIL_PORT:-587}"

    ask "SMTP Username (usually your full email):"
    read -r MAIL_USER
    [[ -z "$MAIL_USER" ]] && { warn "Username cannot be empty."; read -rp "Press Enter..."; return; }

    ask "SMTP Password:"
    read -rs MAIL_PASS
    echo ""
    [[ -z "$MAIL_PASS" ]] && { warn "Password cannot be empty."; read -rp "Press Enter..."; return; }

    ask "From Address [default: no-reply@${PANEL_DOMAIN:-yourdomain.com}]:"
    read -r MAIL_FROM
    MAIL_FROM="${MAIL_FROM:-no-reply@${PANEL_DOMAIN:-yourdomain.com}}"

    ask "From Name [default: XCASPER Hosting]:"
    read -r MAIL_NAME
    MAIL_NAME="${MAIL_NAME:-XCASPER Hosting}"

    ask "Encryption [tls/ssl/none] [default: tls]:"
    read -r MAIL_ENC
    MAIL_ENC="${MAIL_ENC:-tls}"

    # Helper — update or append a .env key
    _set_env_mail() {
        local K="$1" V="$2"
        if grep -q "^${K}=" "$PANEL_DIR/.env" 2>/dev/null; then
            sed -i "s|^${K}=.*|${K}=${V}|" "$PANEL_DIR/.env"
        else
            echo "${K}=${V}" >> "$PANEL_DIR/.env"
        fi
    }

    _set_env_mail "MAIL_DRIVER"       "smtp"
    _set_env_mail "MAIL_HOST"         "$MAIL_HOST"
    _set_env_mail "MAIL_PORT"         "$MAIL_PORT"
    _set_env_mail "MAIL_USERNAME"     "$MAIL_USER"
    _set_env_mail "MAIL_PASSWORD"     "$MAIL_PASS"
    _set_env_mail "MAIL_ENCRYPTION"   "$MAIL_ENC"
    _set_env_mail "MAIL_FROM_ADDRESS" "$MAIL_FROM"
    _set_env_mail "MAIL_FROM_NAME"    "\"${MAIL_NAME}\""

    cd "$PANEL_DIR"
    sudo -u "${WEB_USER}" php artisan config:clear --quiet 2>/dev/null || true

    success "SMTP configured"
    echo ""
    echo -e "  ${DIM}Test it: reset a user's password or create a new account — a verification${NC}"
    echo -e "  ${DIM}email should arrive from ${BOLD}$MAIL_FROM${DIM}.${NC}"
    echo ""
}

# ── Configure Nginx ───────────────────────────────────────────
configure_nginx() {
    step "Configuring Nginx"

    # Stop any conflicting service on port 80
    systemctl stop apache2 2>/dev/null || true

    # Detect PHP-FPM socket (varies by OS and install method)
    PHP_FPM_SOCK="/run/php/php8.3-fpm.sock"
    for CANDIDATE in \
            /run/php/php8.3-fpm.sock \
            /var/run/php/php8.3-fpm.sock \
            /run/php-fpm/www.sock \
            /var/run/php-fpm/www.sock; do
        if [[ -S "$CANDIDATE" ]]; then
            PHP_FPM_SOCK="$CANDIDATE"
            break
        fi
    done
    info "PHP-FPM socket: $PHP_FPM_SOCK"

    # Determine nginx vhost path (Debian/Ubuntu use sites-available, RPM uses conf.d)
    if [[ -d /etc/nginx/sites-available ]]; then
        NGINX_CONF="/etc/nginx/sites-available/xcasper-panel"
        NGINX_ENABLED="/etc/nginx/sites-enabled/xcasper-panel"
        USE_SITES_ENABLED=true
    else
        NGINX_CONF="/etc/nginx/conf.d/xcasper-panel.conf"
        NGINX_ENABLED=""
        USE_SITES_ENABLED=false
    fi

    cat > "$NGINX_CONF" << NGINX
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
        fastcgi_pass unix:${PHP_FPM_SOCK};
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

    if [[ "$USE_SITES_ENABLED" == "true" ]]; then
        ln -sf "$NGINX_CONF" "$NGINX_ENABLED"
        rm -f /etc/nginx/sites-enabled/default
    fi

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
    detect_web_user

    DB_SVC="${DB_SERVICE:-mysql}"
    # Service unit — variables expand from shell
    cat > /etc/systemd/system/xcasper-queue.service << SERVICE
[Unit]
Description=XCASPER Panel Queue Worker
After=network.target ${DB_SVC}.service redis.service

[Service]
User=${WEB_USER}
Group=${WEB_USER}
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

    success "Queue worker running (user: ${WEB_USER})"
}

# ── Setup Cron ────────────────────────────────────────────────
setup_cron() {
    step "Setting Up Scheduled Tasks (Cron)"

    detect_web_user
    CRON_LINE="* * * * * php /var/www/xcasper-panel/artisan schedule:run >> /dev/null 2>&1"
    EXISTING_CRON=$(crontab -l -u "${WEB_USER}" 2>/dev/null || true)

    if echo "$EXISTING_CRON" | grep -qF "artisan schedule:run"; then
        info "Cron job already present — skipping"
    else
        printf '%s\n%s\n' "$EXISTING_CRON" "$CRON_LINE" | crontab -u "${WEB_USER}" -
        success "Cron job added for ${WEB_USER}"
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

    # ── Docker ───────────────────────────────────────────────
    info "Installing Docker..."
    if ! command -v docker &>/dev/null; then
        curl -fsSL https://get.docker.com | CHANNEL=stable bash >/dev/null 2>&1
        systemctl enable --now docker >/dev/null 2>&1
    fi
    DOCKER_VER=$(docker --version | awk '{print $3}' | tr -d ',')
    success "Docker $DOCKER_VER"
    usermod -aG docker pterodactyl 2>/dev/null || true

    # ── GRUB swap/memory accounting (required by Docker cgroups) ─
    GRUB_FILE="/etc/default/grub"
    if [[ -f "$GRUB_FILE" ]]; then
        if ! grep -q "swapaccount=1" "$GRUB_FILE"; then
            info "Enabling swap memory accounting in GRUB..."
            sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="swapaccount=1"/' "$GRUB_FILE"
            update-grub >/dev/null 2>&1 || \
                grub2-mkconfig -o /boot/grub2/grub.cfg >/dev/null 2>&1 || true
            success "GRUB updated — swap accounting enabled (active after reboot)"
        else
            info "GRUB swap accounting already enabled"
        fi
    fi

    # ── Architecture detection ────────────────────────────────
    ARCH=$(uname -m)
    [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]] && ARCH="arm64" || ARCH="amd64"
    info "Detected architecture: $ARCH"

    # ── Wings binary — XCASPER build first, fall back to official ──
    info "Downloading XCASPER Wings binary..."
    mkdir -p /etc/pterodactyl

    XCASPER_WINGS_RELEASE=$(curl -sf \
        "https://api.github.com/repos/Casper-Tech-ke/xcasper-wings/releases/latest" \
        | grep '"tag_name"' | cut -d '"' -f4 || true)

    if [[ -n "$XCASPER_WINGS_RELEASE" ]]; then
        info "Found XCASPER Wings release: $XCASPER_WINGS_RELEASE"
        WINGS_URL="https://github.com/Casper-Tech-ke/xcasper-wings/releases/download/${XCASPER_WINGS_RELEASE}/wings_linux_${ARCH}"
        WINGS_VERSION="$XCASPER_WINGS_RELEASE"
    else
        info "No XCASPER custom release found — using official Pterodactyl Wings..."
        WINGS_VERSION=$(curl -s "https://api.github.com/repos/pterodactyl/wings/releases/latest" \
            | grep '"tag_name"' | cut -d '"' -f4)
        WINGS_URL="https://github.com/pterodactyl/wings/releases/download/${WINGS_VERSION}/wings_linux_${ARCH}"
    fi

    curl -fsSL "$WINGS_URL" -o /usr/local/bin/wings
    chmod +x /usr/local/bin/wings
    success "Wings $WINGS_VERSION installed at /usr/local/bin/wings [$ARCH]"

    # ── Self-signed SSL cert for Wings API port 8080 ─────────
    info "Generating Wings API SSL certificate..."
    mkdir -p /etc/certs/wing
    openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 \
        -subj "/C=NA/ST=NA/L=NA/O=XCASPER Hosting/CN=Wings SSL" \
        -keyout /etc/certs/wing/privkey.pem \
        -out    /etc/certs/wing/fullchain.pem >/dev/null 2>&1
    success "SSL certificate generated at /etc/certs/wing/"

    # ── Systemd service ───────────────────────────────────────
    cat > /etc/systemd/system/wings.service << SERVICE
[Unit]
Description=XCASPER Wings Daemon
After=docker.service
Requires=docker.service
PartOf=docker.service

[Service]
User=root
WorkingDirectory=/etc/pterodactyl
LimitNOFILE=4096
PIDFile=/var/run/wings/daemon.pid
ExecStart=/usr/local/bin/wings
Restart=on-failure
RestartSec=5s
StartLimitInterval=180
StartLimitBurst=30
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=xcasper-wings

[Install]
WantedBy=multi-user.target
SERVICE

    systemctl daemon-reload
    systemctl enable wings >/dev/null 2>&1
    success "Wings service enabled"

    # ── 'wing' helper command ─────────────────────────────────
    cat > /usr/local/bin/wing << 'WINGHELPER'
#!/bin/bash
C='\033[1;36m' Y='\033[1;33m' G='\033[1;32m' NC='\033[0m'
echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${Y}  XCASPER Wings Quick Reference${NC}"
echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${C}Start:${NC}    ${G}sudo systemctl start wings${NC}"
echo -e "${C}Stop:${NC}     ${G}sudo systemctl stop wings${NC}"
echo -e "${C}Restart:${NC}  ${G}sudo systemctl restart wings${NC}"
echo -e "${C}Status:${NC}   ${G}sudo systemctl status wings${NC}"
echo -e "${C}Logs:${NC}     ${G}sudo journalctl -u wings -f${NC}"
echo -e "${C}Config:${NC}   ${G}nano /etc/pterodactyl/config.yml${NC}"
echo -e "${Y}  Port 8080 must be open and reachable from the panel.${NC}"
echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
WINGHELPER
    chmod +x /usr/local/bin/wing
    success "'wing' helper installed — type 'wing' anytime for quick commands"

    # ── Post-install: prompt to auto-configure ────────────────
    wings_post_install
}

# ── Wings post-install auto-configure prompt ──────────────────
wings_post_install() {
    echo ""
    divider
    echo -e "${GREEN}${BOLD}  Wings Installed Successfully!${NC}"
    echo ""
    echo -e "  ${YELLOW}${BOLD}Next Steps:${NC}"
    echo -e "  ${CYAN}1.${NC} In your ${BOLD}Panel Admin → Nodes → [your node] → Configuration${NC} tab"
    echo -e "     you will find the ${BOLD}UUID${NC}, ${BOLD}Token ID${NC} and ${BOLD}Token${NC} for this node."
    echo -e "  ${CYAN}2.${NC} Come back here — we will write the config file for you right now."
    echo -e "  ${CYAN}3.${NC} Type ${BOLD}wing${NC} anytime to see quick commands."
    echo ""
    divider
    echo ""
    ask "Auto-configure Wings with your panel token now? [y/N]:"
    read -r WINGS_AUTO

    if [[ "${WINGS_AUTO,,}" == "y" ]]; then
        echo ""
        echo -e "  ${DIM}Find these values at: Panel Admin → Nodes → [node] → Configuration tab${NC}"
        echo ""

        ask "Panel URL (e.g. https://panel.xcasper.space):"
        read -r WINGS_REMOTE
        WINGS_REMOTE="${WINGS_REMOTE%/}"
        if [[ -z "$WINGS_REMOTE" ]]; then
            warn "Panel URL is required — skipping auto-config."
            wings_show_manual; return
        fi

        ask "Node UUID (from Configuration tab — press Enter to auto-generate):"
        read -r WINGS_UUID_INPUT
        WINGS_UUID="${WINGS_UUID_INPUT:-$(cat /proc/sys/kernel/random/uuid)}"
        [[ -z "$WINGS_UUID_INPUT" ]] && info "Auto-generated UUID: $WINGS_UUID"

        ask "Token ID (from Configuration tab):"
        read -r WINGS_TOKEN_ID
        if [[ -z "$WINGS_TOKEN_ID" ]]; then
            warn "Token ID is required — skipping auto-config."
            wings_show_manual; return
        fi

        ask "Token (from Configuration tab — input is hidden):"
        read -rs WINGS_TOKEN_VAL
        echo ""
        if [[ -z "$WINGS_TOKEN_VAL" ]]; then
            warn "Token is required — skipping auto-config."
            wings_show_manual; return
        fi

        info "Writing /etc/pterodactyl/config.yml..."
        mkdir -p /etc/pterodactyl
        cat > /etc/pterodactyl/config.yml << WCONF
debug: false
uuid: "${WINGS_UUID}"
token_id: "${WINGS_TOKEN_ID}"
token: "${WINGS_TOKEN_VAL}"
remote: "${WINGS_REMOTE}"
api:
  host: "0.0.0.0"
  port: 8080
  ssl:
    enabled: true
    cert: /etc/certs/wing/fullchain.pem
    key: /etc/certs/wing/privkey.pem
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
        success "Configuration saved to /etc/pterodactyl/config.yml"

        info "Starting Wings daemon..."
        systemctl start wings
        sleep 3

        WINGS_LIVE=$(systemctl is-active wings 2>/dev/null)
        if [[ "$WINGS_LIVE" == "active" ]]; then
            success "Wings is running!"
        else
            warn "Wings may not have started cleanly — check logs:"
            echo -e "     ${BOLD}journalctl -u wings -f${NC}"
        fi

        echo ""
        divider
        echo -e "${GREEN}${BOLD}  Wings auto-configuration complete!${NC}"
        echo ""
        echo -e "  ${CYAN}Status:${NC}  ${BOLD}systemctl status wings${NC}"
        echo -e "  ${CYAN}Logs:${NC}    ${BOLD}journalctl -u wings -f${NC}"
        echo -e "  ${CYAN}Helper:${NC}  Type ${BOLD}wing${NC} anytime for quick commands"
        echo ""
        divider
    else
        wings_show_manual
    fi
}

# ── Wings manual config instructions ─────────────────────────
wings_show_manual() {
    echo ""
    divider
    echo -e "${YELLOW}${BOLD}  Manual Wings Configuration${NC}"
    echo ""
    echo -e "  ${CYAN}1.${NC} Go to your panel → Admin → Nodes → [your node] → Configuration tab"
    echo -e "  ${CYAN}2.${NC} Copy the values and edit the config file:"
    echo -e "     ${BOLD}nano /etc/pterodactyl/config.yml${NC}"
    echo -e "  ${CYAN}3.${NC} Set ${BOLD}uuid${NC}, ${BOLD}token_id${NC}, ${BOLD}token${NC} and ${BOLD}remote${NC} from the panel"
    echo -e "  ${CYAN}4.${NC} Start Wings:"
    echo -e "     ${BOLD}systemctl start wings${NC}"
    echo ""
    echo -e "  Type ${BOLD}wing${NC} anytime for a quick command reference."
    echo ""
    divider
}

# ── Post-install next-steps guidance ─────────────────────────
_show_next_steps() {
    echo ""
    divider
    echo -e "${YELLOW}${BOLD}  ── What to do next ──────────────────────────────────────${NC}"
    echo ""
    if [[ "${INSTALL_PANEL:-false}" == true ]]; then
        echo -e "  ${GREEN}1.${NC} Open your panel in a browser:"
        echo -e "     ${CYAN}${BOLD}https://${PANEL_DOMAIN}${NC}"
        echo ""
        echo -e "  ${GREEN}2.${NC} Log in with your admin credentials and verify everything loads."
        echo ""
        echo -e "  ${GREEN}3.${NC} Visit the ${BOLD}Super Admin${NC} panel to manage billing, plans & notifications:"
        echo -e "     ${CYAN}${BOLD}https://${PANEL_DOMAIN}/super-admin${NC}"
        echo -e "     ${DIM}(enter the super admin key you just set when prompted)${NC}"
        echo ""
        echo -e "  ${GREEN}4.${NC} In the Super Admin panel you can:"
        echo -e "     ${DIM}• Activate / deactivate plans (Basic KES 50 · Pro KES 100 · Admin KES 200/mo)${NC}"
        echo -e "     ${DIM}• Top up user KES wallets and view billing history${NC}"
        echo -e "     ${DIM}• Send push notifications to all users${NC}"
        echo -e "     ${DIM}• View Paystack transactions and manage subscriptions${NC}"
        echo ""
        if [[ -z "${MAIL_HOST:-}" ]]; then
            echo -e "  ${GREEN}5.${NC} Configure SMTP mail (for email verification & password resets):"
            echo -e "     Run the installer again → Panel Control Center → ${BOLD}Configure SMTP Mail${NC}"
            echo -e "     or visit: ${CYAN}https://${PANEL_DOMAIN}/admin/settings/mail${NC}"
            echo ""
        fi
        echo -e "  ${GREEN}6.${NC} Add game nodes: ${CYAN}https://${PANEL_DOMAIN}/admin/nodes${NC}"
        echo -e "     ${DIM}Then run the installer again → Install Wings Daemon on each node server.${NC}"
        echo ""
    fi
    divider
}

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
        echo -e "${CYAN}  Panel URL:${NC}        ${BOLD}https://$PANEL_DOMAIN${NC}"
        echo -e "${CYAN}  Admin Email:${NC}      ${BOLD}$ADMIN_EMAIL${NC}"
        echo -e "${CYAN}  Admin Username:${NC}   ${BOLD}$ADMIN_USER${NC}"
        echo -e "${CYAN}  Admin Password:${NC}   ${BOLD}$ADMIN_PASSWORD${NC}"
        echo -e "${CYAN}  DB Password:${NC}      ${BOLD}$DB_PASSWORD${NC}"
        echo ""
        echo -e "${CYAN}  Super Admin URL:${NC}  ${BOLD}https://$PANEL_DOMAIN/super-admin${NC}"
        echo -e "${CYAN}  Super Admin Key:${NC}  ${BOLD}${SUPER_KEY:-see .env → XCASPER_SUPER_KEY}${NC}"
        echo -e "  ${DIM}(Use this key to access billing, KES wallets, plans & push notifications)${NC}"
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
    echo -e "${YELLOW}${BOLD}  Important — Save This Before Closing:${NC}"
    echo -e "  ${DIM}These credentials will NOT be shown again.${NC}"
    if [[ "${INSTALL_PANEL:-false}" == true ]]; then
        echo -e "  • Super Admin:  ${CYAN}https://$PANEL_DOMAIN/super-admin${NC}  (key above)"
        if [[ -z "${MAIL_HOST:-}" ]]; then
            echo -e "  • SMTP Mail:    Not yet configured — do it from the Panel Control Center menu"
        else
            echo -e "  • SMTP Mail:    ${GREEN}Configured ✓${NC}  (host: $MAIL_HOST)"
        fi
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
        echo -e "  ${CYAN}4)${NC}  Configure SMTP Mail"
        echo -e "  ${CYAN}5)${NC}  Change Super Admin Key"
        echo -e "  ${CYAN}6)${NC}  Uninstall Panel"
        echo -e "  ${CYAN}0)${NC}  Back to main menu"
        echo ""
        divider
        ask "Choose [0-6]:"
        read -r PANEL_CHOICE

        case "$PANEL_CHOICE" in
            1) _panel_install            ;;
            2) _panel_create_user        ;;
            3) _panel_update             ;;
            4) _panel_mail_config        ;;
            5) _panel_super_admin_key    ;;
            6) _panel_uninstall          ;;
            0) return 0                  ;;
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
    setup_super_admin_key
    configure_nginx
    obtain_ssl
    setup_cloudflare
    setup_queue_worker
    setup_cron
    configure_firewall

    # ── Optional SMTP setup right after install ────────────────
    echo ""
    divider
    ask "Do you want to configure SMTP mail now? [y/N]:"
    read -r SETUP_MAIL_NOW
    if [[ "${SETUP_MAIL_NOW,,}" == "y" ]]; then
        echo ""
        step "SMTP Mail Setup"
        divider
        _do_mail_config
    else
        info "Skipped — you can configure mail later from the Panel Control Center menu."
    fi

    show_summary
    _show_next_steps

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

    detect_web_user
    info "Running artisan user creation wizard..."
    echo ""
    cd "$PANEL_DIR"
    sudo -u "${WEB_USER}" php artisan p:user:make

    success "User created successfully"
    echo ""
    read -rp "$(echo -e "${YELLOW}Press Enter to return to menu...${NC}")"
}

# ── Panel: mail config (menu wrapper) ────────────────────────
_panel_mail_config() {
    clear
    banner
    step "Configure SMTP Mail"
    divider

    # Need PANEL_DOMAIN for defaults inside _do_mail_config
    PANEL_DOMAIN="${PANEL_DOMAIN:-$(grep -oP '(?<=server_name ).*(?=;)' /etc/nginx/sites-enabled/xcasper-panel 2>/dev/null | head -1 || echo 'panel.xcasper.space')}"

    _do_mail_config

    read -rp "$(echo -e "${YELLOW}Press Enter to return to menu...${NC}")"
}

# ── Panel: change super admin key (menu wrapper) ──────────────
_panel_super_admin_key() {
    clear
    banner
    step "Change Super Admin Key"
    divider

    PANEL_DIR="/var/www/xcasper-panel"
    if [[ ! -d "$PANEL_DIR" ]]; then
        warn "Panel not found at $PANEL_DIR — install the panel first."
        echo ""
        read -rp "$(echo -e "${YELLOW}Press Enter to continue...${NC}")"
        return
    fi

    # Detect current domain from nginx config so the URL hint is accurate
    PANEL_DOMAIN="${PANEL_DOMAIN:-$(grep -oP '(?<=server_name ).*(?=;)' /etc/nginx/sites-enabled/xcasper-panel 2>/dev/null | head -1 || echo 'panel.xcasper.space')}"

    # Show current key if set
    CURRENT_KEY=$(grep "^XCASPER_SUPER_KEY=" "$PANEL_DIR/.env" 2>/dev/null | cut -d= -f2-)
    if [[ -n "$CURRENT_KEY" ]]; then
        echo ""
        echo -e "  ${DIM}Current key: ${BOLD}$CURRENT_KEY${NC}"
    fi

    setup_super_admin_key

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

    detect_web_user
    cd "$PANEL_DIR"

    info "Enabling maintenance mode..."
    sudo -u "${WEB_USER}" php artisan down

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
    sudo -u "${WEB_USER}" php artisan view:clear
    sudo -u "${WEB_USER}" php artisan config:clear
    sudo -u "${WEB_USER}" php artisan route:clear

    info "Running migrations..."
    sudo -u "${WEB_USER}" php artisan migrate --seed --force

    info "Setting permissions..."
    chmod -R 755 storage/* bootstrap/cache/
    chown -R "${WEB_USER}:${WEB_USER}" "$PANEL_DIR"

    info "Restarting queue worker..."
    sudo -u "${WEB_USER}" php artisan queue:restart
    systemctl restart xcasper-queue 2>/dev/null || true

    info "Taking panel out of maintenance mode..."
    sudo -u "${WEB_USER}" php artisan up

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

    crontab -l -u "${WEB_USER}" 2>/dev/null \
        | grep -v 'artisan schedule:run' \
        | crontab -u "${WEB_USER}" - 2>/dev/null || true

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

            crontab -l -u "${WEB_USER}" 2>/dev/null \
                | grep -v 'artisan schedule:run' \
                | crontab -u "${WEB_USER}" - 2>/dev/null || true

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
            rm -rf /etc/certs/wing
            rm -f /usr/local/bin/wings
            rm -f /usr/local/bin/wing
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

        # ── Live status badge ─────────────────────────────────
        CF_SVC_STATUS=$(systemctl is-active cloudflared 2>/dev/null || echo "not installed")
        CF_VER=$(cloudflared --version 2>&1 | head -1 | awk '{print $3}' 2>/dev/null || true)
        if [[ "$CF_SVC_STATUS" == "active" ]]; then
            echo -e "  ${GREEN}${BOLD}☁  Cloudflare Tunnel: RUNNING${NC}  ${DIM}($CF_VER)${NC}"
        elif [[ "$CF_SVC_STATUS" == "inactive" ]]; then
            echo -e "  ${YELLOW}${BOLD}☁  Cloudflare Tunnel: STOPPED${NC}  ${DIM}($CF_VER)${NC}"
        else
            echo -e "  ${DIM}☁  Cloudflare Tunnel: not installed${NC}"
        fi
        echo ""
        echo -e "  ${CYAN}1)${NC} Install / Setup Tunnel"
        echo -e "  ${CYAN}2)${NC} Status & Logs"
        echo -e "  ${CYAN}3)${NC} Restart Tunnel"
        echo -e "  ${CYAN}4)${NC} Uninstall Completely"
        echo -e "  ${CYAN}0)${NC} Back to main menu"
        echo ""
        divider
        ask "Choose [0-4]:"
        read -r CF_CHOICE

        case "$CF_CHOICE" in
            1)
                clear
                banner
                step "Installing Cloudflared"
                divider

                # ── Step 1: Install package (cross-distro) ────
                info "Step 1: Installing cloudflared package..."
                if command -v cloudflared &>/dev/null; then
                    info "cloudflared already installed — skipping package install"
                else
                    if [[ "${PKG_FAMILY:-apt}" == "apt" ]]; then
                        mkdir -p --mode=0755 /usr/share/keyrings
                        curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg \
                            | tee /usr/share/keyrings/cloudflare-main.gpg > /dev/null
                        echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] \
https://pkg.cloudflare.com/cloudflared any main" \
                            | tee /etc/apt/sources.list.d/cloudflared.list > /dev/null
                        apt-get update -qq
                        apt-get install -y cloudflared
                    else
                        # RPM-based (AlmaLinux / Rocky / CentOS)
                        curl -fsSL https://pkg.cloudflare.com/cloudflared-ascii.repo \
                            | tee /etc/yum.repos.d/cloudflared.repo > /dev/null
                        if command -v dnf &>/dev/null; then
                            dnf install -y cloudflared
                        else
                            yum install -y cloudflared
                        fi
                    fi
                fi

                if ! command -v cloudflared &>/dev/null; then
                    warn "cloudflared installation failed — check your internet or OS."
                    echo ""
                    read -rp "$(echo -e "${YELLOW}Press Enter to continue...${NC}")"
                    continue
                fi
                success "cloudflared $(cloudflared --version 2>&1 | head -1 | awk '{print $3}')"

                # ── Step 2: Remove any stale service ──────────
                info "Step 2: Checking for existing service..."
                if systemctl list-units --type=service 2>/dev/null | grep -q cloudflared; then
                    warn "Existing cloudflared service found — removing before reinstall..."
                    cloudflared service uninstall 2>/dev/null || true
                    success "Old service removed"
                else
                    info "No existing service found — clean install"
                fi

                # ── Step 3: Prompt for tunnel token ───────────
                echo ""
                info "Step 3: Configure tunnel token"
                echo ""
                echo -e "  ${DIM}Get your token from:${NC}"
                echo -e "  ${BOLD}Cloudflare Dashboard → Zero Trust → Networks → Tunnels${NC}"
                echo -e "  ${DIM}Create or select a tunnel → Install connector → copy the token${NC}"
                echo -e "  ${DIM}You can paste the full 'cloudflared service install <TOKEN>' command or just the token.${NC}"
                echo ""
                ask "Paste tunnel token (or full install command):"
                read -r USER_INPUT

                CF_TUNNEL_TOKEN=$(echo "$USER_INPUT" \
                    | sed 's/sudo cloudflared service install //g' \
                    | sed 's/cloudflared service install //g' \
                    | xargs)

                if [[ -z "$CF_TUNNEL_TOKEN" ]]; then
                    warn "Empty token — service not installed. Run this menu again when you have your token."
                else
                    # ── Step 4: Install and start service ─────
                    info "Step 4: Installing and starting tunnel service..."
                    cloudflared service install "$CF_TUNNEL_TOKEN"
                    sleep 2
                    if systemctl is-active --quiet cloudflared; then
                        success "Cloudflare Tunnel is running!"
                    else
                        warn "Service installed but not running yet."
                        echo -e "  ${DIM}Check: ${BOLD}systemctl status cloudflared${NC}"
                        echo -e "  ${DIM}Logs:  ${BOLD}journalctl -u cloudflared -f${NC}"
                    fi
                fi

                echo ""
                divider
                echo -e "  ${CYAN}Status:${NC}  ${BOLD}systemctl status cloudflared${NC}"
                echo -e "  ${CYAN}Logs:${NC}    ${BOLD}journalctl -u cloudflared -f${NC}"
                echo -e "  ${CYAN}Restart:${NC} ${BOLD}systemctl restart cloudflared${NC}"
                echo ""
                read -rp "$(echo -e "${YELLOW}Press Enter to continue...${NC}")"
                ;;

            2)
                clear
                banner
                step "Cloudflare Tunnel Status"
                divider
                echo ""
                if ! command -v cloudflared &>/dev/null; then
                    warn "cloudflared is not installed."
                else
                    echo -e "  ${CYAN}Service status:${NC}"
                    systemctl status cloudflared --no-pager -l 2>/dev/null || true
                    echo ""
                    divider
                    echo -e "  ${CYAN}Recent logs (last 20 lines):${NC}"
                    journalctl -u cloudflared -n 20 --no-pager 2>/dev/null || true
                fi
                echo ""
                read -rp "$(echo -e "${YELLOW}Press Enter to continue...${NC}")"
                ;;

            3)
                clear
                banner
                step "Restarting Cloudflare Tunnel"
                divider
                if ! command -v cloudflared &>/dev/null; then
                    warn "cloudflared is not installed."
                else
                    systemctl restart cloudflared 2>/dev/null || true
                    sleep 2
                    if systemctl is-active --quiet cloudflared; then
                        success "Cloudflare Tunnel restarted and running"
                    else
                        warn "Restart attempted but service is not active."
                        echo -e "  ${DIM}Check: ${BOLD}journalctl -u cloudflared -f${NC}"
                    fi
                fi
                echo ""
                read -rp "$(echo -e "${YELLOW}Press Enter to continue...${NC}")"
                ;;

            4)
                clear
                banner
                step "Uninstalling Cloudflared"
                divider
                ask "Type 'yes' to confirm full removal:"
                read -r CF_CONFIRM
                if [[ "$CF_CONFIRM" != "yes" ]]; then
                    warn "Cancelled."
                else
                    cloudflared service uninstall 2>/dev/null || true
                    if [[ "${PKG_FAMILY:-apt}" == "apt" ]]; then
                        apt-get remove -y cloudflared 2>/dev/null || true
                    else
                        dnf remove -y cloudflared 2>/dev/null || \
                            yum remove -y cloudflared 2>/dev/null || true
                    fi
                    rm -f /etc/apt/sources.list.d/cloudflared.list
                    rm -f /usr/share/keyrings/cloudflare-main.gpg
                    rm -f /etc/yum.repos.d/cloudflared.repo
                    success "cloudflared completely removed"
                fi
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

        # ── Live status badge with IP ─────────────────────────
        TS_STATUS=$(systemctl is-active tailscaled 2>/dev/null || echo "not installed")
        TS_IP=$(tailscale ip -4 2>/dev/null || true)
        if [[ "$TS_STATUS" == "active" ]]; then
            echo -e "  ${GREEN}${BOLD}🔒 Tailscale VPN: RUNNING${NC}"
            [[ -n "$TS_IP" ]] && echo -e "  ${CYAN}Tailscale IP:${NC} ${BOLD}$TS_IP${NC}"
        elif [[ "$TS_STATUS" == "inactive" ]]; then
            echo -e "  ${YELLOW}${BOLD}🔒 Tailscale VPN: STOPPED${NC}"
        else
            echo -e "  ${DIM}🔒 Tailscale VPN: not installed${NC}"
        fi
        echo ""
        echo -e "  ${CYAN}1)${NC} Install Tailscale & Connect"
        echo -e "  ${CYAN}2)${NC} Reconnect / Re-authenticate"
        echo -e "  ${CYAN}3)${NC} Status & Info"
        echo -e "  ${CYAN}4)${NC} Uninstall Tailscale"
        echo -e "  ${CYAN}0)${NC} Back to main menu"
        echo ""
        divider
        ask "Choose [0-4]:"
        read -r TS_CHOICE

        case "$TS_CHOICE" in
            1)
                clear
                banner
                step "Installing Tailscale"
                divider

                if command -v tailscale &>/dev/null; then
                    info "Tailscale is already installed — skipping download"
                else
                    # ── Step 1: Download & install ───────────────
                    echo ""
                    info "Step 1: Downloading and installing Tailscale..."
                    if curl -fsSL https://tailscale.com/install.sh | sh; then
                        success "Tailscale downloaded and installed"
                    else
                        warn "Tailscale install script failed."
                        echo ""
                        read -rp "$(echo -e "${YELLOW}Press Enter to continue...${NC}")"
                        continue
                    fi
                fi

                # ── Step 2: Enable & start daemon ────────────────
                echo ""
                info "Step 2: Starting Tailscale daemon..."
                systemctl enable --now tailscaled 2>/dev/null || true
                sleep 1
                if systemctl is-active --quiet tailscaled; then
                    success "tailscaled service running"
                else
                    warn "tailscaled not running — trying to start..."
                    systemctl start tailscaled 2>/dev/null || true
                fi

                # ── Step 3: Connect to network ────────────────────
                echo ""
                info "Step 3: Connecting to Tailscale network..."
                echo ""
                echo -e "  ${DIM}A browser authentication URL will appear below.${NC}"
                echo -e "  ${DIM}Open it in your browser to approve this machine.${NC}"
                echo ""
                tailscale up
                sleep 2

                # ── Show results ──────────────────────────────────
                TS_NEW_IP=$(tailscale ip -4 2>/dev/null || true)
                echo ""
                divider
                echo -e "${GREEN}${BOLD}  Tailscale Connected!${NC}"
                echo ""
                if [[ -n "$TS_NEW_IP" ]]; then
                    echo -e "  ${CYAN}Your Tailscale IP:${NC}  ${BOLD}$TS_NEW_IP${NC}"
                    echo -e "  ${DIM}Other devices on your Tailnet can reach this server at that IP.${NC}"
                fi
                echo ""
                echo -e "  ${CYAN}Status:${NC}  ${BOLD}tailscale status${NC}"
                echo -e "  ${CYAN}Peers:${NC}   ${BOLD}tailscale status --peers${NC}"
                echo -e "  ${CYAN}Ping:${NC}    ${BOLD}tailscale ping <peer-ip>${NC}"
                echo ""
                divider
                echo ""
                read -rp "$(echo -e "${YELLOW}Press Enter to continue...${NC}")"
                ;;

            2)
                clear
                banner
                step "Reconnect / Re-authenticate Tailscale"
                divider

                if ! command -v tailscale &>/dev/null; then
                    warn "Tailscale is not installed — use option 1 first."
                else
                    echo ""
                    echo -e "  ${DIM}This will log this machine out and open a new auth URL.${NC}"
                    ask "Force re-login (clears existing session)? [y/N]:"
                    read -r TS_RELOGIN

                    if [[ "${TS_RELOGIN,,}" == "y" ]]; then
                        tailscale logout 2>/dev/null || true
                        info "Logged out — reconnecting..."
                    else
                        info "Reconnecting with existing account..."
                    fi

                    systemctl start tailscaled 2>/dev/null || true
                    tailscale up
                    sleep 2

                    TS_RECO_IP=$(tailscale ip -4 2>/dev/null || true)
                    echo ""
                    if [[ -n "$TS_RECO_IP" ]]; then
                        success "Reconnected — Tailscale IP: ${BOLD}$TS_RECO_IP${NC}"
                    else
                        warn "May not have connected yet — check browser auth."
                    fi
                fi
                echo ""
                read -rp "$(echo -e "${YELLOW}Press Enter to continue...${NC}")"
                ;;

            3)
                clear
                banner
                step "Tailscale Status & Info"
                divider

                if ! command -v tailscale &>/dev/null; then
                    warn "Tailscale is not installed."
                else
                    echo ""
                    echo -e "  ${CYAN}Service:${NC}  $(systemctl is-active tailscaled 2>/dev/null || echo 'stopped')"
                    TS_DISP_IP=$(tailscale ip -4 2>/dev/null || echo 'n/a')
                    echo -e "  ${CYAN}IP:${NC}       ${BOLD}$TS_DISP_IP${NC}"
                    echo ""
                    divider
                    echo -e "  ${CYAN}Connected peers:${NC}"
                    tailscale status 2>/dev/null || echo "  (run 'tailscale up' to connect)"
                    echo ""
                    divider
                    echo -e "  ${CYAN}Recent logs:${NC}"
                    journalctl -u tailscaled -n 15 --no-pager 2>/dev/null || true
                fi
                echo ""
                read -rp "$(echo -e "${YELLOW}Press Enter to continue...${NC}")"
                ;;

            4)
                clear
                banner
                step "Uninstalling Tailscale"
                divider
                echo ""
                echo -e "  ${RED}This will completely remove Tailscale and all its configuration.${NC}"
                echo ""
                ask "Type 'yes' to confirm:"
                read -r TS_CONF

                if [[ "$TS_CONF" != "yes" ]]; then
                    warn "Cancelled — Tailscale was NOT removed."
                else
                    info "Step 1: Stopping and disabling service..."
                    systemctl stop tailscaled 2>/dev/null || true
                    systemctl disable tailscaled 2>/dev/null || true
                    success "Service stopped"

                    info "Step 2: Removing package..."
                    if [[ "${PKG_FAMILY:-apt}" == "apt" ]]; then
                        apt-get purge -y tailscale 2>/dev/null || true
                        apt-get autoremove -y 2>/dev/null || true
                    else
                        dnf remove -y tailscale 2>/dev/null || \
                            yum remove -y tailscale 2>/dev/null || true
                    fi
                    success "Package removed"

                    info "Step 3: Cleaning up files..."
                    rm -rf /var/lib/tailscale /etc/tailscale /var/cache/tailscale
                    success "Files cleaned"

                    echo ""
                    success "Tailscale completely removed"
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
# ── 8) Egg Downloader ─────────────────────────────────────────
# XCASPER Eggs repo: github.com/Casper-Tech-ke/xcasper-eggs
EGG_REPO="Casper-Tech-ke/xcasper-eggs"
EGG_RAW="https://raw.githubusercontent.com/${EGG_REPO}/main"
EGG_API="https://api.github.com/repos/${EGG_REPO}/contents"
EGG_DEST="/tmp/xcasper-eggs"

# Fetch egg list for a category from GitHub API
_egg_list_category() {
    local CAT="$1"
    curl -sf "${EGG_API}/${CAT}" \
        | grep '"name".*\.json' | cut -d'"' -f4
}

# Download a single egg
_egg_download() {
    local CAT="$1" FILE="$2"
    mkdir -p "${EGG_DEST}/${CAT}"
    local DEST="${EGG_DEST}/${CAT}/${FILE}"
    if curl -sf "${EGG_RAW}/${CAT}/${FILE}" -o "$DEST"; then
        echo "$DEST"
    fi
}

# Show import instructions
_egg_import_hint() {
    echo ""
    divider
    echo -e "  ${CYAN}${BOLD}How to import this egg into your panel:${NC}"
    echo -e "  1. Log in to your panel as admin"
    echo -e "  2. Go to:  ${BOLD}Admin → Nests → Import Egg${NC}"
    echo -e "  3. Upload the ${BOLD}.json${NC} file downloaded above"
    echo -e "  4. Assign the egg to a Nest and save"
    echo -e "  ${DIM}Eggs are saved to: ${EGG_DEST}/<category>/egg-name.json${NC}"
    divider
}

# Category submenu — list eggs and let user pick
_egg_category_menu() {
    local CAT="$1"
    local CAT_LABEL="$2"
    while true; do
        clear
        banner
        echo -e "  ${CYAN}${BOLD}🥚 Egg Downloader › ${CAT_LABEL}${NC}"
        divider
        echo ""
        info "Fetching egg list from XCASPER repo..."

        # Build indexed list from GitHub
        mapfile -t EGGS < <(_egg_list_category "$CAT")

        if [[ ${#EGGS[@]} -eq 0 ]]; then
            warn "No eggs found in category '${CAT}' — check internet connection."
            echo ""
            read -rp "$(echo -e "${YELLOW}Press Enter to go back...${NC}")"
            return
        fi

        echo ""
        local IDX=1
        for EGG in "${EGGS[@]}"; do
            # Check if already downloaded
            if [[ -f "${EGG_DEST}/${CAT}/${EGG}" ]]; then
                echo -e "  ${CYAN}${IDX})${NC} ${EGG}  ${GREEN}${DIM}[downloaded]${NC}"
            else
                echo -e "  ${CYAN}${IDX})${NC} ${EGG}"
            fi
            ((IDX++))
        done
        echo ""
        echo -e "  ${CYAN}a)${NC} Download ALL eggs in this category"
        echo -e "  ${CYAN}0)${NC} Back"
        echo ""
        divider
        ask "Choose egg [1-${#EGGS[@]}], 'a' for all, or 0 to go back:"
        read -r EGG_PICK

        case "$EGG_PICK" in
            0) return 0 ;;
            a|A)
                clear
                banner
                step "Downloading all ${CAT_LABEL} eggs"
                divider
                local DL_COUNT=0
                for EGG in "${EGGS[@]}"; do
                    info "Downloading ${EGG}..."
                    local SAVED
                    SAVED=$(_egg_download "$CAT" "$EGG")
                    if [[ -n "$SAVED" ]]; then
                        success "${EGG}  →  ${SAVED}"
                        ((DL_COUNT++))
                    else
                        warn "Failed to download ${EGG}"
                    fi
                done
                echo ""
                success "Downloaded ${DL_COUNT}/${#EGGS[@]} eggs"
                _egg_import_hint
                read -rp "$(echo -e "${YELLOW}Press Enter to continue...${NC}")"
                ;;
            *)
                if [[ "$EGG_PICK" =~ ^[0-9]+$ ]] && \
                    (( EGG_PICK >= 1 && EGG_PICK <= ${#EGGS[@]} )); then
                    local SELECTED="${EGGS[$((EGG_PICK - 1))]}"
                    clear
                    banner
                    step "Downloading Egg"
                    divider
                    info "Downloading ${SELECTED}..."
                    local SAVED
                    SAVED=$(_egg_download "$CAT" "$SELECTED")
                    if [[ -n "$SAVED" ]]; then
                        echo ""
                        success "Saved to: ${BOLD}${SAVED}${NC}"
                        _egg_import_hint
                    else
                        warn "Download failed — check internet connection."
                    fi
                    echo ""
                    read -rp "$(echo -e "${YELLOW}Press Enter to continue...${NC}")"
                else
                    warn "Invalid choice."; sleep 1
                fi
                ;;
        esac
    done
}

menu_eggs() {
    while true; do
        clear
        banner

        # ── Live summary ──────────────────────────────────────
        DL_COUNT=$(find "$EGG_DEST" -name "*.json" 2>/dev/null | wc -l)
        echo -e "  ${CYAN}${BOLD}🥚  XCASPER Egg Downloader${NC}"
        echo -e "  ${DIM}Source: github.com/${EGG_REPO}${NC}"
        echo -e "  ${DIM}Eggs downloaded this session: ${DL_COUNT}${NC}"
        echo ""
        echo -e "  ${CYAN}1)${NC} Generic  ${DIM}(Python, Node.js, Golang, Java, Rust)${NC}"
        echo -e "  ${CYAN}2)${NC} Bots     ${DIM}(Discord music bots, moderation)${NC}"
        echo -e "  ${CYAN}3)${NC} Games    ${DIM}(Minecraft Paper)${NC}"
        echo -e "  ${CYAN}4)${NC} Software ${DIM}(Uptime Kuma, Code Server)${NC}"
        echo -e "  ${CYAN}5)${NC} Sync / Update all eggs from upstream"
        echo -e "  ${CYAN}6)${NC} View downloaded eggs"
        echo -e "  ${CYAN}0)${NC} Back to main menu"
        echo ""
        divider
        ask "Choose [0-6]:"
        read -r EGG_MENU

        case "$EGG_MENU" in
            1) _egg_category_menu "generic" "Generic Runtimes" ;;
            2) _egg_category_menu "bots"    "Bots" ;;
            3) _egg_category_menu "games"   "Games" ;;
            4) _egg_category_menu "software" "Software" ;;

            5)
                clear
                banner
                step "Syncing all eggs from XCASPER repo"
                divider
                echo ""
                TOTAL=0; UPDATED=0; FAILED=0
                for CAT in generic bots games software; do
                    info "Syncing category: ${CAT}..."
                    mapfile -t SYNC_EGGS < <(_egg_list_category "$CAT")
                    for EGG in "${SYNC_EGGS[@]}"; do
                        ((TOTAL++))
                        SAVED=$(_egg_download "$CAT" "$EGG")
                        if [[ -n "$SAVED" ]]; then
                            echo -e "  ${GREEN}✓${NC} ${CAT}/${EGG}"
                            ((UPDATED++))
                        else
                            echo -e "  ${RED}✗${NC} ${CAT}/${EGG}"
                            ((FAILED++))
                        fi
                    done
                done
                echo ""
                divider
                success "Sync complete — ${UPDATED}/${TOTAL} eggs updated"
                [[ $FAILED -gt 0 ]] && warn "${FAILED} egg(s) failed to download"
                _egg_import_hint
                read -rp "$(echo -e "${YELLOW}Press Enter to continue...${NC}")"
                ;;

            6)
                clear
                banner
                step "Downloaded Eggs"
                divider
                echo ""
                if [[ $(find "$EGG_DEST" -name "*.json" 2>/dev/null | wc -l) -eq 0 ]]; then
                    warn "No eggs downloaded yet — use options 1–5 above."
                else
                    find "$EGG_DEST" -name "*.json" | sort | while read -r F; do
                        REL="${F#${EGG_DEST}/}"
                        echo -e "  ${GREEN}✓${NC}  ${REL}"
                    done
                    echo ""
                    echo -e "  ${DIM}Location: ${EGG_DEST}/${NC}"
                fi
                echo ""
                _egg_import_hint
                read -rp "$(echo -e "${YELLOW}Press Enter to continue...${NC}")"
                ;;

            0) return 0 ;;
            *) warn "Invalid choice."; sleep 1 ;;
        esac
    done
}

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
    echo -e "  ${CYAN}${BOLD}8)${NC}  Egg Downloader"
    echo -e "  ${CYAN}${BOLD}0)${NC}  Exit"
    echo ""
    divider
}

# ── Entry point ───────────────────────────────────────────────
check_root

while true; do
    show_main_menu
    ask "Select an option [0-8]:"
    read -r MAIN_CHOICE

    case "$MAIN_CHOICE" in
        1) menu_install_panel  ;;
        2) menu_install_wings  ;;
        3) menu_uninstall      ;;
        4) menu_cloudflare     ;;
        5) menu_system_info    ;;
        6) menu_tailscale      ;;
        7) menu_database       ;;
        8) menu_eggs           ;;
        0)
            echo ""
            echo -e "${GREEN}${BOLD}  Goodbye from XCASPER Hosting!${NC}"
            divider
            exit 0
            ;;
        *)
            warn "Invalid option — choose 0–8."
            sleep 1
            ;;
    esac
done
