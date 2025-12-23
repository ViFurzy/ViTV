# ViTV - Comprehensive Media Streaming System

Comprehensive Docker solution containing all essential tools for managing and streaming media:
- **Jellyfin** - Media Server
- **Prowlarr** - Indexer Manager
- **Sonarr** - TV Series Manager
- **Jellyseerr** - Media Request System
- **Transmission** - BitTorrent Client

## Quick Start

```bash
# Clone repository
git clone https://github.com/ViFurzy/ViTV.git
cd ViTV

# Run installation (scripts are already executable)
sudo ./install.sh
```

> **Note**: Shell scripts (`.sh` files) are configured with execute permissions in Git. After cloning, they should be executable on Linux/Unix systems. If you encounter permission issues, run: `chmod +x *.sh`

See [QUICKSTART.md](QUICKSTART.md) for a quick guide or [INSTALL.md](INSTALL.md) for detailed instructions.

## Requirements

- Docker (version 20.10 or newer)
- Docker Compose (version 1.29 or newer)
- Ubuntu (or other Linux system)
- Minimum 4GB RAM
- Free disk space for media
- Root permissions (sudo) for installation

> 💡 **New**: Use the automatic installation script `install.sh`, which will create a user, configure permissions and prepare the entire environment! See [INSTALL.md](INSTALL.md) for detailed instructions.

## Installation

### Option 1: Automatic Installation (RECOMMENDED)

Use the global installation script which automatically:
- Creates a dedicated Linux user
- Configures all permissions
- Creates directory structure
- Configures all applications
- **Optionally starts Docker containers**
- **Optionally displays interactive step-by-step configuration instructions**
- **Clean install option** - removes existing configurations and containers for fresh setup

```bash
# Download or clone project
cd /path/to/project

# Run installation script as root
sudo ./install.sh
```

The script will ask you for:
- **Installation Mode** - Clean install (removes existing configs) or normal install
- Username (default: `vitv`)
- Installation path (default: `/opt/vitv`)
- Timezone (default: `Europe/Warsaw`)
- Transmission login credentials
- **Do you want to start Docker containers now?** (y/n)
- **Do you want to display step-by-step configuration instructions?** (y/n) - if containers were started

#### Clean Install Option

If you want to start fresh and remove all existing configurations:

1. When prompted **"Perform clean install?"**, answer **yes**
2. Enter the installation path to clean (default: `/opt/vitv`)
3. The script will:
   - Stop and remove all Docker containers
   - Remove configuration directories (`config/`)
   - Optionally remove media and downloads (you can choose to keep them)
4. Then proceed with fresh installation

**Use clean install when:**
- You want to reconfigure everything from scratch
- You're experiencing configuration issues
- You want to reset application settings

> 💡 **Tip**: If you choose to display instructions, the script will guide you through configuring each application (Transmission, Prowlarr, Sonarr, Jellyfin, Jellyseerr) with detailed steps and URLs.

After installation completes (if containers were not started):
```bash
# Switch to created user
sudo su - vitv  # or other username

# Go to installation directory
cd /opt/vitv  # or other path

# Start services
./vitv.sh start
# or if symbolic link was created:
vitv start
```

### Option 2: Manual Installation

#### 1. Clone/Prepare Project

```bash
cd /path/to/project
```

#### 2. Configure Environment Variables

```bash
cp env.example .env
nano .env  # or use another editor
```

Update values in `.env` file:
- `PUID` and `PGID` - User and group ID (check using `id $USER`)
- `TZ` - Your timezone
- `TRANSMISSION_USER` and `TRANSMISSION_PASS` - Transmission login credentials

#### 3. Create Directories

```bash
mkdir -p config/{jellyfin,prowlarr,sonarr,jellyseerr,transmission}
mkdir -p media/{tv,movies}
mkdir -p downloads
mkdir -p cache/jellyfin
```

#### 4. Set Permissions

```bash
# Set directory owner (replace 1000:1000 with your PUID:PGID)
sudo chown -R 1000:1000 config media downloads cache
```

#### 5. Start Containers

```bash
docker-compose up -d
```

## Application Access

After startup, applications will be available at the following addresses:

- **Jellyfin**: http://localhost:8096
- **Prowlarr**: http://localhost:9696
- **Sonarr**: http://localhost:8989
- **Jellyseerr**: http://localhost:5055
- **Transmission**: http://localhost:9091

## Step-by-Step Configuration

### 1. Transmission (BitTorrent Client)

1. Open http://localhost:9091
2. Log in using credentials from `.env` file
3. Go to: Hamburger menu (☰) → Edit Preferences
4. In the 'Torrents' tab, set 'Download to:' to `/downloads` ⚠️ **Use container path, NOT host path!**
   - ❌ **Wrong:** `/opt/vitv/downloads` (host path)
   - ✅ **Correct:** `/downloads` (container path)
5. (Optional) Set 'Use temporary folder:' to `/downloads`
6. **Important:** Change password in Remote Access tab for security

### 2. Prowlarr (Indexer Manager)

1. Open http://localhost:9696
2. Go to Indexers → + Add
3. Add indexers (e.g. RARBG, 1337x, TorrentGalaxy)
4. Go to Settings → Apps
5. Add Sonarr as application:
   - Name: Sonarr
   - Prowlarr Server: `http://prowlarr:9696` ⚠️ **Use container name, not localhost!**
   - Sonarr Server: `http://sonarr:8989` ⚠️ **Use container name, not localhost!**
   - API Key: (found in Sonarr → Settings → General → Security)

> 💡 **Important**: For inter-container communication, use container names (`sonarr`, `prowlarr`) instead of `localhost`. The `localhost` addresses are only for accessing services from your browser.

### 3. Sonarr (TV Series Manager)

1. Open http://localhost:8989
2. Go to Settings → Media Management
3. Set directories:
   - Root Folders: `/tv` ⚠️ **Use container path, not host path!**
     (This is mapped from `/opt/vitv/media/tv` on the host)
   - Completed Download Handling: `/downloads` ⚠️ **Use container path!**
     (This is mapped from `/opt/vitv/downloads` on the host)
4. Go to Settings → Download Clients
5. Add Transmission:
   - Host: `transmission` ⚠️ **Use container name, not localhost!**
   - Port: `9091`
   - Username/Password: (from `.env` file)
   - Category: `tv`
   - Click 'Test' to verify connection, then Save
6. **CRITICAL: Add Remote Path Mapping (fixes Docker path warning):**
   - Go to: Settings → Download Clients → **Remote Path Mappings** tab (next to Download Clients)
   - Click '+ Add'
   - **Host:** `transmission` ⚠️ **Must match exactly the Host field above!**
   - **Remote Path:** `/downloads/tv` (path Transmission reports - where files are saved with category 'tv')
   - **Local Path:** `/downloads` (path Sonarr sees - where Sonarr should look for files)
   - Click 'Test' if available, then Save
   - The health warning should disappear after saving
7. Go to Settings → Indexers
8. Add Prowlarr:
   - URL: `http://prowlarr:9696` ⚠️ **Use container name, not localhost!**
   - API Key: (found in Prowlarr → Settings → General)

### 4. Jellyfin (Media Server)

1. Open http://localhost:8096
2. Complete first-time setup (language settings, admin user)
3. Go to Dashboard → Libraries
4. Add libraries:
   - Movies: `/media/movies` ⚠️ **Use container path!**
     (This is mapped from `/opt/vitv/media/movies` on the host)
   - TV Shows: `/media/tv` ⚠️ **Use container path!**
     (This is mapped from `/opt/vitv/media/tv` on the host)
5. Start library scan

### 5. Jellyseerr (Request System)

1. Open http://localhost:5055
2. Complete first-time setup
3. Go to Settings → Services
4. Add Jellyfin:
   - URL: `http://jellyfin:8096` ⚠️ **Use container name, not localhost!**
   - API Key: (found in Jellyfin → Dashboard → API Keys)
5. Add Sonarr:
   - URL: `http://sonarr:8989` ⚠️ **Use container name, not localhost!**
   - API Key: (found in Sonarr → Settings → General → Security)
6. Go to Settings → Users and add users

## Directory Structure

```
ViTV/
├── config/              # Application configurations
│   ├── jellyfin/
│   ├── prowlarr/
│   ├── sonarr/
│   ├── jellyseerr/
│   └── transmission/
├── media/               # Ready media
│   ├── tv/             # TV Series
│   └── movies/         # Movies
├── downloads/           # Downloaded files
│   └── watch/          # Directory watched by Transmission
├── cache/              # Application cache
│   └── jellyfin/
├── docker-compose.yml
├── .env
└── README.md
```

## Management

### Using Management Script (if install.sh was used)

```bash
# If symbolic link was created:
vitv start      # Start all services
vitv stop       # Stop all services
vitv restart    # Restart all services
vitv status     # Show services status
vitv logs       # Show logs for all services
vitv logs sonarr # Show logs for specific service
vitv update     # Update and restart services
vitv rebuild    # Stop, rebuild and start services
```

> **Note:** If `vitv restart` opens a text editor instead of restarting services, the script may have incorrect line endings or permissions. Fix with:
> ```bash
> # Fix line endings and permissions
> sudo sed -i 's/\r$//' /usr/local/bin/vitv
> sudo chmod +x /usr/local/bin/vitv
> # Or recreate the symlink:
> sudo rm /usr/local/bin/vitv
> sudo ln -sf /opt/vitv/vitv.sh /usr/local/bin/vitv
> sudo chmod +x /usr/local/bin/vitv
> ```

### Direct docker-compose Usage

```bash
cd /opt/vitv  # or other installation path

# Stop all containers
docker-compose down

# Stop with volume removal (WARNING: removes configuration!)
docker-compose down -v

# Restart specific service
docker-compose restart sonarr

# Display logs
docker-compose logs -f
# or for specific service:
docker-compose logs -f sonarr

# Update images
docker-compose pull
docker-compose up -d
```

## Troubleshooting

### Python "distutils" Module Error

**Error Message:** `"no module named 'distutils'"` or `"ModuleNotFoundError: No module named 'distutils'"`

**Root Cause:** This error occurs on systems with Python 3.12+ where the `distutils` module was removed. Older versions of `docker-compose` (standalone) use Python and may require `distutils`.

**Solution:**

1. **Install distutils (Python 3.12+):**
   ```bash
   # Ubuntu/Debian
   sudo apt-get update
   sudo apt-get install python3-distutils-extra
   
   # Or install setuptools which includes distutils
   sudo apt-get install python3-setuptools
   ```

2. **Alternative: Use Docker Compose Plugin (Recommended):**
   ```bash
   # Remove old docker-compose
   sudo apt-get remove docker-compose
   
   # Install Docker Compose plugin (doesn't require Python)
   sudo apt-get update
   sudo apt-get install docker-compose-plugin
   
   # Use 'docker compose' (with space) instead of 'docker-compose'
   docker compose version
   ```

3. **Verify Installation:**
   ```bash
   # For standalone docker-compose
   docker-compose --version
   
   # For plugin version
   docker compose version
   ```

**Note:** The Docker Compose plugin (v2) is recommended as it doesn't require Python and is actively maintained by Docker.

### Permission Issues
If applications cannot write files, check permissions:
```bash
# Get PUID and PGID from .env file
cd /opt/vitv  # or your installation path
source .env

# Fix ownership
sudo chown -R $PUID:$PGID config media downloads cache

# Fix permissions - config directories need write access (especially for Jellyfin plugins)
sudo chmod -R 775 config
sudo chmod 775 downloads downloads/watch
```

### Jellyfin Permission Denied Error

**Error Message:** `"Access to the path '/jellyfin/jellyfin-web/index.html' is denied"` or `"Permission denied"` in Jellyfin logs when plugins try to inject scripts.

**Root Cause:** Jellyfin config directory (or subdirectories created by Jellyfin) has insufficient permissions for plugins to write files. This affects plugins like JavaScriptInjector, JellyTweaks, and JellyfinEnhanced.

**Solution:**

1. **Fix Jellyfin Config Permissions (CRITICAL):**
   ```bash
   # Get PUID and PGID from .env file
   cd /opt/vitv  # or your installation path
   source .env
   
   # Fix Jellyfin config directory permissions recursively
   sudo chown -R $PUID:$PGID config/jellyfin
   sudo chmod -R 775 config/jellyfin
   
   # Also ensure cache directory has proper permissions
   sudo chown -R $PUID:$PGID cache/jellyfin
   sudo chmod -R 775 cache/jellyfin
   ```

2. **Restart Jellyfin:**
   ```bash
   docker compose restart jellyfin
   # or
   vitv restart jellyfin
   ```

3. **Verify Fix:**
   - Check Jellyfin logs: `docker compose logs jellyfin | grep -i "permission\|denied"`
   - The errors should disappear after restart
   - Plugins should successfully inject scripts into `index.html`

**Note:** Jellyfin plugins need **recursive write access** (`775`) to the entire config directory, including subdirectories like `/jellyfin/jellyfin-web/` that are created by Jellyfin itself. The `-R` flag is essential to fix permissions on existing subdirectories.

**If the issue persists:**
- Check that the user running Jellyfin (from `.env` PUID/PGID) matches the directory owner
- Verify with: `ls -la config/jellyfin/` - should show `drwxrwxr-x` (775) permissions
- Check subdirectories: `ls -la config/jellyfin/jellyfin-web/` - should also have 775 permissions

### Jellyfin Media Folders Inaccessible Error

**Error Message:** `"folder /media/movies is inaccessible or empty"` or `"folder /config/data/playlists is inaccessible or empty"` in Jellyfin logs.

**Root Cause:** Jellyfin cannot access media directories or write to playlists directory due to insufficient permissions. Media directories need read access, and config directories need write access.

**Solution:**

1. **Fix Media Directory Permissions:**
   ```bash
   # Get PUID and PGID from .env file
   cd /opt/vitv  # or your installation path
   source .env
   
   # Fix media directories permissions
   sudo chown -R $PUID:$PGID media
   sudo chmod -R 775 media
   sudo chmod 775 media/tv media/movies
   ```

2. **Fix Jellyfin Config and Cache Permissions:**
   ```bash
   # Fix Jellyfin config directory (including playlists)
   sudo chown -R $PUID:$PGID config/jellyfin
   sudo chmod -R 775 config/jellyfin
   
   # Fix cache directory
   sudo chown -R $PUID:$PGID cache/jellyfin
   sudo chmod -R 775 cache/jellyfin
   ```

3. **Restart Jellyfin:**
   ```bash
   docker compose restart jellyfin
   # or
   vitv restart jellyfin
   ```

4. **Verify Fix:**
   - Check Jellyfin logs: `docker compose logs jellyfin | grep -i "inaccessible\|empty"`
   - The errors should disappear after restart
   - Jellyfin should be able to scan and play media files

**Note:** Jellyfin needs:
- **Read access** (775) to media directories (`/media/movies`, `/media/tv`)
- **Write access** (775) to config directory for playlists and metadata
- **Write access** (775) to cache directory for transcoding

### Transmission Permission Denied Error

**Error Message:** `"Couldn't get '/opt/vitv/downloads/...': Permission denied (13)"`

**Root Cause:** Transmission is configured with the **host path** (`/opt/vitv/downloads`) instead of the **container path** (`/downloads`).

**Solution:**

1. **Fix Transmission Configuration (CRITICAL):**
   - Open Transmission: http://localhost:9091
   - Menu (☰) → Edit Preferences → Torrents tab
   - Check "Download to:" field
   - ❌ **If it shows:** `/opt/vitv/downloads` (WRONG - host path)
   - ✅ **Change it to:** `/downloads` (CORRECT - container path)
   - Click "Save"
   - Restart Transmission: `docker compose restart transmission` or `vitv restart transmission`

2. **Fix Permissions (if still needed):**
   ```bash
   # Get PUID and PGID from .env file
   cd /opt/vitv  # or your installation path
   source .env
   
   # Fix permissions
   sudo chown -R $PUID:$PGID downloads
   sudo chmod 775 downloads
   sudo chmod 775 downloads/watch
   
   # Restart Transmission
   docker compose restart transmission
   # or
   vitv restart transmission
   ```

3. **Verify:**
   - Transmission should now be able to write to `/downloads` (container path)
   - Files will appear in `/opt/vitv/downloads` on the host (mapped volume)
   - No more "Permission denied" errors

**Important:** Always use container paths (`/downloads`, `/tv`, `/media/movies`) inside Docker containers, NOT host paths (`/opt/vitv/downloads`).

### Container Connection Issues
Make sure all containers use the same Docker network. All services are on the default Docker Compose network, which allows them to communicate via container names.

### "no configuration file provided: not found" Error
If you get this error when running `vitv rebuild` or other commands:
```bash
# Check if docker-compose.yml exists in installation directory
ls -l /opt/vitv/docker-compose.yml

# If missing, re-run installation or copy from repository
# The vitv.sh script should auto-detect the installation path,
# but if it doesn't, run commands from the installation directory:
cd /opt/vitv
./vitv.sh rebuild
```

### Sonarr Remote Path Mapping Warning
If Sonarr shows a warning about download client placing files in `/opt/vitv/downloads/tv` but directory doesn't exist in container:
1. Go to: Settings → Download Clients → Remote Path Mappings
2. Add mapping:
   - Host: `transmission`
   - Remote Path: `/downloads/tv`
   - Local Path: `/downloads`
3. Save and the warning should disappear

### Check Container Status
```bash
docker-compose ps
```

### Check Error Logs
```bash
docker-compose logs --tail=100 [service_name]
```

## Security

⚠️ **WARNING**: This solution is intended for local use. If you plan to expose it to the network:

1. Change default passwords in Transmission
2. Consider using a reverse proxy (e.g. Nginx) with SSL
3. Restrict port access via firewall
4. Use VPN for Transmission

## Updates

Applications will be automatically updated with each `docker-compose pull && docker-compose up -d`, as we use the `latest` tag. For production environments, consider using specific versions.

## Support

If you encounter problems, check:
- Container logs: `docker-compose logs`
- Individual application documentation
- Container status: `docker-compose ps`

## Sharing the Project

If you want to share this project with others, see [SHARING.md](SHARING.md) for detailed instructions.

## License

This project is released under the MIT license. See [LICENSE](LICENSE) for details.

