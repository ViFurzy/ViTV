#!/bin/bash

# ViTV - Global Installation Script
# This script creates a user, configures permissions and prepares the environment

set -e

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display messages
info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then 
    error "This script must be run as root (use sudo)"
    exit 1
fi

clear
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                            ║"
echo "║          🎬 ViTV - Media Streaming System 🎬              ║"
echo "║          Global Installation & Setup Script                ║"
echo "║                                                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    error "Docker is not installed."
    echo "Install Docker using:"
    echo "  curl -fsSL https://get.docker.com -o get-docker.sh"
    echo "  sh get-docker.sh"
    exit 1
fi

# Check if Docker Compose is installed and determine command
DOCKER_COMPOSE_CMD=""
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker-compose"
elif docker compose version &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker compose"
else
    error "Docker Compose is not installed."
    exit 1
fi

success "Docker and Docker Compose are installed (using: $DOCKER_COMPOSE_CMD)"
echo ""

# Ask for username
echo "┌─────────────────────────────────────────────────────────┐"
echo "│ Step 1: User Configuration                                │"
echo "└─────────────────────────────────────────────────────────┘"
echo ""
read -p "Enter username for ViTV (default: vitv): " VITV_USER
VITV_USER=${VITV_USER:-vitv}

# Check if user already exists
if id "$VITV_USER" &>/dev/null; then
    warning "User '$VITV_USER' already exists."
    read -p "Do you want to use the existing user? (y/n): " USE_EXISTING
    if [[ ! "$USE_EXISTING" =~ ^[TtYy]$ ]]; then
        error "Installation cancelled."
        exit 1
    fi
    VITV_UID=$(id -u "$VITV_USER")
    VITV_GID=$(id -g "$VITV_USER")
else
    # Create user
    info "Creating user '$VITV_USER'..."
    useradd -r -m -s /bin/bash "$VITV_USER" 2>/dev/null || {
        error "Failed to create user."
        exit 1
    }
    VITV_UID=$(id -u "$VITV_USER")
    VITV_GID=$(id -g "$VITV_USER")
    success "User '$VITV_USER' created (UID: $VITV_UID, GID: $VITV_GID)"
fi

# Add user to docker group
info "Adding user to docker group..."
if getent group docker > /dev/null 2>&1; then
    usermod -aG docker "$VITV_USER"
    success "User added to docker group"
    warning "NOTE: For docker group changes to take effect, user $VITV_USER must:"
    echo "  - Log out and log back in, OR"
    echo "  - Run: newgrp docker"
else
    warning "Docker group does not exist. Creating group..."
    groupadd docker
    usermod -aG docker "$VITV_USER"
    success "Docker group created and user added"
    warning "NOTE: For docker group changes to take effect, user $VITV_USER must:"
    echo "  - Log out and log back in, OR"
    echo "  - Run: newgrp docker"
fi

echo ""
echo "┌─────────────────────────────────────────────────────────┐"
echo "│ Step 2: Installation Path                               │"
echo "└─────────────────────────────────────────────────────────┘"
echo ""
read -p "Enter installation path (default: /opt/vitv): " INSTALL_PATH
INSTALL_PATH=${INSTALL_PATH:-/opt/vitv}

# Expand path to full absolute path
INSTALL_PATH=$(readlink -f "$INSTALL_PATH" 2>/dev/null || echo "$INSTALL_PATH")

info "Installation path: $INSTALL_PATH"

# Check if directory exists
if [ -d "$INSTALL_PATH" ]; then
    warning "Directory '$INSTALL_PATH' already exists."
    read -p "Do you want to continue? Existing files may be overwritten. (y/n): " CONTINUE
    if [[ ! "$CONTINUE" =~ ^[TtYy]$ ]]; then
        error "Installation cancelled."
        exit 1
    fi
else
    # Create main directory
    mkdir -p "$INSTALL_PATH"
    success "Main directory created"
fi

# Set directory owner
chown "$VITV_USER:$VITV_USER" "$INSTALL_PATH"
success "Directory owner set to $VITV_USER"

echo ""
echo "┌─────────────────────────────────────────────────────────┐"
echo "│ Step 3: System Configuration                            │"
echo "└─────────────────────────────────────────────────────────┘"
echo ""
read -p "Enter timezone (default: Europe/Warsaw): " TIMEZONE
TIMEZONE=${TIMEZONE:-Europe/Warsaw}

echo ""
echo "┌─────────────────────────────────────────────────────────┐"
echo "│ Step 4: Transmission Credentials                       │"
echo "└─────────────────────────────────────────────────────────┘"
echo ""
read -p "Enter Transmission username (default: admin): " TRANS_USER
TRANS_USER=${TRANS_USER:-admin}

read -sp "Enter Transmission password (default: admin): " TRANS_PASS
TRANS_PASS=${TRANS_PASS:-admin}
echo ""

# Create directory structure
echo ""
echo "┌─────────────────────────────────────────────────────────┐"
echo "│ Step 5: Creating Directory Structure                    │"
echo "└─────────────────────────────────────────────────────────┘"
echo ""
info "Creating directories..."
mkdir -p "$INSTALL_PATH"/{config,media,downloads,cache}
mkdir -p "$INSTALL_PATH/config"/{jellyfin,prowlarr,sonarr,jellyseerr,transmission}
mkdir -p "$INSTALL_PATH/media"/{tv,movies}
mkdir -p "$INSTALL_PATH/downloads"/watch
mkdir -p "$INSTALL_PATH/cache"/jellyfin
success "Directory structure created ✓"

info "Setting permissions..."
chown -R "$VITV_USER:$VITV_USER" "$INSTALL_PATH"
chmod -R 755 "$INSTALL_PATH"
chmod 775 "$INSTALL_PATH/downloads" "$INSTALL_PATH/downloads/watch"
chmod 700 "$INSTALL_PATH/config"/*
success "Permissions configured ✓"

echo ""

# Copy project files to installation directory
echo ""
echo "┌─────────────────────────────────────────────────────────┐"
echo "│ Step 6: Copying Project Files                           │"
echo "└─────────────────────────────────────────────────────────┘"
echo ""
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
    warning "You will need to copy files manually to $INSTALL_PATH"
fi

chown -R "$VITV_USER:$VITV_USER" "$INSTALL_PATH"

echo ""

# Update docker-compose.yml with absolute paths
echo ""
echo "┌─────────────────────────────────────────────────────────┐"
echo "│ Step 7: Configuring Docker Compose                       │"
echo "└─────────────────────────────────────────────────────────┘"
echo ""
info "Updating paths in docker-compose.yml..."
if [ -f "$INSTALL_PATH/docker-compose.yml" ]; then
    cp "$INSTALL_PATH/docker-compose.yml" "$INSTALL_PATH/docker-compose.yml.bak"
    sed -i "s|\./config|$INSTALL_PATH/config|g" "$INSTALL_PATH/docker-compose.yml"
    sed -i "s|\./media|$INSTALL_PATH/media|g" "$INSTALL_PATH/docker-compose.yml"
    sed -i "s|\./downloads|$INSTALL_PATH/downloads|g" "$INSTALL_PATH/docker-compose.yml"
    sed -i "s|\./cache|$INSTALL_PATH/cache|g" "$INSTALL_PATH/docker-compose.yml"
    success "docker-compose.yml configured ✓"
fi

info "Creating .env file..."
cat > "$INSTALL_PATH/.env" << EOF
# User ID and Group ID for file permissions
PUID=$VITV_UID
PGID=$VITV_GID

# Timezone
TZ=$TIMEZONE

# Transmission credentials
TRANSMISSION_USER=$TRANS_USER
TRANSMISSION_PASS=$TRANS_PASS

# Jellyfin settings
JELLYFIN_PublishedServerUrl=http://localhost:8096
EOF

chown "$VITV_USER:$VITV_USER" "$INSTALL_PATH/.env"
chmod 600 "$INSTALL_PATH/.env"
success ".env file created ✓"

echo ""
echo "┌─────────────────────────────────────────────────────────┐"
echo "│ Step 8: Creating Management Script                      │"
echo "└─────────────────────────────────────────────────────────┘"
echo ""
info "Generating vitv.sh management script..."
cat > "$INSTALL_PATH/vitv.sh" << 'SCRIPT_EOF'
#!/bin/bash

# ViTV - Management Script
# Usage: ./vitv.sh [start|stop|restart|status|logs|update|rebuild]

set -e

# Get the real installation directory
# If script is symlinked, resolve the symlink
SCRIPT_PATH="${BASH_SOURCE[0]}"
if [ -L "$SCRIPT_PATH" ]; then
    SCRIPT_PATH=$(readlink -f "$SCRIPT_PATH")
fi
INSTALL_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

# Fallback: try to detect from common installation paths
if [ ! -f "$INSTALL_DIR/docker-compose.yml" ]; then
    for path in "/opt/vitv" "/home/$USER/vitv" "$HOME/vitv"; do
        if [ -f "$path/docker-compose.yml" ]; then
            INSTALL_DIR="$path"
            break
        fi
    done
fi

if [ ! -f "$INSTALL_DIR/docker-compose.yml" ]; then
    echo "Error: docker-compose.yml not found in $INSTALL_DIR"
    echo "Please run this script from the installation directory or ensure docker-compose.yml exists."
    exit 1
fi

cd "$INSTALL_DIR"

# Detect available docker-compose command
detect_docker_compose() {
    if command -v docker-compose &> /dev/null; then
        echo "docker-compose"
    elif docker compose version &> /dev/null 2>&1; then
        echo "docker compose"
    else
        echo "docker-compose"  # fallback
    fi
}

DOCKER_COMPOSE_CMD=$(detect_docker_compose)

case "$1" in
    start)
        echo "Starting ViTV services..."
        $DOCKER_COMPOSE_CMD up -d
        echo "Services started!"
        ;;
    stop)
        echo "Stopping ViTV services..."
        $DOCKER_COMPOSE_CMD down
        echo "Services stopped!"
        ;;
    restart)
        echo "Restarting ViTV services..."
        $DOCKER_COMPOSE_CMD restart
        echo "Services restarted!"
        ;;
    status)
        echo "ViTV services status:"
        $DOCKER_COMPOSE_CMD ps
        ;;
    logs)
        $DOCKER_COMPOSE_CMD logs -f "${2:-}"
        ;;
    update)
        echo "Updating Docker images..."
        $DOCKER_COMPOSE_CMD pull
        $DOCKER_COMPOSE_CMD up -d
        echo "Update completed!"
        ;;
    rebuild)
        echo "Rebuilding ViTV services..."
        echo "Stopping containers (if running)..."
        $DOCKER_COMPOSE_CMD down 2>/dev/null || true
        echo "Building and starting containers..."
        $DOCKER_COMPOSE_CMD up -d --build
        echo "Services rebuilt and started!"
        ;;
    *)
        echo "ViTV - Management Script"
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  start     - Start all services"
        echo "  stop      - Stop all services"
        echo "  restart   - Restart all services"
        echo "  status    - Show services status"
        echo "  logs [service] - Show logs (optionally for specific service)"
        echo "  update    - Update and restart services"
        echo "  rebuild   - Stop, rebuild and start services"
        exit 1
        ;;
esac
SCRIPT_EOF

chmod +x "$INSTALL_PATH/vitv.sh"
chown "$VITV_USER:$VITV_USER" "$INSTALL_PATH/vitv.sh"
success "Management script created ✓"

echo ""
read -p "Create system-wide command 'vitv'? (y/n): " CREATE_LINK
if [[ "$CREATE_LINK" =~ ^[TtYy]$ ]]; then
    ln -sf "$INSTALL_PATH/vitv.sh" /usr/local/bin/vitv
    success "System command 'vitv' created ✓"
fi

echo ""

# Function to display configuration instructions
show_configuration_guide() {
    clear
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║     🎬 ViTV Configuration Guide - Quick Setup 🎬          ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    info "Configure in order: Transmission → Prowlarr → Sonarr → Jellyfin → Jellyseerr"
    echo ""
    read -p "Press Enter to start..." 
    echo ""
    
    # 1. Transmission
    echo "┌─────────────────────────────────────────────────────────┐"
    echo "│ 1️⃣  TRANSMISSION  │  http://localhost:9091              │"
    echo "└─────────────────────────────────────────────────────────┘"
    echo ""
    echo "  🔐 Login: $TRANS_USER / $TRANS_PASS"
    echo "  📁 Menu (☰) → Edit Preferences → Torrents"
    echo "     Set 'Download to:' → $INSTALL_PATH/downloads"
    echo "  🔒 Remote Access → Change password!"
    echo ""
    read -p "  ✓ Press Enter to continue..."
    echo ""
    
    # 2. Prowlarr
    echo "┌─────────────────────────────────────────────────────────┐"
    echo "│ 2️⃣  PROWLARR      │  http://localhost:9696              │"
    echo "└─────────────────────────────────────────────────────────┘"
    echo ""
    echo "  📚 Settings → Indexers → + Add Indexer"
    echo "     Add: RARBG, 1337x, TorrentGalaxy"
    echo ""
    echo "  🔗 Settings → Apps → + Add Application → Sonarr"
    echo "     • Name: Sonarr"
    echo "     • Prowlarr Server: http://prowlarr:9696"
    echo "     • Sonarr Server: http://sonarr:8989"
    echo "     • API Key: (get from Sonarr later)"
    echo "     • ✓ Sync App Indexers"
    echo ""
    echo "  ⚠️  Use container names (prowlarr/sonarr), NOT localhost!"
    echo ""
    read -p "  ✓ Press Enter to continue..."
    echo ""
    
    # 3. Sonarr
    echo "┌─────────────────────────────────────────────────────────┐"
    echo "│ 3️⃣  SONARR        │  http://localhost:8989              │"
    echo "└─────────────────────────────────────────────────────────┘"
    echo ""
    echo "  📂 Settings → Media Management → + Add Root Folder"
    echo "     Path: /tv  (container path)"
    echo ""
    echo "  ⬇️  Settings → Download Clients → + Add → Transmission"
    echo "     • Host: transmission  • Port: 9091"
    echo "     • Username: $TRANS_USER  • Password: $TRANS_PASS"
    echo "     • Category: tv  • Test → Save"
    echo ""
    echo "  🗺️  Remote Path Mappings (IMPORTANT!) → + Add"
    echo "     • Host: transmission"
    echo "     • Remote: /downloads/tv"
    echo "     • Local: /downloads"
    echo ""
    echo "  🔍 Settings → Indexers → + Add → Prowlarr"
    echo "     • URL: http://prowlarr:9696"
    echo "     • API Key: (Prowlarr → Settings → General)"
    echo ""
    read -p "  ✓ Press Enter to continue..."
    echo ""
    
    # 4. Jellyfin
    echo "┌─────────────────────────────────────────────────────────┐"
    echo "│ 4️⃣  JELLYFIN      │  http://localhost:8096              │"
    echo "└─────────────────────────────────────────────────────────┘"
    echo ""
    echo "  🎬 First-time setup → Create admin account"
    echo ""
    echo "  📚 Dashboard → Libraries → + Add Media Library"
    echo "     Movies: /media/movies"
    echo "     TV Shows: /media/tv"
    echo ""
    echo "  🔑 Dashboard → API Keys → Create key (for Jellyseerr)"
    echo ""
    read -p "  ✓ Press Enter to continue..."
    echo ""
    
    # 5. Jellyseerr
    echo "┌─────────────────────────────────────────────────────────┐"
    echo "│ 5️⃣  JELLYSEERR    │  http://localhost:5055              │"
    echo "└─────────────────────────────────────────────────────────┘"
    echo ""
    echo "  🎯 First-time setup → Create admin account"
    echo ""
    echo "  ⚙️  Settings → Services → + Add Service"
    echo "     Jellyfin: http://jellyfin:8096 + API Key"
    echo "     Sonarr: http://sonarr:8989 + API Key"
    echo ""
    echo "  👥 Settings → Users → + Create User"
    echo ""
    read -p "  ✓ Press Enter to finish..."
    echo ""
    
    echo "╔════════════════════════════════════════════════════════════╗"
    success "  ✅ Configuration Guide Complete!"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    info "Quick reminders:"
    echo "  🔒 Change Transmission password"
    echo "  📚 Add indexers in Prowlarr"
    echo "  🔗 Connect apps with API Keys"
    echo "  📺 Add your first series/movie"
    echo ""
}

# Ask if user wants to start Docker containers now
SHOW_GUIDE_SHOWN=false
echo ""
echo "┌─────────────────────────────────────────────────────────┐"
echo "│ Step 9: Starting Services                                │"
echo "└─────────────────────────────────────────────────────────┘"
echo ""
read -p "Start Docker containers now? (y/n): " START_NOW
if [[ "$START_NOW" =~ ^[TtYy]$ ]]; then
    info "Starting Docker containers..."
    
    # Run as vitv user
    # Use full environment path to ensure PATH is correct
    info "Checking Docker Compose availability for user $VITV_USER..."
    
    # Check if user can use docker compose
    if sudo -u "$VITV_USER" bash -c "cd $INSTALL_PATH && $DOCKER_COMPOSE_CMD version &>/dev/null"; then
        info "Starting containers using: $DOCKER_COMPOSE_CMD"
        sudo -u "$VITV_USER" bash -c "cd $INSTALL_PATH && $DOCKER_COMPOSE_CMD up -d" 2>&1
        DOCKER_EXIT_CODE=$?
    else
        # Fallback - try docker compose (plugin)
        warning "Checking alternative method..."
        if sudo -u "$VITV_USER" bash -c "cd $INSTALL_PATH && docker compose version &>/dev/null"; then
            info "Using: docker compose"
            sudo -u "$VITV_USER" bash -c "cd $INSTALL_PATH && docker compose up -d" 2>&1
            DOCKER_EXIT_CODE=$?
            DOCKER_COMPOSE_CMD="docker compose"
        else
            error "Cannot find working Docker Compose command for user $VITV_USER"
            DOCKER_EXIT_CODE=1
        fi
    fi
    
    if [ $DOCKER_EXIT_CODE -eq 0 ]; then
        success "Docker containers started! ✓"
        echo ""
        info "Waiting for services to initialize (10 seconds)..."
        sleep 10
        
        echo ""
        info "Container status:"
        sudo -u "$VITV_USER" bash -c "cd $INSTALL_PATH && $DOCKER_COMPOSE_CMD ps"
        echo ""
        
        read -p "Show step-by-step configuration guide? (y/n): " SHOW_GUIDE
        if [[ "$SHOW_GUIDE" =~ ^[TtYy]$ ]]; then
            show_configuration_guide
            SHOW_GUIDE_SHOWN=true
        fi
    else
        error "Failed to start containers."
        echo ""
        warning "Possible causes:"
        echo "  1. User $VITV_USER does not have Docker permissions"
        echo "  2. Docker Compose is not available in user's PATH"
        echo ""
        info "Solution:"
        echo "  1. Switch to user: sudo su - $VITV_USER"
        echo "  2. Go to directory: cd $INSTALL_PATH"
        echo "  3. Run manually: $DOCKER_COMPOSE_CMD up -d"
        echo ""
        echo "Or check logs:"
        echo "  cd $INSTALL_PATH"
        echo "  $DOCKER_COMPOSE_CMD logs"
        echo ""
        echo "You can also run manually after switching to user:"
        echo "  sudo su - $VITV_USER"
        echo "  cd $INSTALL_PATH"
        echo "  ./vitv.sh start"
    fi
fi

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                            ║"
success "  ✅ Installation Completed Successfully!"
echo "║                                                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "┌─────────────────────────────────────────────────────────┐"
echo "│ Installation Summary                                     │"
echo "└─────────────────────────────────────────────────────────┘"
echo ""
echo "  👤 User:        $VITV_USER (UID: $VITV_UID, GID: $VITV_GID)"
echo "  📁 Directory:   $INSTALL_PATH"
echo "  🌍 Timezone:    $TIMEZONE"
echo ""

if [[ ! "$START_NOW" =~ ^[TtYy]$ ]]; then
    echo "┌─────────────────────────────────────────────────────────┐"
    echo "│ Next Steps                                             │"
    echo "└─────────────────────────────────────────────────────────┘"
    echo ""
    echo "  1. Switch user: sudo su - $VITV_USER"
    echo "  2. Go to: cd $INSTALL_PATH"
    echo "  3. Start: "
    if [ -f /usr/local/bin/vitv ]; then
        echo "     vitv start"
    else
        echo "     ./vitv.sh start"
    fi
    echo ""
fi

echo "┌─────────────────────────────────────────────────────────┐"
echo "│ 🌐 Application Access URLs                               │"
echo "└─────────────────────────────────────────────────────────┘"
echo ""
echo "  🎬 Jellyfin:     http://localhost:8096"
echo "  🔍 Prowlarr:     http://localhost:9696"
echo "  📺 Sonarr:       http://localhost:8989"
echo "  🎯 Jellyseerr:   http://localhost:5055"
echo "  ⬇️  Transmission: http://localhost:9091"
echo ""

if [ "$SHOW_GUIDE_SHOWN" = false ]; then
    echo "┌─────────────────────────────────────────────────────────┐"
    echo "│ 📖 Documentation                                        │"
    echo "└─────────────────────────────────────────────────────────┘"
    echo ""
    echo "  Configuration guide: See README.md in installation directory"
    echo "  Full docs: $INSTALL_PATH/README.md"
    echo ""
fi

echo "┌─────────────────────────────────────────────────────────┐"
warning "  ⚠️  IMPORTANT: Change Transmission password after first startup!"
echo "└─────────────────────────────────────────────────────────┘"
echo ""


