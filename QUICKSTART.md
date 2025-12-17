# Quick Start - ViTV

## Fastest Installation (3 Steps)

### 1. Run Installation Script

```bash
sudo ./install.sh
```

The script will ask you for:
- Username (Enter = `vitv`)
- Installation path (Enter = `/opt/vitv`)
- Timezone (Enter = `Europe/Warsaw`)
- Transmission login credentials

### 2. Switch to User and Start

```bash
sudo su - vitv
cd /opt/vitv
vitv start
```

### 3. Open Applications

- **Jellyfin**: http://localhost:8096
- **Prowlarr**: http://localhost:9696
- **Sonarr**: http://localhost:8989
- **Jellyseerr**: http://localhost:5055
- **Transmission**: http://localhost:9091

## Basic Commands

```bash
vitv start      # Start
vitv stop       # Stop
vitv restart    # Restart
vitv status     # Status
vitv logs       # Logs
vitv update     # Update
```

## What's Next?

1. **Change Transmission password** - log in and change in settings
2. **Configure applications** - see [README.md](README.md) section "Step-by-Step Configuration"
3. **Add indexers** - in Prowlarr add torrent sources
4. **Connect applications** - configure integrations between applications

## More Information

- Detailed installation: [INSTALL.md](INSTALL.md)
- Full documentation: [README.md](README.md)
