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

echo "=========================================="
echo "  ViTV - Global Installation Script"
echo "=========================================="
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

# Ask for installation path
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

# Ask for timezone
read -p "Enter timezone (default: Europe/Warsaw): " TIMEZONE
TIMEZONE=${TIMEZONE:-Europe/Warsaw}

# Ask for Transmission credentials
read -p "Enter Transmission username (default: admin): " TRANS_USER
TRANS_USER=${TRANS_USER:-admin}

read -sp "Enter Transmission password (default: admin): " TRANS_PASS
TRANS_PASS=${TRANS_PASS:-admin}
echo ""

# Create directory structure
info "Creating directory structure..."
mkdir -p "$INSTALL_PATH"/{config,media,downloads,cache}
mkdir -p "$INSTALL_PATH/config"/{jellyfin,prowlarr,sonarr,jellyseerr,transmission}
mkdir -p "$INSTALL_PATH/media"/{tv,movies}
mkdir -p "$INSTALL_PATH/downloads"/watch
mkdir -p "$INSTALL_PATH/cache"/jellyfin

success "Directory structure created"

# Set permissions
info "Setting permissions..."
chown -R "$VITV_USER:$VITV_USER" "$INSTALL_PATH"
chmod -R 755 "$INSTALL_PATH"
# Config directories - more restrictive
chmod 700 "$INSTALL_PATH/config"/*

success "Permissions set"

echo ""

# Copy project files to installation directory
info "Copying project files..."

# Check if we are in the project directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$SCRIPT_DIR/docker-compose.yml" ]; then
    cp "$SCRIPT_DIR/docker-compose.yml" "$INSTALL_PATH/"
    cp "$SCRIPT_DIR/env.example" "$INSTALL_PATH/" 2>/dev/null || true
    cp "$SCRIPT_DIR/.dockerignore" "$INSTALL_PATH/" 2>/dev/null || true
    cp "$SCRIPT_DIR/.gitignore" "$INSTALL_PATH/" 2>/dev/null || true
    cp "$SCRIPT_DIR/README.md" "$INSTALL_PATH/" 2>/dev/null || true
    success "Project files copied"
else
    warning "Project files not found in $SCRIPT_DIR"
    warning "You will need to copy files manually to $INSTALL_PATH"
fi

# Change owner of copied files
chown -R "$VITV_USER:$VITV_USER" "$INSTALL_PATH"

echo ""

# Update docker-compose.yml with absolute paths
info "Updating docker-compose.yml with absolute paths..."
if [ -f "$INSTALL_PATH/docker-compose.yml" ]; then
    # Backup original file
    cp "$INSTALL_PATH/docker-compose.yml" "$INSTALL_PATH/docker-compose.yml.bak"
    
    # Replace relative paths with absolute paths
    sed -i "s|\./config|$INSTALL_PATH/config|g" "$INSTALL_PATH/docker-compose.yml"
    sed -i "s|\./media|$INSTALL_PATH/media|g" "$INSTALL_PATH/docker-compose.yml"
    sed -i "s|\./downloads|$INSTALL_PATH/downloads|g" "$INSTALL_PATH/docker-compose.yml"
    sed -i "s|\./cache|$INSTALL_PATH/cache|g" "$INSTALL_PATH/docker-compose.yml"
    
    success "docker-compose.yml updated"
fi

# Create .env file
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
success ".env file created"

echo ""

# Create management script
info "Creating management script..."
cat > "$INSTALL_PATH/vitv.sh" << 'SCRIPT_EOF'
#!/bin/bash

# ViTV - Management Script
# Usage: ./vitv.sh [start|stop|restart|status|logs|update|rebuild]

set -e

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
success "Management script created"

# Create symbolic link to management script (optional)
read -p "Do you want to create symbolic link /usr/local/bin/vitv? (y/n): " CREATE_LINK
if [[ "$CREATE_LINK" =~ ^[TtYy]$ ]]; then
    ln -sf "$INSTALL_PATH/vitv.sh" /usr/local/bin/vitv
    success "Symbolic link created: /usr/local/bin/vitv"
fi

echo ""

# Function to display configuration instructions
show_configuration_guide() {
    echo ""
    echo "=========================================="
    echo "  Configuration Instructions - Step by Step"
    echo "=========================================="
    echo ""
    
    info "IMPORTANT: Configure applications in the following order:"
    echo "  1. Transmission"
    echo "  2. Prowlarr"
    echo "  3. Sonarr"
    echo "  4. Jellyfin"
    echo "  5. Jellyseerr"
    echo ""
    read -p "Press Enter to continue..."
    echo ""
    
    # 1. Transmission
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  1. TRANSMISSION - BitTorrent Client"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📍 URL: http://localhost:9091"
    echo ""
    echo "Configuration steps:"
    echo "  1. Open http://localhost:9091 in your browser"
    echo "  2. Log in using:"
    echo "     - Username: $TRANS_USER"
    echo "     - Password: $TRANS_PASS"
    echo "  3. Go to: Hamburger menu (☰) → Edit Preferences"
    echo "  4. In the 'Torrents' tab, set 'Download to:' to:"
    echo "     $INSTALL_PATH/downloads"
    echo "  5. (Optional) Set 'Use temporary folder:' to:"
    echo "     $INSTALL_PATH/downloads"
    echo "  6. Go to: Remote Access tab"
    echo "  7. ⚠️  CHANGE PASSWORD to a secure one!"
    echo ""
    read -p "Press Enter to proceed to next application..."
    echo ""
    
    # 2. Prowlarr
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  2. PROWLARR - Indexer Manager"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📍 URL: http://localhost:9696"
    echo ""
    echo "Configuration steps:"
    echo "  1. Open http://localhost:9696 in your browser"
    echo "  2. Go to: Settings → Indexers"
    echo "  3. Click '+ Add Indexer'"
    echo "  4. Add indexers (e.g. RARBG, 1337x, TorrentGalaxy)"
    echo "     - Select indexer from list"
    echo "     - Fill required fields (if needed)"
    echo "     - Save"
    echo ""
    echo "  5. Go to: Settings → Apps"
    echo "  6. Click '+ Add Application'"
    echo "  7. Select 'Sonarr'"
    echo "  8. Fill in:"
    echo "     - Name: Sonarr"
    echo "     - Prowlarr Server: http://prowlarr:9696"
    echo "       (Use container name 'prowlarr' for inter-container communication)"
    echo "     - Sonarr Server: http://sonarr:8989"
    echo "       (Use container name 'sonarr' for inter-container communication)"
    echo "     - Sonarr API Key: (you will need from Sonarr)"
    echo "     - Sync App Indexers: ✓ (check)"
    echo "  9. Save (you can add API Key later)"
    echo ""
    echo "⚠️  IMPORTANT: Use container names (sonarr, prowlarr) NOT localhost"
    echo "   for inter-container communication!"
    echo ""
    echo "💡 TIP: Sonarr API Key can be found in:"
    echo "   Sonarr → Settings → General → Security → API Key"
    echo ""
    read -p "Press Enter to proceed to next application..."
    echo ""
    
    # 3. Sonarr
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  3. SONARR - TV Series Manager"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📍 URL: http://localhost:8989"
    echo ""
    echo "Configuration steps:"
    echo ""
    echo "A. Media Management:"
    echo "  1. Open http://localhost:8989"
    echo "  2. Go to: Settings → Media Management"
    echo "  3. Set 'Root Folders':"
    echo "     - Click '+ Add Root Folder'"
    echo "     - Enter: /tv"
    echo "       (This is the container path, mapped from $INSTALL_PATH/media/tv)"
    echo "     - Save"
    echo ""
    echo "B. Download Clients:"
    echo "  4. Go to: Settings → Download Clients"
    echo "  5. Click '+ Add Download Client'"
    echo "  6. Select 'Transmission'"
    echo "  7. Fill in:"
    echo "     - Name: Transmission"
    echo "     - Host: transmission"
    echo "     - Port: 9091"
    echo "     - Username: $TRANS_USER"
    echo "     - Password: $TRANS_PASS"
    echo "     - Category: tv"
    echo "  8. Click 'Test' to check connection"
    echo "  9. Save"
    echo ""
    echo "C. Indexers:"
    echo "  10. Go to: Settings → Indexers"
    echo "  11. Click '+ Add Indexer'"
    echo "  12. Select 'Prowlarr'"
    echo "  13. Fill in:"
    echo "      - Name: Prowlarr"
    echo "      - URL: http://prowlarr:9696"
    echo "        (Use container name 'prowlarr' for inter-container communication)"
    echo "      - API Key: (found in Prowlarr → Settings → General)"
    echo "  14. Click 'Test' to check connection"
    echo "  15. Save"
    echo ""
    echo "D. Adding first TV series:"
    echo "  16. Click 'Add New' in main menu"
    echo "  17. Search for series"
    echo "  18. Select series and click 'Add Series'"
    echo "  19. Select folder: /tv"
    echo "     (This is the container path, mapped from $INSTALL_PATH/media/tv)"
    echo "  20. Save"
    echo ""
    read -p "Press Enter to proceed to next application..."
    echo ""
    
    # 4. Jellyfin
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  4. JELLYFIN - Media Server"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📍 URL: http://localhost:8096"
    echo ""
    echo "Configuration steps:"
    echo "  1. Open http://localhost:8096 in your browser"
    echo "  2. Complete first-time setup:"
    echo "     - Select language"
    echo "     - Create administrator account"
    echo "     - Select libraries (you can skip for now)"
    echo ""
    echo "  3. Go to: Dashboard (home icon in top left)"
    echo "  4. Click: Libraries → '+ Add Media Library'"
    echo ""
    echo "  5. Add Movies library:"
    echo "     - Content Type: Movies"
    echo "     - Display Name: Movies"
    echo "     - Folders: Click '+', enter: /media/movies"
    echo "       (This is the container path, mapped from $INSTALL_PATH/media/movies)"
    echo "     - Save"
    echo ""
    echo "  6. Add TV Shows library:"
    echo "     - Content Type: TV Shows"
    echo "     - Display Name: TV Shows"
    echo "     - Folders: Click '+', enter: /media/tv"
    echo "       (This is the container path, mapped from $INSTALL_PATH/media/tv)"
    echo "     - Save"
    echo ""
    echo "  7. Go to: Dashboard → Libraries"
    echo "  8. Click 'Scan All Libraries' to start scanning"
    echo ""
    echo "  9. (Optional) Go to: Dashboard → API Keys"
    echo "     - Create new API key for Jellyseerr"
    echo "     - Copy key (will be needed in Jellyseerr)"
    echo ""
    read -p "Press Enter to proceed to next application..."
    echo ""
    
    # 5. Jellyseerr
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  5. JELLYSEERR - Media Request System"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📍 URL: http://localhost:5055"
    echo ""
    echo "Configuration steps:"
    echo "  1. Open http://localhost:5055 in your browser"
    echo "  2. Complete first-time setup:"
    echo "     - Create administrator account"
    echo "     - Select language"
    echo ""
    echo "  3. Go to: Settings → Services"
    echo ""
    echo "  4. Add Jellyfin:"
    echo "     - Click '+ Add Service'"
    echo "     - Select 'Jellyfin'"
    echo "     - Name: Jellyfin"
    echo "     - Server URL: http://jellyfin:8096"
    echo "       (Use container name 'jellyfin' for inter-container communication)"
    echo "     - API Key: (paste key from Jellyfin → Dashboard → API Keys)"
    echo "     - Save"
    echo ""
    echo "  5. Add Sonarr:"
    echo "     - Click '+ Add Service'"
    echo "     - Select 'Sonarr'"
    echo "     - Name: Sonarr"
    echo "     - Server URL: http://sonarr:8989"
    echo "       (Use container name 'sonarr' for inter-container communication)"
    echo "     - API Key: (found in Sonarr → Settings → General → Security)"
    echo "     - Save"
    echo ""
    echo "  6. Go to: Settings → Users"
    echo "  7. Click '+ Create User' to add users"
    echo "  8. Users will be able to request movies and TV series through Jellyseerr"
    echo ""
    echo "  9. (Optional) Go to: Settings → Notifications"
    echo "     - Configure notifications (Discord, Email, etc.)"
    echo ""
    read -p "Press Enter to finish..."
    echo ""
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    success "Configuration instructions completed!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    info "Remember:"
    echo "  - Change Transmission password to a secure one!"
    echo "  - Add indexers in Prowlarr"
    echo "  - Connect all applications using API Keys"
    echo "  - Add first TV series/movies for testing"
    echo ""
}

# Ask if user wants to start Docker containers now
SHOW_GUIDE_SHOWN=false
echo ""
read -p "Do you want to start Docker containers now? (y/n): " START_NOW
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
        success "Docker containers started!"
        echo ""
        info "Waiting for services to start (10 seconds)..."
        sleep 10
        
        # Check status
        echo ""
        info "Container status:"
        sudo -u "$VITV_USER" bash -c "cd $INSTALL_PATH && $DOCKER_COMPOSE_CMD ps"
        echo ""
        
        # Ask if user wants to see configuration instructions
        read -p "Do you want to display step-by-step configuration instructions? (y/n): " SHOW_GUIDE
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
echo "=========================================="
success "Installation completed successfully!"
echo "=========================================="
echo ""
echo "Installation details:"
echo "  User: $VITV_USER (UID: $VITV_UID, GID: $VITV_GID)"
echo "  Installation directory: $INSTALL_PATH"
echo "  Timezone: $TIMEZONE"
echo ""

if [[ ! "$START_NOW" =~ ^[TtYy]$ ]]; then
    echo "Next steps:"
    echo "  1. Switch to user $VITV_USER:"
    echo "     sudo su - $VITV_USER"
    echo ""
    echo "  2. Go to installation directory:"
    echo "     cd $INSTALL_PATH"
    echo ""
    echo "  3. Start services:"
    if [ -f /usr/local/bin/vitv ]; then
        echo "     vitv start"
    else
        echo "     ./vitv.sh start"
        echo "     # or"
        echo "     docker-compose up -d"
    fi
    echo ""
fi

echo "Application access:"
echo "  - Jellyfin:     http://localhost:8096"
echo "  - Prowlarr:     http://localhost:9696"
echo "  - Sonarr:       http://localhost:8989"
echo "  - Jellyseerr:   http://localhost:5055"
echo "  - Transmission: http://localhost:9091"
echo ""

if [ "$SHOW_GUIDE_SHOWN" = false ]; then
    echo "To display step-by-step configuration instructions:"
    echo "  cd $INSTALL_PATH"
    echo "  # Start services if not already:"
    if [ -f /usr/local/bin/vitv ]; then
        echo "  vitv start"
    else
        echo "  ./vitv.sh start"
    fi
    echo "  # Then read:"
    echo "  - README.md - full documentation with configuration instructions"
    echo "  - INSTALL.md - detailed installation instructions"
    echo ""
fi

warning "IMPORTANT: Change Transmission password after first startup!"
echo ""


