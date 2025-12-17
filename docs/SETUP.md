# Setup Guide

Complete setup guide for the media automation stack. Works on any Docker host with platform-specific notes in collapsible sections.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Step 1: Create Directory Structure](#step-1-create-directory-structure)
- [Step 2: Configure Environment](#step-2-configure-environment)
- [Step 3: External Access (Optional)](#step-3-external-access-optional)
- [Step 4: Deploy Services](#step-4-deploy-services)
- [Step 5: Configure Services](#step-5-configure-services)
- [Step 6: Verify](#step-6-verify)
- [Troubleshooting](#troubleshooting)
- [Quick Reference](#quick-reference)

---

## Prerequisites

### Hardware
- Docker host (NAS, server, Raspberry Pi 4+, etc.)
- Minimum 4GB RAM (8GB+ recommended)
- Storage for media files
- Support for `/dev/net/tun` (for VPN)

### Software
- Docker Engine 20.10+
- Docker Compose v2.0+
- SSH access to your host

### Required Services
- **VPN Subscription** - Any provider supported by [Gluetun](https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers) (Surfshark, NordVPN, PIA, Mullvad, ProtonVPN, etc.)

### Optional (for remote access)
- **Domain Name** (~$8-10/year)
- **Cloudflare Account** (free tier)

> **Local-only?** Skip domain and Cloudflare. Access services via `http://HOST_IP:PORT`.

---

## Step 1: Create Directory Structure

Create the required folders for media and configuration.

<details>
<summary><strong>Ugreen NAS (UGOS)</strong></summary>

**Important:** Folders created via SSH don't appear in UGOS Files app. Create top-level folders via GUI for visibility.

1. Open UGOS web interface → **Files** app
2. Create shared folders: **Media**, **docker**
3. Inside **Media**, create subfolders: **downloads**, **tv**, **movies**
4. Via SSH, create Docker config subdirectories:

```bash
ssh your-username@nas-ip
sudo mkdir -p /volume1/docker/arr-stack/{gluetun-config,jellyseerr/config,bazarr/config,traefik/dynamic,uptime-kuma}
sudo chown -R 1000:1000 /volume1/docker/arr-stack
sudo touch /volume1/docker/arr-stack/traefik/acme.json
sudo chmod 600 /volume1/docker/arr-stack/traefik/acme.json
```

**Note:** Use `sudo` for Docker commands on Ugreen NAS.

</details>

<details>
<summary><strong>Synology / QNAP</strong></summary>

Use File Station to create:
- **Media** shared folder with subfolders: downloads, tv, movies
- **docker** shared folder

Then via SSH:
```bash
ssh your-username@nas-ip
sudo mkdir -p /volume1/docker/arr-stack/{gluetun-config,jellyseerr/config,bazarr/config,traefik/dynamic,uptime-kuma}
sudo chown -R 1000:1000 /volume1/docker/arr-stack
sudo touch /volume1/docker/arr-stack/traefik/acme.json
sudo chmod 600 /volume1/docker/arr-stack/traefik/acme.json
```

</details>

<details>
<summary><strong>Linux Server / Generic</strong></summary>

```bash
# Create all directories
sudo mkdir -p /srv/docker/arr-stack/{gluetun-config,jellyseerr/config,bazarr/config,traefik/dynamic,uptime-kuma}
sudo mkdir -p /srv/media/{downloads,tv,movies}

# Set permissions
sudo chown -R 1000:1000 /srv/docker/arr-stack
sudo chown -R 1000:1000 /srv/media

# Create Traefik certificate file
sudo touch /srv/docker/arr-stack/traefik/acme.json
sudo chmod 600 /srv/docker/arr-stack/traefik/acme.json
```

**Note:** Adjust paths in docker-compose files if using different locations.

</details>

### Expected Structure

```
/volume1/  (or /srv/)
├── Media/
│   ├── downloads/    # qBittorrent downloads
│   ├── tv/           # TV shows (Sonarr → Jellyfin)
│   └── movies/       # Movies (Radarr → Jellyfin)
└── docker/
    └── arr-stack/
        ├── gluetun-config/
        ├── jellyseerr/config/
        ├── bazarr/config/
        ├── uptime-kuma/
        └── traefik/
            ├── traefik.yml
            ├── acme.json      # SSL certificates (chmod 600)
            └── dynamic/
                └── tls.yml
```

---

## Step 2: Configure Environment

### 2.1 Copy Template

```bash
cp .env.example .env
```

### 2.2 VPN Configuration (Required)

Gluetun supports 30+ VPN providers. Configuration varies by provider.

<details>
<summary><strong>Surfshark (WireGuard)</strong></summary>

1. Go to: https://my.surfshark.com/ → VPN → Manual Setup → Router → WireGuard
2. Select "I don't have a key pair" to generate new keys
3. **Select a server location** (e.g., "United Kingdom")
   - You MUST select a location before the Download button appears
4. Click **Download** to get the `.conf` file
5. Open the file and extract:
   ```ini
   [Interface]
   Address = 10.14.0.2/16          ← Copy this
   PrivateKey = uHSC4GWQ...        ← Copy this
   ```
6. Add to `.env`:
   ```bash
   VPN_SERVICE_PROVIDER=surfshark
   VPN_TYPE=wireguard
   WIREGUARD_PRIVATE_KEY=your_private_key_here
   WIREGUARD_ADDRESSES=10.14.0.2/16
   SERVER_COUNTRIES=United Kingdom
   ```

**Note:** You MUST download the config file - the Address field isn't shown on the web interface.

</details>

<details>
<summary><strong>Other Providers (NordVPN, PIA, Mullvad, etc.)</strong></summary>

See the Gluetun wiki for your provider:
- [NordVPN](https://github.com/qdm12/gluetun-wiki/blob/main/setup/providers/nordvpn.md)
- [Private Internet Access](https://github.com/qdm12/gluetun-wiki/blob/main/setup/providers/private-internet-access.md)
- [Mullvad](https://github.com/qdm12/gluetun-wiki/blob/main/setup/providers/mullvad.md)
- [ProtonVPN](https://github.com/qdm12/gluetun-wiki/blob/main/setup/providers/protonvpn.md)
- [All providers](https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers)

Update `.env` with your provider's required variables.

</details>

### 2.3 Service Passwords

**Pi-hole Password:**
```bash
# Generate random password or choose your own
openssl rand -base64 24
```
Add to `.env`: `PIHOLE_UI_PASS=your_password`

**WireGuard Password Hash** (for remote VPN access):
```bash
docker run --rm ghcr.io/wg-easy/wg-easy wgpw 'YOUR_PASSWORD'
```
Copy the `$2a$12$...` hash and add to `.env`:
```bash
WG_PASSWORD_HASH=$2a$12$your_generated_hash
```

**Traefik Dashboard Auth** (if using external access):
```bash
docker run --rm httpd:alpine htpasswd -nb admin 'your_password' | sed -e s/\\$/\\$\\$/g
```
Add to `.env`: `TRAEFIK_DASHBOARD_AUTH=admin:$$apr1$$...`

### 2.4 Save Your Passwords

| Service | Username | Password |
|---------|----------|----------|
| Pi-hole | (none) | Your Pi-hole password |
| WireGuard | (none) | Your WireGuard password (NOT the hash) |
| Traefik | admin | Your Traefik password |

**Important:** The `.env` file contains secrets - never commit it to git.

---

## Step 3: External Access (Optional)

<details>
<summary><strong>Skip this section if you only need local network access</strong></summary>

The stack works perfectly on your home network without any external setup. Use local URLs like `http://NAS_IP:8096` for Jellyfin.

If you want to access services from outside your home (phone on mobile data, travelling), continue with one of the options below.

### Option A: Cloudflare Tunnel (Recommended)

Cloudflare Tunnel connects outbound from your server, bypassing port forwarding and ISP restrictions.

1. **Create Tunnel:**
   - Go to https://one.dash.cloudflare.com/
   - Networks → Tunnels → Create a tunnel
   - Choose "Cloudflared" connector
   - Name your tunnel (e.g., "nas-tunnel")
   - Copy the tunnel token

2. **Add to .env:**
   ```bash
   TUNNEL_TOKEN=your_tunnel_token_here
   ```

3. **Configure Public Hostnames** in Cloudflare dashboard:
   | Subdomain | Service | URL |
   |-----------|---------|-----|
   | jellyfin | HTTP | jellyfin:8096 |
   | jellyseerr | HTTP | jellyseerr:5055 |
   | sonarr | HTTP | gluetun:8989 |
   | radarr | HTTP | gluetun:7878 |
   | (etc.) | | |

4. **Deploy** (see Step 4)

### Option B: Port Forwarding + DNS

Traditional approach - requires your ISP to allow incoming connections.

**1. Cloudflare API Token** (for SSL certificates):
- Go to: https://dash.cloudflare.com/profile/api-tokens
- Create Token → Use "Edit zone DNS" template
- Permissions: `Zone → DNS → Edit` AND `Zone → Zone → Read`
- Copy token and add to `.env`: `CF_DNS_API_TOKEN=your_token`

**2. DNS Records** in Cloudflare:
- Add A record: `@` → Your public IP
- Add CNAME: `*` → `@` (or your DDNS hostname)
- **Set Proxy Status to "DNS only" (gray cloud)** - this is critical!

**3. Router Port Forwarding:**

| External Port | Internal IP | Internal Port | Protocol |
|---------------|-------------|---------------|----------|
| 80 | NAS_IP | 8080 | TCP |
| 443 | NAS_IP | 8443 | TCP |
| 51820 | NAS_IP | 51820 | UDP |

<details>
<summary><strong>Ugreen NAS Note</strong></summary>

Ugreen NAS (nginx) uses ports 80/443 and auto-repairs its config. This stack uses Traefik on ports 8080/8443 instead. Configure router to forward external 80→8080 and 443→8443.

</details>

**4. Add Domain to .env:**
```bash
DOMAIN=yourdomain.com
```

</details>

---

## Step 4: Deploy Services

### 4.1 Create Docker Network

```bash
docker network create \
  --driver=bridge \
  --subnet=192.168.100.0/24 \
  --gateway=192.168.100.1 \
  traefik-proxy
```

### 4.2 Copy Configuration Files

```bash
# Copy to your server (adjust paths as needed)
scp traefik/traefik.yml user@host:/volume1/docker/arr-stack/traefik/
scp traefik/dynamic/tls.yml user@host:/volume1/docker/arr-stack/traefik/dynamic/
scp traefik/dynamic/vpn-services.yml user@host:/volume1/docker/arr-stack/traefik/dynamic/
```

### 4.3 Deploy (Order Matters)

**Local-only deployment:**
```bash
# Deploy media stack
docker compose -f docker-compose.arr-stack.yml up -d
```

**With external access (Traefik + Cloudflare Tunnel):**
```bash
# 1. Deploy Traefik first (creates network, handles SSL)
docker compose -f docker-compose.traefik.yml up -d

# 2. Deploy media stack
docker compose -f docker-compose.arr-stack.yml up -d

# 3. Deploy Cloudflare Tunnel (if using)
docker compose -f docker-compose.cloudflared.yml up -d
```

### 4.4 Verify Deployment

```bash
# Check all containers are running
docker ps

# Check VPN connection
docker logs gluetun | grep -i "connected"

# Verify VPN IP (should NOT be your home IP)
docker exec gluetun wget -qO- ifconfig.me
```

---

## Step 5: Configure Services

### 5.1 qBittorrent

1. **Access:** `http://HOST_IP:8085`
2. **Default Login:** `admin` / `adminadmin`
3. **Immediately change password:** Tools → Options → Web UI
4. **Create categories:** Right-click categories → Add
   - `sonarr` → Save path: `/downloads/sonarr`
   - `radarr` → Save path: `/downloads/radarr`

### 5.2 Prowlarr (Indexer Manager)

1. **Access:** `http://HOST_IP:9696`
2. **Add Indexers:** Settings → Indexers → Add Indexer
3. **Add FlareSolverr** (for protected sites):
   - Settings → Indexers → Add FlareSolverr
   - Host: `http://flaresolverr:8191`
   - Tag: `flaresolverr`
4. **Connect to Sonarr:**
   - Settings → Apps → Add → Sonarr
   - Sonarr Server: `http://sonarr:8989`
   - API Key: (from Sonarr → Settings → General → Security)
5. **Connect to Radarr:** Same process with `http://radarr:7878`
6. **Sync:** Settings → Apps → Sync App Indexers

### 5.3 Sonarr (TV Shows)

1. **Access:** `http://HOST_IP:8989`
2. **Add Root Folder:** Settings → Media Management → `/tv`
3. **Add Download Client:** Settings → Download Clients → qBittorrent
   - Host: `gluetun` (important - not localhost!)
   - Port: `8085`
   - Category: `sonarr`

### 5.4 Radarr (Movies)

1. **Access:** `http://HOST_IP:7878`
2. **Add Root Folder:** Settings → Media Management → `/movies`
3. **Add Download Client:** Settings → Download Clients → qBittorrent
   - Host: `gluetun`
   - Port: `8085`
   - Category: `radarr`

### 5.5 Jellyfin (Media Server)

1. **Access:** `http://HOST_IP:8096`
2. **Initial Setup:** Create admin account
3. **Add Libraries:**
   - Movies: Content type "Movies", Folder `/media/movies`
   - TV Shows: Content type "Shows", Folder `/media/tv`

### 5.6 Jellyseerr (Request Manager)

1. **Access:** `http://HOST_IP:5055`
2. **Sign in with Jellyfin:**
   - Jellyfin URL: `http://jellyfin:8096`
   - Enter Jellyfin credentials
3. **Configure Services:**
   - Settings → Services → Add Sonarr: `http://sonarr:8989`
   - Settings → Services → Add Radarr: `http://radarr:7878`

### 5.7 Bazarr (Subtitles)

1. **Access:** `http://HOST_IP:6767`
2. **Enable Authentication:** Settings → General → Security → Forms
3. **Connect to Sonarr:** Settings → Sonarr → `http://sonarr:8989`
4. **Connect to Radarr:** Settings → Radarr → `http://radarr:7878`
5. **Add Providers:** Settings → Providers (OpenSubtitles, etc.)

### 5.8 Pi-hole (DNS/Ad-blocking)

1. **Access:** `http://HOST_IP/admin`
2. **Login:** Use password from `PIHOLE_UI_PASS`
3. **Configure DNS:** Settings → DNS → Upstream: 1.1.1.1, 1.0.0.1

**Network-wide ad-blocking:** Set your router's DHCP DNS to your host IP.

### 5.9 Security: Enable Authentication

**Critical for external access:** Many services default to no authentication.

| Service | Location | Set To |
|---------|----------|--------|
| Sonarr/Radarr/Prowlarr | Settings → General → Security | Authentication: Forms, Required: Enabled |
| Bazarr | Settings → General → Security | Authentication: Forms |
| qBittorrent | Tools → Options → Web UI | Disable "Bypass for localhost" |

---

## Step 6: Verify

### VPN Test
```bash
# Should show VPN IP, not your home IP
docker exec gluetun wget -qO- ifconfig.me
docker exec qbittorrent wget -qO- ifconfig.me
```

### Service Integration Test
1. Sonarr/Radarr: Settings → Download Clients → Test
2. Add a TV show or movie → verify it appears in qBittorrent
3. After download completes → verify it moves to library
4. Jellyfin → verify media appears in library

### External Access Test (if configured)
- From phone on cellular data: `https://jellyfin.yourdomain.com`
- Check SSL certificate is valid (padlock icon)

---

## Troubleshooting

### VPN Connected But Services Have No Internet

**Symptoms:** Gluetun shows "Connected" but qBittorrent/Sonarr can't reach internet.

**Solutions:**
1. Check firewall subnets in gluetun config:
   ```yaml
   FIREWALL_OUTBOUND_SUBNETS=192.168.0.0/24,192.168.100.0/24,10.8.1.0/24
   ```
2. Restart gluetun: `docker compose restart gluetun`
3. Check DNS: Add `DOT=off` to gluetun environment if DNS issues persist

### Downloads Complete But Don't Move to Library

**Symptoms:** Download finishes in qBittorrent but Sonarr/Radarr doesn't import it.

**Solutions:**
1. Check category matches in qBittorrent and Sonarr/Radarr
2. Verify path mapping - download client host should be `gluetun` not `localhost`
3. Check permissions: `sudo chown -R 1000:1000 /path/to/downloads`
4. Check Sonarr/Radarr Activity tab for import errors

### Container Restart Loop

**Symptoms:** Container keeps restarting, `docker ps` shows "Restarting"

**Solutions:**
```bash
# Check logs for error
docker logs <container_name> --tail 100

# Common causes:
# - Missing environment variables in .env
# - Permission errors on volumes
# - Port conflicts
```

### SSL Certificates Not Generating (External Access)

**Symptoms:** Browser shows "certificate invalid" after Traefik deployment

**Solutions:**
1. Verify Cloudflare proxy is **disabled** (gray cloud, not orange)
2. Check API token permissions: Zone:DNS:Edit AND Zone:Zone:Read
3. Check acme.json permissions: `chmod 600 traefik/acme.json`
4. View Traefik logs: `docker logs traefik | grep -i certificate`

### Services Accessible Without Login (Security Issue)

**Symptoms:** Can access Bazarr/Sonarr/etc. without authentication

**Cause:** Default settings or "Disabled for Local Addresses" with Cloudflare Tunnel (tunnel traffic appears as localhost).

**Solution:** Set all services to "Authentication: Forms" and "Required: Enabled" (not "Disabled for Local Addresses").

---

## Quick Reference

### Local Access URLs

| Service | URL | Default Credentials |
|---------|-----|---------------------|
| Jellyfin | http://HOST_IP:8096 | (create during setup) |
| Jellyseerr | http://HOST_IP:5055 | (use Jellyfin login) |
| qBittorrent | http://HOST_IP:8085 | admin / adminadmin |
| Sonarr | http://HOST_IP:8989 | (none by default) |
| Radarr | http://HOST_IP:7878 | (none by default) |
| Prowlarr | http://HOST_IP:9696 | (none by default) |
| Bazarr | http://HOST_IP:6767 | (none by default) |
| Pi-hole | http://HOST_IP/admin | (from PIHOLE_UI_PASS) |
| Uptime Kuma | http://HOST_IP:3001 | (create during setup) |

### Docker Commands

```bash
# View all containers
docker ps

# View logs
docker logs -f <container_name>

# Restart service
docker compose -f docker-compose.arr-stack.yml restart <service_name>

# Update all services
docker compose -f docker-compose.arr-stack.yml pull
docker compose -f docker-compose.arr-stack.yml up -d

# Stop everything
docker compose -f docker-compose.arr-stack.yml down
```

### Network Information

| Network | Subnet | Purpose |
|---------|--------|---------|
| traefik-proxy | 192.168.100.0/24 | Service communication |
| vpn-net | 10.8.1.0/24 | Internal VPN routing |

### IP Allocation (traefik-proxy)

| IP | Service |
|----|---------|
| .1 | Gateway |
| .2 | Traefik |
| .3 | Gluetun |
| .4 | Jellyfin |
| .5 | Pi-hole |
| .6 | WireGuard |
| .8 | Jellyseerr |
| .9 | Bazarr |
| .10 | FlareSolverr |
| .12 | Cloudflared |
| .13 | Uptime Kuma |

---

## Next Steps

1. **Add content:** Search for TV shows in Sonarr, movies in Radarr
2. **Configure Uptime Kuma:** Add monitors for all services
3. **Set up backups:** Backup Docker volumes regularly
4. **Family access:** Create Jellyfin accounts, share Jellyseerr for requests

---

**Need help?** Check the [GitHub Issues](https://github.com/Pharkie/arr-stack-ugreennas/issues) or community resources:
- [Servarr Wiki](https://wiki.servarr.com/) (Sonarr/Radarr/Prowlarr)
- [Gluetun Wiki](https://github.com/qdm12/gluetun-wiki)
- [r/selfhosted](https://reddit.com/r/selfhosted)
