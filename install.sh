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
echo -e "\n╔════════════════════════════════════════════════════════════╗"
echo -e "║          🎬 ViTV - Media Streaming System 🎬              ║"
echo -e "╚════════════════════════════════════════════════════════════╝\n"

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
success "Docker and Docker Compose installed (using: $DOCKER_COMPOSE_CMD)\n"

# User Configuration
echo "┌─────────────────────────────────────────────────────────┐"
echo "│ Step 1: User Configuration                                │"
echo "└─────────────────────────────────────────────────────────┘\n"
read -p "Enter username for ViTV (default: vitv): " VITV_USER
VITV_USER=${VITV_USER:-vitv}

if id "$VITV_USER" &>/dev/null; then
    warning "User '$VITV_USER' already exists."
    read -p "Use existing user? (y/n): " USE_EXISTING
    [[ ! "$USE_EXISTING" =~ ^[TtYy]$ ]] && error "Installation cancelled."
    VITV_UID=$(id -u "$VITV_USER")
    VITV_GID=$(id -g "$VITV_USER")
else
    info "Creating user '$VITV_USER'..."
    useradd -r -m -s /bin/bash "$VITV_USER" 2>/dev/null || error "Failed to create user."
    VITV_UID=$(id -u "$VITV_USER")
    VITV_GID=$(id -g "$VITV_USER")
    success "User '$VITV_USER' created (UID: $VITV_UID, GID: $VITV_GID)"
fi

# Add to docker group
info "Adding user to docker group..."
if ! getent group docker > /dev/null 2>&1; then
    groupadd docker
fi
usermod -aG docker "$VITV_USER"
success "User added to docker group"
warning "NOTE: User $VITV_USER must log out/in or run: newgrp docker\n"

# Installation Path
echo "┌─────────────────────────────────────────────────────────┐"
echo "│ Step 2: Installation Path                               │"
echo "└─────────────────────────────────────────────────────────┘\n"
read -p "Enter installation path (default: /opt/vitv): " INSTALL_PATH
INSTALL_PATH=${INSTALL_PATH:-/opt/vitv}
INSTALL_PATH=$(readlink -f "$INSTALL_PATH" 2>/dev/null || echo "$INSTALL_PATH")
info "Installation path: $INSTALL_PATH"

if [ -d "$INSTALL_PATH" ]; then
    warning "Directory '$INSTALL_PATH' already exists."
    read -p "Continue? Existing files may be overwritten. (y/n): " CONTINUE
    [[ ! "$CONTINUE" =~ ^[TtYy]$ ]] && error "Installation cancelled."
else
    mkdir -p "$INSTALL_PATH"
    success "Main directory created"
fi
chown "$VITV_USER:$VITV_USER" "$INSTALL_PATH"
success "Directory owner set to $VITV_USER\n"

# System Configuration
echo "┌─────────────────────────────────────────────────────────┐"
echo "│ Step 3: System Configuration                            │"
echo "└─────────────────────────────────────────────────────────┘\n"
read -p "Enter timezone (default: Europe/Warsaw): " TIMEZONE
TIMEZONE=${TIMEZONE:-Europe/Warsaw}
read -p "Enter Transmission username (default: admin): " TRANS_USER
TRANS_USER=${TRANS_USER:-admin}
read -sp "Enter Transmission password (default: admin): " TRANS_PASS
TRANS_PASS=${TRANS_PASS:-admin}
echo -e "\n"

# Directory Structure
echo "┌─────────────────────────────────────────────────────────┐"
echo "│ Step 4: Creating Directory Structure                    │"
echo "└─────────────────────────────────────────────────────────┘\n"
info "Creating directories..."
mkdir -p "$INSTALL_PATH"/{config/{jellyfin,prowlarr,sonarr,jellyseerr,transmission},media/{tv,movies},downloads/watch,cache/jellyfin}
chown -R "$VITV_USER:$VITV_USER" "$INSTALL_PATH"
chmod -R 755 "$INSTALL_PATH"
chmod 775 "$INSTALL_PATH/downloads" "$INSTALL_PATH/downloads/watch"
chmod 700 "$INSTALL_PATH/config"/*
success "Directory structure and permissions configured ✓\n"

# Copy Files
echo "┌─────────────────────────────────────────────────────────┐"
echo "│ Step 5: Copying Project Files                           │"
echo "└─────────────────────────────────────────────────────────┘\n"
info "Copying files..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/docker-compose.yml" ]; then
    cp "$SCRIPT_DIR/docker-compose.yml" "$INSTALL_PATH/"
    cp "$SCRIPT_DIR/env.example" "$INSTALL_PATH/" 2>/dev/null || true
    cp "$SCRIPT_DIR/.dockerignore" "$INSTALL_PATH/" 2>/dev/null || true
    cp "$SCRIPT_DIR/.gitignore" "$INSTALL_PATH/" 2>/dev/null || true
    cp "$SCRIPT_DIR/README.md" "$INSTALL_PATH/" 2>/dev/null || true
    success "Project files copied ✓"
else
    warning "Project files not found in $SCRIPT_DIR"
fi
chown -R "$VITV_USER:$VITV_USER" "$INSTALL_PATH"

# Configure Docker Compose
echo -e "\n┌─────────────────────────────────────────────────────────┐"
echo "│ Step 6: Configuring Docker Compose                       │"
echo "└─────────────────────────────────────────────────────────┘\n"
info "Updating paths in docker-compose.yml..."
if [ -f "$INSTALL_PATH/docker-compose.yml" ]; then
    cp "$INSTALL_PATH/docker-compose.yml" "$INSTALL_PATH/docker-compose.yml.bak"
    sed -i "s|\./config|$INSTALL_PATH/config|g; s|\./media|$INSTALL_PATH/media|g; s|\./downloads|$INSTALL_PATH/downloads|g; s|\./cache|$INSTALL_PATH/cache|g" "$INSTALL_PATH/docker-compose.yml"
    success "docker-compose.yml configured ✓"
fi

# Create .env
info "Creating .env file..."
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
success ".env file created ✓\n"

# Management Script
echo "┌─────────────────────────────────────────────────────────┐"
echo "│ Step 7: Creating Management Script                      │"
echo "└─────────────────────────────────────────────────────────┘\n"
info "Generating vitv.sh management script..."
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
success "Management script created ✓\n"

read -p "Create system-wide command 'vitv'? (y/n): " CREATE_LINK
[[ "$CREATE_LINK" =~ ^[TtYy]$ ]] && ln -sf "$INSTALL_PATH/vitv.sh" /usr/local/bin/vitv && success "System command 'vitv' created ✓"

# Configuration Guide Function
show_configuration_guide() {
    clear
    echo -e "\n╔════════════════════════════════════════════════════════════╗"
    echo -e "║     🎬 ViTV Configuration Guide - Quick Setup 🎬          ║"
    echo -e "╚════════════════════════════════════════════════════════════╝\n"
    info "Configure in order: Transmission → Prowlarr → Sonarr → Jellyfin → Jellyseerr\n"
    read -p "Press Enter to start..." 
    
    echo -e "\n┌─────────────────────────────────────────────────────────┐"
    echo -e "│ 1️⃣  TRANSMISSION  │  http://localhost:9091              │"
    echo -e "└─────────────────────────────────────────────────────────┘\n"
    echo -e "  🔐 Login: $TRANS_USER / $TRANS_PASS"
    echo -e "  📁 Menu (☰) → Edit Preferences → Torrents"
    echo -e "     Set 'Download to:' → $INSTALL_PATH/downloads"
    echo -e "  🔒 Remote Access → Change password!\n"
    read -p "  ✓ Press Enter to continue..."
    
    echo -e "\n┌─────────────────────────────────────────────────────────┐"
    echo -e "│ 2️⃣  PROWLARR      │  http://localhost:9696              │"
    echo -e "└─────────────────────────────────────────────────────────┘\n"
    echo -e "  📚 Settings → Indexers → + Add Indexer (RARBG, 1337x, TorrentGalaxy)"
    echo -e "  🔗 Settings → Apps → + Add Application → Sonarr"
    echo -e "     • Name: Sonarr"
    echo -e "     • Prowlarr Server: http://prowlarr:9696"
    echo -e "     • Sonarr Server: http://sonarr:8989"
    echo -e "     • API Key: (get from Sonarr later) • ✓ Sync App Indexers"
    echo -e "  ⚠️  Use container names (prowlarr/sonarr), NOT localhost!\n"
    read -p "  ✓ Press Enter to continue..."
    
    echo -e "\n┌─────────────────────────────────────────────────────────┐"
    echo -e "│ 3️⃣  SONARR        │  http://localhost:8989              │"
    echo -e "└─────────────────────────────────────────────────────────┘\n"
    echo -e "  📂 Settings → Media Management → + Add Root Folder → /tv"
    echo -e "  ⬇️  Settings → Download Clients → + Add → Transmission"
    echo -e "     • Host: transmission • Port: 9091 • Username: $TRANS_USER • Password: $TRANS_PASS • Category: tv"
    echo -e "  🗺️  Remote Path Mappings → + Add → Host: transmission • Remote: /downloads/tv • Local: /downloads"
    echo -e "  🔍 Settings → Indexers → + Add → Prowlarr → URL: http://prowlarr:9696 + API Key\n"
    read -p "  ✓ Press Enter to continue..."
    
    echo -e "\n┌─────────────────────────────────────────────────────────┐"
    echo -e "│ 4️⃣  JELLYFIN      │  http://localhost:8096              │"
    echo -e "└─────────────────────────────────────────────────────────┘\n"
    echo -e "  🎬 First-time setup → Create admin account"
    echo -e "  📚 Dashboard → Libraries → + Add Media Library"
    echo -e "     Movies: /media/movies • TV Shows: /media/tv"
    echo -e "  🔑 Dashboard → API Keys → Create key (for Jellyseerr)\n"
    read -p "  ✓ Press Enter to continue..."
    
    echo -e "\n┌─────────────────────────────────────────────────────────┐"
    echo -e "│ 5️⃣  JELLYSEERR    │  http://localhost:5055              │"
    echo -e "└─────────────────────────────────────────────────────────┘\n"
    echo -e "  🎯 First-time setup → Create admin account"
    echo -e "  ⚙️  Settings → Services → + Add Service"
    echo -e "     Jellyfin: http://jellyfin:8096 + API Key"
    echo -e "     Sonarr: http://sonarr:8989 + API Key"
    echo -e "  👥 Settings → Users → + Create User\n"
    read -p "  ✓ Press Enter to finish..."
    
    echo -e "\n╔════════════════════════════════════════════════════════════╗"
    success "  ✅ Configuration Guide Complete!"
    echo -e "╚════════════════════════════════════════════════════════════╝\n"
    info "Quick reminders:"
    echo -e "  🔒 Change Transmission password • 📚 Add indexers in Prowlarr"
    echo -e "  🔗 Connect apps with API Keys • 📺 Add your first series/movie\n"
}

# Start Services
SHOW_GUIDE_SHOWN=false
echo -e "\n┌─────────────────────────────────────────────────────────┐"
echo "│ Step 8: Starting Services                                │"
echo "└─────────────────────────────────────────────────────────┘\n"
read -p "Start Docker containers now? (y/n): " START_NOW
if [[ "$START_NOW" =~ ^[TtYy]$ ]]; then
    info "Starting Docker containers..."
    if sudo -u "$VITV_USER" bash -c "cd $INSTALL_PATH && $DOCKER_COMPOSE_CMD version &>/dev/null"; then
        info "Starting containers using: $DOCKER_COMPOSE_CMD"
        sudo -u "$VITV_USER" bash -c "cd $INSTALL_PATH && $DOCKER_COMPOSE_CMD up -d" 2>&1
        DOCKER_EXIT_CODE=$?
    elif sudo -u "$VITV_USER" bash -c "cd $INSTALL_PATH && docker compose version &>/dev/null"; then
        info "Using: docker compose"
        sudo -u "$VITV_USER" bash -c "cd $INSTALL_PATH && docker compose up -d" 2>&1
        DOCKER_EXIT_CODE=$?
        DOCKER_COMPOSE_CMD="docker compose"
    else
        error "Cannot find working Docker Compose command for user $VITV_USER"
    fi
    
    if [ $DOCKER_EXIT_CODE -eq 0 ]; then
        success "Docker containers started! ✓\n"
        info "Waiting for services to initialize (10 seconds)..."
        sleep 10
        echo -e "\n"
        info "Container status:"
        sudo -u "$VITV_USER" bash -c "cd $INSTALL_PATH && $DOCKER_COMPOSE_CMD ps"
        echo -e "\n"
        read -p "Show step-by-step configuration guide? (y/n): " SHOW_GUIDE
        [[ "$SHOW_GUIDE" =~ ^[TtYy]$ ]] && show_configuration_guide && SHOW_GUIDE_SHOWN=true
    else
        error "Failed to start containers.\n\nPossible causes:\n  1. User $VITV_USER does not have Docker permissions\n  2. Docker Compose is not available in user's PATH\n\nSolution:\n  1. Switch to user: sudo su - $VITV_USER\n  2. Go to directory: cd $INSTALL_PATH\n  3. Run manually: $DOCKER_COMPOSE_CMD up -d"
    fi
fi

# Final Summary
echo -e "\n╔════════════════════════════════════════════════════════════╗"
success "  ✅ Installation Completed Successfully!"
echo -e "╚════════════════════════════════════════════════════════════╝\n"
echo "┌─────────────────────────────────────────────────────────┐"
echo "│ Installation Summary                                     │"
echo "└─────────────────────────────────────────────────────────┘\n"
echo -e "  👤 User:        $VITV_USER (UID: $VITV_UID, GID: $VITV_GID)"
echo -e "  📁 Directory:   $INSTALL_PATH"
echo -e "  🌍 Timezone:    $TIMEZONE\n"

[[ ! "$START_NOW" =~ ^[TtYy]$ ]] && echo "┌─────────────────────────────────────────────────────────┐" && \
echo "│ Next Steps                                             │" && \
echo "└─────────────────────────────────────────────────────────┘\n" && \
echo -e "  1. Switch user: sudo su - $VITV_USER" && \
echo -e "  2. Go to: cd $INSTALL_PATH" && \
echo -e "  3. Start: $([ -f /usr/local/bin/vitv ] && echo 'vitv start' || echo './vitv.sh start')\n"

echo "┌─────────────────────────────────────────────────────────┐"
echo "│ 🌐 Application Access URLs                               │"
echo "└─────────────────────────────────────────────────────────┘\n"
echo -e "  🎬 Jellyfin:     http://localhost:8096"
echo -e "  🔍 Prowlarr:     http://localhost:9696"
echo -e "  📺 Sonarr:       http://localhost:8989"
echo -e "  🎯 Jellyseerr:   http://localhost:5055"
echo -e "  ⬇️  Transmission: http://localhost:9091\n"

[ "$SHOW_GUIDE_SHOWN" = false ] && echo "┌─────────────────────────────────────────────────────────┐" && \
echo "│ 📖 Documentation                                        │" && \
echo "└─────────────────────────────────────────────────────────┘\n" && \
echo -e "  Configuration guide: See README.md in installation directory\n"

echo "┌─────────────────────────────────────────────────────────┐"
warning "  ⚠️  IMPORTANT: Change Transmission password after first startup!"
echo -e "└─────────────────────────────────────────────────────────┘\n"
