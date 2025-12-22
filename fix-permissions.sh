#!/bin/bash

# ViTV - Fix Permissions Script
# This script fixes file permissions to allow git operations

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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
echo "  ViTV - Fix Permissions Script"
echo "=========================================="
echo ""

# Get current user
CURRENT_USER=${SUDO_USER:-$USER}
if [ "$CURRENT_USER" = "root" ]; then
    error "Please run as: sudo -u your_user ./fix-permissions.sh"
    exit 1
fi

CURRENT_UID=$(id -u "$CURRENT_USER")
CURRENT_GID=$(id -g "$CURRENT_USER")

info "Current user: $CURRENT_USER (UID: $CURRENT_UID, GID: $CURRENT_GID)"
echo ""

# Ask for directory
read -p "Enter directory path to fix (default: current directory): " TARGET_DIR
TARGET_DIR=${TARGET_DIR:-$(pwd)}

if [ ! -d "$TARGET_DIR" ]; then
    error "Directory '$TARGET_DIR' does not exist"
    exit 1
fi

info "Target directory: $TARGET_DIR"
echo ""

# Ask for permission mode
echo "Choose permission fix method:"
echo "  1. Set owner and reasonable permissions (755/644) - RECOMMENDED"
echo "  2. Set chmod 777 for all files (less secure, but works)"
echo ""
read -p "Choose option (1 or 2, default: 1): " PERM_OPTION
PERM_OPTION=${PERM_OPTION:-1}

if [ "$PERM_OPTION" = "1" ]; then
    info "Setting owner and reasonable permissions..."
    chown -R "$CURRENT_USER:$CURRENT_USER" "$TARGET_DIR"
    find "$TARGET_DIR" -type d -exec chmod 755 {} \;
    find "$TARGET_DIR" -type f -exec chmod 644 {} \;
    find "$TARGET_DIR" -name "*.sh" -exec chmod +x {} \;
    # Jellyfin config needs write access for plugins
    [ -d "$TARGET_DIR/config/jellyfin" ] && chmod -R 775 "$TARGET_DIR/config/jellyfin" && info "Jellyfin config permissions set to 775"
    success "Permissions set (755 for directories, 644 for files, +x for scripts)"
elif [ "$PERM_OPTION" = "2" ]; then
    warning "Setting chmod 777 for all files (less secure!)"
    chown -R "$CURRENT_USER:$CURRENT_USER" "$TARGET_DIR"
    chmod -R 777 "$TARGET_DIR"
    success "Permissions set to 777"
else
    error "Invalid option"
    exit 1
fi

echo ""
success "Permissions fixed!"
echo ""
info "If you have uncommitted changes blocking git pull, you can:"
echo "  1. Stash changes: git stash"
echo "  2. Then pull: git pull"
echo "  3. Apply stashed changes: git stash pop"
echo ""
echo "Or commit your changes first:"
echo "  git add ."
echo "  git commit -m 'Local changes'"
echo "  git pull"
echo ""

