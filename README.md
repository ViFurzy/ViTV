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
git clone https://github.com/TWOJA_NAZWA/ViTV.git
cd ViTV

# Run installation
sudo ./install.sh
```

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

```bash
# Download or clone project
cd /path/to/project

# Run installation script as root
sudo ./install.sh
```

The script will ask you for:
- Username (default: `vitv`)
- Installation path (default: `/opt/vitv`)
- Timezone (default: `Europe/Warsaw`)
- Transmission login credentials
- **Do you want to start Docker containers now?** (y/n)
- **Do you want to display step-by-step configuration instructions?** (y/n) - if containers were started

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
4. In the 'Torrents' tab, set 'Download to:' to `/opt/vitv/downloads`
5. (Optional) Set 'Use temporary folder:' to `/opt/vitv/downloads`

### 2. Prowlarr (Indexer Manager)

1. Open http://localhost:9696
2. Go to Settings → Indexers
3. Add indexers (e.g. RARBG, 1337x)
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
6. **IMPORTANT: Add Remote Path Mapping:**
   - Go to: Settings → Download Clients → Remote Path Mappings tab
   - Click '+ Add'
   - Host: `transmission`
   - Remote Path: `/downloads/tv` (where Transmission saves with category 'tv')
   - Local Path: `/downloads` (where Sonarr expects files)
   - Save
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

### Permission Issues
If applications cannot write files, check permissions:
```bash
sudo chown -R $PUID:$PGID config media downloads cache
# Downloads directory needs write access
sudo chmod 775 downloads downloads/watch
```

### Transmission Permission Denied Error
If Transmission shows "Permission denied" when downloading:
```bash
# Fix permissions for downloads directory
sudo chown -R $PUID:$PGID /opt/vitv/downloads
sudo chmod 775 /opt/vitv/downloads
sudo chmod 775 /opt/vitv/downloads/watch

# Restart Transmission
docker compose restart transmission
# or
vitv restart transmission
```

### Container Connection Issues
Make sure all containers use the same Docker network. All services are on the default Docker Compose network, which allows them to communicate via container names.

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

