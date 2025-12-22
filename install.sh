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
DOCKER_COMPOSE_CMD=""
info "Detecting Docker Compose..."

# Method 1: Check via command -v
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE_PATH=$(command -v docker-compose)
    info "Found docker-compose at: $DOCKER_COMPOSE_PATH"
    # Try to verify docker-compose works
    if docker-compose version &> /dev/null 2>&1; then
        DOCKER_COMPOSE_CMD="docker-compose"
    else
        # Try with full path
        if "$DOCKER_COMPOSE_PATH" version &> /dev/null 2>&1; then
            DOCKER_COMPOSE_CMD="docker-compose"
        fi
    fi
fi

# Method 2: Check common installation paths
if [ -z "$DOCKER_COMPOSE_CMD" ]; then
    for path in /usr/bin/docker-compose /usr/local/bin/docker-compose /snap/bin/docker-compose; do
        if [ -f "$path" ] && [ -x "$path" ]; then
            info "Found docker-compose at: $path"
            if "$path" version &> /dev/null 2>&1; then
                DOCKER_COMPOSE_CMD="docker-compose"
                break
            fi
        fi
    done
fi

# Method 3: Try docker compose (plugin v2)
if [ -z "$DOCKER_COMPOSE_CMD" ]; then
    if docker compose version &> /dev/null 2>&1; then
        DOCKER_COMPOSE_CMD="docker compose"
        info "Found docker compose (plugin v2)"
    fi
fi

# Method 4: Try via which command
if [ -z "$DOCKER_COMPOSE_CMD" ]; then
    DOCKER_COMPOSE_PATH=$(which docker-compose 2>/dev/null)
    if [ -n "$DOCKER_COMPOSE_PATH" ] && [ -x "$DOCKER_COMPOSE_PATH" ]; then
        info "Found docker-compose via which: $DOCKER_COMPOSE_PATH"
        if "$DOCKER_COMPOSE_PATH" version &> /dev/null 2>&1; then
            DOCKER_COMPOSE_CMD="docker-compose"
        fi
    fi
fi

# Method 5: Last attempt - direct execution (only if all previous methods failed)
if [ -z "$DOCKER_COMPOSE_CMD" ]; then
    info "Attempting manual verification..."
    # Last attempt: try to run docker-compose directly and capture output
    if docker-compose --version 2>&1 | grep -q "docker-compose\|compose version"; then
        DOCKER_COMPOSE_CMD="docker-compose"
        info "Docker Compose verified via direct execution"
    elif docker compose version 2>&1 | grep -q "Docker Compose\|compose version"; then
        DOCKER_COMPOSE_CMD="docker compose"
        info "Docker Compose (plugin) verified via direct execution"
    fi
fi

if [ -z "$DOCKER_COMPOSE_CMD" ]; then
    error "Docker Compose is not installed or not accessible.\n\nTroubleshooting:\n  1. Verify installation: docker-compose --version\n  2. Check PATH: echo \$PATH\n  3. Try full path: /usr/bin/docker-compose --version\n\nInstall Docker Compose:\n  Standalone: https://docs.docker.com/compose/install/standalone/\n  Plugin: https://docs.docker.com/compose/install/linux/\n\nOr via package manager:\n  Ubuntu/Debian: sudo apt-get install docker-compose-plugin\n  Or: sudo apt-get install docker-compose"
fi

success "Docker ready ($DOCKER_COMPOSE_CMD)"

# Clean Install Option
CLEAN_INSTALL=false
echo -e "\n[0/8] Installation Mode"
read -p "Perform clean install? (removes existing configs/containers) (y/n): " CLEAN_CHOICE
if [[ "$CLEAN_CHOICE" =~ ^[TtYy]$ ]]; then
    CLEAN_INSTALL=true
    warning "Clean install selected - existing configurations will be removed!"
    read -p "Enter installation path to clean (default: /opt/vitv): " CLEAN_PATH
    CLEAN_PATH=${CLEAN_PATH:-/opt/vitv}
    CLEAN_PATH=$(readlink -f "$CLEAN_PATH" 2>/dev/null || echo "$CLEAN_PATH")
    
    if [ -d "$CLEAN_PATH" ] && [ -f "$CLEAN_PATH/docker-compose.yml" ]; then
        info "Stopping and removing containers..."
        cd "$CLEAN_PATH" 2>/dev/null || true
        $DOCKER_COMPOSE_CMD down -v 2>/dev/null || true
        docker rm -f jellyfin prowlarr sonarr jellyseerr transmission 2>/dev/null || true
        success "Containers removed"
        
        info "Removing configuration directories and files..."
        rm -rf "$CLEAN_PATH/config" 2>/dev/null || true
        rm -f "$CLEAN_PATH/docker-compose.yml" "$CLEAN_PATH/docker-compose.yml.bak" "$CLEAN_PATH/.env" "$CLEAN_PATH/env.example" "$CLEAN_PATH/.dockerignore" "$CLEAN_PATH/.gitignore" "$CLEAN_PATH/README.md" 2>/dev/null || true
        success "Configurations removed"
        
        read -p "Remove media and downloads? (y/n): " REMOVE_MEDIA
        if [[ "$REMOVE_MEDIA" =~ ^[TtYy]$ ]]; then
            warning "Removing media and downloads directories..."
            rm -rf "$CLEAN_PATH/media" "$CLEAN_PATH/downloads" "$CLEAN_PATH/cache" 2>/dev/null || true
            success "Media and downloads removed"
        else
            info "Keeping media and downloads directories"
        fi
        
        echo ""
    else
        info "No existing installation found at $CLEAN_PATH"
    fi
fi

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
if [ "$CLEAN_INSTALL" = true ] && [ -n "$CLEAN_PATH" ]; then
    INSTALL_PATH="$CLEAN_PATH"
    info "Using cleaned path: $INSTALL_PATH"
else
    read -p "Path (default: /opt/vitv): " INSTALL_PATH
    INSTALL_PATH=${INSTALL_PATH:-/opt/vitv}
    INSTALL_PATH=$(readlink -f "$INSTALL_PATH" 2>/dev/null || echo "$INSTALL_PATH")
fi

# Ensure installation directory exists
if [ ! -d "$INSTALL_PATH" ]; then
    info "Creating installation directory: $INSTALL_PATH"
    mkdir -p "$INSTALL_PATH"
elif [ "$CLEAN_INSTALL" = false ]; then
    read -p "Directory exists. Continue? (y/n): " CONTINUE
    [[ ! "$CONTINUE" =~ ^[TtYy]$ ]] && error "Cancelled."
fi

# Set ownership (directory must exist at this point)
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
# Only create directories that don't exist (preserve media/downloads if not cleaned)
[ ! -d "$INSTALL_PATH/config" ] && mkdir -p "$INSTALL_PATH/config"
[ ! -d "$INSTALL_PATH/media" ] && mkdir -p "$INSTALL_PATH/media"
[ ! -d "$INSTALL_PATH/downloads" ] && mkdir -p "$INSTALL_PATH/downloads"
[ ! -d "$INSTALL_PATH/cache" ] && mkdir -p "$INSTALL_PATH/cache"
mkdir -p "$INSTALL_PATH/config"/{jellyfin,prowlarr,sonarr,jellyseerr,transmission}
mkdir -p "$INSTALL_PATH/media"/{tv,movies}
mkdir -p "$INSTALL_PATH/downloads"/watch
mkdir -p "$INSTALL_PATH/cache"/jellyfin
chown -R "$VITV_USER:$VITV_USER" "$INSTALL_PATH"
chmod -R 755 "$INSTALL_PATH"
chmod 775 "$INSTALL_PATH/downloads" "$INSTALL_PATH/downloads/watch" 2>/dev/null || true
# Config directories need write access for applications (especially Jellyfin plugins)
# Jellyfin requires recursive write access for plugin injection into index.html
chmod -R 775 "$INSTALL_PATH/config"/*
# Ensure Jellyfin config has proper permissions recursively (fixes plugin injection errors)
[ -d "$INSTALL_PATH/config/jellyfin" ] && chown -R "$VITV_USER:$VITV_USER" "$INSTALL_PATH/config/jellyfin" && chmod -R 775 "$INSTALL_PATH/config/jellyfin"
success "Directories created"

# Copy Files
echo -e "\n[5/8] Copying Files"
info "Copying files..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if we're running from the installation directory
if [ "$SCRIPT_DIR" = "$INSTALL_PATH" ]; then
    info "Script running from installation directory - files should already be present"
    if [ ! -f "$INSTALL_PATH/docker-compose.yml" ]; then
        error "docker-compose.yml not found! Please run install.sh from the repository directory."
    fi
else
    # Copy files from repository to installation directory
    if [ -f "$SCRIPT_DIR/docker-compose.yml" ]; then
        # Only copy if source and destination are different
        if [ "$SCRIPT_DIR/docker-compose.yml" != "$INSTALL_PATH/docker-compose.yml" ]; then
            cp "$SCRIPT_DIR/docker-compose.yml" "$INSTALL_PATH/"
        fi
        [ -f "$SCRIPT_DIR/env.example" ] && [ "$SCRIPT_DIR/env.example" != "$INSTALL_PATH/env.example" ] && cp "$SCRIPT_DIR/env.example" "$INSTALL_PATH/" 2>/dev/null || true
        [ -f "$SCRIPT_DIR/.dockerignore" ] && [ "$SCRIPT_DIR/.dockerignore" != "$INSTALL_PATH/.dockerignore" ] && cp "$SCRIPT_DIR/.dockerignore" "$INSTALL_PATH/" 2>/dev/null || true
        [ -f "$SCRIPT_DIR/.gitignore" ] && [ "$SCRIPT_DIR/.gitignore" != "$INSTALL_PATH/.gitignore" ] && cp "$SCRIPT_DIR/.gitignore" "$INSTALL_PATH/" 2>/dev/null || true
        [ -f "$SCRIPT_DIR/README.md" ] && [ "$SCRIPT_DIR/README.md" != "$INSTALL_PATH/README.md" ] && cp "$SCRIPT_DIR/README.md" "$INSTALL_PATH/" 2>/dev/null || true
        success "Files copied"
    else
        warning "Files not found in $SCRIPT_DIR"
        if [ ! -f "$INSTALL_PATH/docker-compose.yml" ]; then
            error "docker-compose.yml not found! Please ensure you're running install.sh from the repository directory."
        fi
    fi
fi

# Verify docker-compose.yml exists
if [ ! -f "$INSTALL_PATH/docker-compose.yml" ]; then
    error "docker-compose.yml is missing! Cannot continue."
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
[ -L "$SCRIPT_PATH" ] && SCRIPT_PATH=$(readlink -f "$SCRIPT_PATH" 2>/dev/null || echo "$SCRIPT_PATH")
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
    *) echo "ViTV - Management Script"; echo "Usage: $0 [start|stop|restart|status|logs|update|rebuild]"; exit 1 ;;
esac
SCRIPT_EOF

chmod +x "$INSTALL_PATH/vitv.sh"
chown "$VITV_USER:$VITV_USER" "$INSTALL_PATH/vitv.sh"
# Ensure script has Unix line endings (LF, not CRLF) to prevent editor opening
sed -i 's/\r$//' "$INSTALL_PATH/vitv.sh" 2>/dev/null || true
success "Management script created"

read -p "Create system command 'vitv'? (y/n): " CREATE_LINK
if [[ "$CREATE_LINK" =~ ^[TtYy]$ ]]; then
    ln -sf "$INSTALL_PATH/vitv.sh" /usr/local/bin/vitv
    chmod +x /usr/local/bin/vitv 2>/dev/null || true
    success "System command 'vitv' created"
fi

# Configuration Guide Function
show_configuration_guide() {
    clear
    echo -e "🎬 ViTV Configuration Guide\n"
    echo "Order: Transmission → Prowlarr → Sonarr → Jellyfin → Jellyseerr"
    read -p "Press Enter to start..." 
    
    echo -e "\n[1/5] TRANSMISSION - http://localhost:9091"
    echo "  Login: $TRANS_USER / $TRANS_PASS"
    echo "  Menu (☰) → Edit Preferences → Torrents"
    echo "    Download to: /downloads (container path, NOT $INSTALL_PATH/downloads)"
    echo "    ⚠️  CRITICAL: Use /downloads, NOT host path!"
    echo "  Remote Access → Change password!"
    read -p "Press Enter to continue..."
    
    echo -e "\n[2/5] PROWLARR - http://localhost:9696"
    echo "  Indexers → + Add (RARBG, 1337x, TorrentGalaxy)"
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
    # Detect Docker Compose for the user
    USER_DOCKER_COMPOSE_CMD=""
    if sudo -u "$VITV_USER" bash -c "command -v docker-compose &>/dev/null && docker-compose version &>/dev/null 2>&1"; then
        USER_DOCKER_COMPOSE_CMD="docker-compose"
    elif sudo -u "$VITV_USER" bash -c "docker compose version &>/dev/null 2>&1"; then
        USER_DOCKER_COMPOSE_CMD="docker compose"
    else
        # Fallback: use the root-detected command
        USER_DOCKER_COMPOSE_CMD="$DOCKER_COMPOSE_CMD"
    fi
    
    if [ -z "$USER_DOCKER_COMPOSE_CMD" ]; then
        error "Cannot find Docker Compose for user $VITV_USER.\n\nMake sure Docker Compose is installed and accessible.\nUser may need to log out/in after being added to docker group."
    fi
    
    info "Starting containers using: $USER_DOCKER_COMPOSE_CMD"
    sudo -u "$VITV_USER" bash -c "cd $INSTALL_PATH && $USER_DOCKER_COMPOSE_CMD up -d" 2>&1
    DOCKER_EXIT_CODE=$?
    
    if [ $DOCKER_EXIT_CODE -eq 0 ]; then
        success "Containers started"
        echo "Waiting 10 seconds..."
        sleep 10
        sudo -u "$VITV_USER" bash -c "cd $INSTALL_PATH && $USER_DOCKER_COMPOSE_CMD ps"
        read -p "Show configuration guide? (y/n): " SHOW_GUIDE
        [[ "$SHOW_GUIDE" =~ ^[TtYy]$ ]] && show_configuration_guide && SHOW_GUIDE_SHOWN=true
    else
        error "Failed to start containers.\n\nPossible causes:\n  1. User $VITV_USER does not have Docker permissions\n  2. Docker Compose is not available in user's PATH\n  3. User needs to log out/in after being added to docker group\n\nSolution:\n  1. Switch to user: sudo su - $VITV_USER\n  2. Go to directory: cd $INSTALL_PATH\n  3. Run manually: $USER_DOCKER_COMPOSE_CMD up -d\n\nOr run: newgrp docker (to activate docker group without logout)"
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
