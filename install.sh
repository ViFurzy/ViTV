#!/bin/bash

# ViTV - Global Installation Script
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; exit 1; }

[ "$EUID" -ne 0 ] && error "This script must be run as root (use sudo)"

clear
echo -e "🎬 ViTV - Media Streaming System\n"

# Check Docker
command -v docker &> /dev/null || error "Docker is not installed.\nInstall: curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh"

# Check Docker Compose
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker-compose"
elif docker compose version &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker compose"
else
    error "Docker Compose is not installed."
fi
success "Docker ready ($DOCKER_COMPOSE_CMD)"

# User Configuration
echo -e "\n[1/8] User Configuration"
read -p "Username (default: vitv): " VITV_USER
VITV_USER=${VITV_USER:-vitv}

if id "$VITV_USER" &>/dev/null; then
    read -p "User exists. Use it? (y/n): " USE_EXISTING
    [[ ! "$USE_EXISTING" =~ ^[TtYy]$ ]] && error "Cancelled."
    VITV_UID=$(id -u "$VITV_USER")
    VITV_GID=$(id -g "$VITV_USER")
else
    useradd -r -m -s /bin/bash "$VITV_USER" 2>/dev/null || error "Failed to create user."
    VITV_UID=$(id -u "$VITV_USER")
    VITV_GID=$(id -g "$VITV_USER")
    success "User created"
fi

if ! getent group docker > /dev/null 2>&1; then groupadd docker; fi
usermod -aG docker "$VITV_USER"
success "Added to docker group (log out/in or: newgrp docker)"

# Installation Path
echo -e "\n[2/8] Installation Path"
read -p "Path (default: /opt/vitv): " INSTALL_PATH
INSTALL_PATH=${INSTALL_PATH:-/opt/vitv}
INSTALL_PATH=$(readlink -f "$INSTALL_PATH" 2>/dev/null || echo "$INSTALL_PATH")

if [ -d "$INSTALL_PATH" ]; then
    read -p "Directory exists. Continue? (y/n): " CONTINUE
    [[ ! "$CONTINUE" =~ ^[TtYy]$ ]] && error "Cancelled."
else
    mkdir -p "$INSTALL_PATH"
fi
chown "$VITV_USER:$VITV_USER" "$INSTALL_PATH"
success "Path: $INSTALL_PATH"

# System Configuration
echo -e "\n[3/8] System Configuration"
read -p "Timezone (default: Europe/Warsaw): " TIMEZONE
TIMEZONE=${TIMEZONE:-Europe/Warsaw}
read -p "Transmission username (default: admin): " TRANS_USER
TRANS_USER=${TRANS_USER:-admin}
read -sp "Transmission password (default: admin): " TRANS_PASS
TRANS_PASS=${TRANS_PASS:-admin}
echo ""

# Directory Structure
echo -e "\n[4/8] Creating Directories"
mkdir -p "$INSTALL_PATH"/{config/{jellyfin,prowlarr,sonarr,jellyseerr,transmission},media/{tv,movies},downloads/watch,cache/jellyfin}
chown -R "$VITV_USER:$VITV_USER" "$INSTALL_PATH"
chmod -R 755 "$INSTALL_PATH"
chmod 775 "$INSTALL_PATH/downloads" "$INSTALL_PATH/downloads/watch"
chmod 700 "$INSTALL_PATH/config"/*
success "Directories created"

# Copy Files
echo -e "\n[5/8] Copying Files"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/docker-compose.yml" ]; then
    cp "$SCRIPT_DIR/docker-compose.yml" "$INSTALL_PATH/"
    cp "$SCRIPT_DIR/env.example" "$INSTALL_PATH/" 2>/dev/null || true
    cp "$SCRIPT_DIR/.dockerignore" "$INSTALL_PATH/" 2>/dev/null || true
    cp "$SCRIPT_DIR/.gitignore" "$INSTALL_PATH/" 2>/dev/null || true
    cp "$SCRIPT_DIR/README.md" "$INSTALL_PATH/" 2>/dev/null || true
    success "Files copied"
else
    warning "Files not found in $SCRIPT_DIR"
fi
chown -R "$VITV_USER:$VITV_USER" "$INSTALL_PATH"

# Configure Docker Compose
echo -e "\n[6/8] Configuring Docker Compose"
if [ -f "$INSTALL_PATH/docker-compose.yml" ]; then
    cp "$INSTALL_PATH/docker-compose.yml" "$INSTALL_PATH/docker-compose.yml.bak"
    sed -i "s|\./config|$INSTALL_PATH/config|g; s|\./media|$INSTALL_PATH/media|g; s|\./downloads|$INSTALL_PATH/downloads|g; s|\./cache|$INSTALL_PATH/cache|g" "$INSTALL_PATH/docker-compose.yml"
    success "docker-compose.yml configured"
fi

cat > "$INSTALL_PATH/.env" << EOF
PUID=$VITV_UID
PGID=$VITV_GID
TZ=$TIMEZONE
TRANSMISSION_USER=$TRANS_USER
TRANSMISSION_PASS=$TRANS_PASS
JELLYFIN_PublishedServerUrl=http://localhost:8096
EOF
chown "$VITV_USER:$VITV_USER" "$INSTALL_PATH/.env"
chmod 600 "$INSTALL_PATH/.env"
success ".env created"

# Management Script
echo -e "\n[7/8] Creating Management Script"
cat > "$INSTALL_PATH/vitv.sh" << 'SCRIPT_EOF'
#!/bin/bash
# ViTV - Management Script
set -e

SCRIPT_PATH="${BASH_SOURCE[0]}"
[ -L "$SCRIPT_PATH" ] && SCRIPT_PATH=$(readlink -f "$SCRIPT_PATH")
INSTALL_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

[ ! -f "$INSTALL_DIR/docker-compose.yml" ] && for path in "/opt/vitv" "/home/$USER/vitv" "$HOME/vitv"; do
    [ -f "$path/docker-compose.yml" ] && INSTALL_DIR="$path" && break
done

[ ! -f "$INSTALL_DIR/docker-compose.yml" ] && echo "Error: docker-compose.yml not found" && exit 1

cd "$INSTALL_DIR"

detect_docker_compose() {
    command -v docker-compose &> /dev/null && echo "docker-compose" || \
    (docker compose version &> /dev/null 2>&1 && echo "docker compose" || echo "docker-compose")
}

DOCKER_COMPOSE_CMD=$(detect_docker_compose)

case "$1" in
    start) echo "Starting ViTV services..."; $DOCKER_COMPOSE_CMD up -d; echo "Services started!" ;;
    stop) echo "Stopping ViTV services..."; $DOCKER_COMPOSE_CMD down; echo "Services stopped!" ;;
    restart) echo "Restarting ViTV services..."; $DOCKER_COMPOSE_CMD restart; echo "Services restarted!" ;;
    status) echo "ViTV services status:"; $DOCKER_COMPOSE_CMD ps ;;
    logs) $DOCKER_COMPOSE_CMD logs -f "${2:-}" ;;
    update) echo "Updating Docker images..."; $DOCKER_COMPOSE_CMD pull; $DOCKER_COMPOSE_CMD up -d; echo "Update completed!" ;;
    rebuild) echo "Rebuilding ViTV services..."; $DOCKER_COMPOSE_CMD down 2>/dev/null || true; $DOCKER_COMPOSE_CMD up -d --build; echo "Services rebuilt and started!" ;;
    *) echo "ViTV - Management Script\nUsage: $0 [start|stop|restart|status|logs|update|rebuild]"; exit 1 ;;
esac
SCRIPT_EOF

chmod +x "$INSTALL_PATH/vitv.sh"
chown "$VITV_USER:$VITV_USER" "$INSTALL_PATH/vitv.sh"
success "Management script created"

read -p "Create system command 'vitv'? (y/n): " CREATE_LINK
[[ "$CREATE_LINK" =~ ^[TtYy]$ ]] && ln -sf "$INSTALL_PATH/vitv.sh" /usr/local/bin/vitv && success "Command 'vitv' created"

# Configuration Guide Function
show_configuration_guide() {
    clear
    echo -e "🎬 ViTV Configuration Guide\n"
    echo "Order: Transmission → Prowlarr → Sonarr → Jellyfin → Jellyseerr"
    read -p "Press Enter to start..." 
    
    echo -e "\n[1/5] TRANSMISSION - http://localhost:9091"
    echo "  Login: $TRANS_USER / $TRANS_PASS"
    echo "  Menu (☰) → Edit Preferences → Torrents → Download to: $INSTALL_PATH/downloads"
    echo "  Remote Access → Change password!"
    read -p "Press Enter to continue..."
    
    echo -e "\n[2/5] PROWLARR - http://localhost:9696"
    echo "  Settings → Indexers → + Add (RARBG, 1337x, TorrentGalaxy)"
    echo "  Settings → Apps → + Add → Sonarr"
    echo "    Name: Sonarr | Prowlarr: http://prowlarr:9696 | Sonarr: http://sonarr:8989"
    echo "    API Key: (get from Sonarr) | ✓ Sync App Indexers"
    echo "  ⚠️  Use container names, NOT localhost!"
    read -p "Press Enter to continue..."
    
    echo -e "\n[3/5] SONARR - http://localhost:8989"
    echo "  Settings → Media Management → + Add Root Folder → /tv"
    echo "  Settings → Download Clients → + Add → Transmission"
    echo "    Host: transmission | Port: 9091 | User: $TRANS_USER | Pass: $TRANS_PASS | Category: tv"
    echo "    ⚠️  IMPORTANT: Test connection, then Save"
    echo "  Remote Path Mappings (CRITICAL!) → + Add"
    echo "    Host: transmission (must match Download Client Host exactly)"
    echo "    Remote Path: /downloads/tv (where Transmission saves with category 'tv')"
    echo "    Local Path: /downloads (where Sonarr should look for files)"
    echo "    Save → Warning should disappear"
    echo "  Settings → Indexers → + Add → Prowlarr → URL: http://prowlarr:9696 + API Key"
    read -p "Press Enter to continue..."
    
    echo -e "\n[4/5] JELLYFIN - http://localhost:8096"
    echo "  First-time setup → Create admin account"
    echo "  Dashboard → Libraries → + Add → Movies: /media/movies | TV: /media/tv"
    echo "  Dashboard → API Keys → Create key (for Jellyseerr)"
    read -p "Press Enter to continue..."
    
    echo -e "\n[5/5] JELLYSEERR - http://localhost:5055"
    echo "  First-time setup → Create admin account"
    echo "  Settings → Services → + Add → Jellyfin: http://jellyfin:8096 + API Key"
    echo "  Settings → Services → + Add → Sonarr: http://sonarr:8989 + API Key"
    echo "  Settings → Users → + Create User"
    read -p "Press Enter to finish..."
    
    echo -e "\n✅ Configuration Guide Complete!"
    echo "Reminders: Change Transmission password | Add indexers | Connect with API Keys | Add first series/movie"
}

# Start Services
SHOW_GUIDE_SHOWN=false
echo -e "\n[8/8] Starting Services"
read -p "Start Docker containers now? (y/n): " START_NOW
if [[ "$START_NOW" =~ ^[TtYy]$ ]]; then
    if sudo -u "$VITV_USER" bash -c "cd $INSTALL_PATH && $DOCKER_COMPOSE_CMD version &>/dev/null"; then
        sudo -u "$VITV_USER" bash -c "cd $INSTALL_PATH && $DOCKER_COMPOSE_CMD up -d" 2>&1
        DOCKER_EXIT_CODE=$?
    elif sudo -u "$VITV_USER" bash -c "cd $INSTALL_PATH && docker compose version &>/dev/null"; then
        sudo -u "$VITV_USER" bash -c "cd $INSTALL_PATH && docker compose up -d" 2>&1
        DOCKER_EXIT_CODE=$?
        DOCKER_COMPOSE_CMD="docker compose"
    else
        error "Cannot find Docker Compose for user $VITV_USER"
    fi
    
    if [ $DOCKER_EXIT_CODE -eq 0 ]; then
        success "Containers started"
        echo "Waiting 10 seconds..."
        sleep 10
        sudo -u "$VITV_USER" bash -c "cd $INSTALL_PATH && $DOCKER_COMPOSE_CMD ps"
        read -p "Show configuration guide? (y/n): " SHOW_GUIDE
        [[ "$SHOW_GUIDE" =~ ^[TtYy]$ ]] && show_configuration_guide && SHOW_GUIDE_SHOWN=true
    else
        error "Failed to start containers.\nSwitch user: sudo su - $VITV_USER\nThen: cd $INSTALL_PATH && $DOCKER_COMPOSE_CMD up -d"
    fi
fi

# Final Summary
echo -e "\n✅ Installation Complete!\n"
echo "Summary:"
echo "  User: $VITV_USER (UID: $VITV_UID, GID: $VITV_GID)"
echo "  Path: $INSTALL_PATH"
echo "  Timezone: $TIMEZONE\n"

[[ ! "$START_NOW" =~ ^[TtYy]$ ]] && echo "Next steps:" && \
echo "  1. sudo su - $VITV_USER" && \
echo "  2. cd $INSTALL_PATH" && \
echo "  3. $([ -f /usr/local/bin/vitv ] && echo 'vitv start' || echo './vitv.sh start')\n"

echo "Application URLs:"
echo "  Jellyfin:     http://localhost:8096"
echo "  Prowlarr:     http://localhost:9696"
echo "  Sonarr:       http://localhost:8989"
echo "  Jellyseerr:   http://localhost:5055"
echo "  Transmission: http://localhost:9091\n"

[ "$SHOW_GUIDE_SHOWN" = false ] && echo "Configuration guide: See README.md in installation directory\n"

warning "⚠️  Change Transmission password after first startup!\n"
