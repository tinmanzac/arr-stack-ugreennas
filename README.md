# Media Automation Stack for Ugreen NAS

A complete, production-ready Docker Compose stack for automated media management with VPN routing, SSL certificates, and remote access.

**Specifically designed and tested for Ugreen NAS DXP4800+** with comprehensive documentation covering deployment, configuration, troubleshooting, and production best practices.

> **Note**: Tested on Ugreen NAS DXP4800+. Should work on other Ugreen models and Docker-compatible NAS devices, but may require adjustments.

## Legal Notice

This project provides configuration files for **legal, open-source software** designed for managing personal media libraries. All included tools have legitimate purposes - see **[LEGAL.md](docs/LEGAL.md)** for details on intended use, user responsibilities, and disclaimer.

---

## Getting Started

**[Setup Guide](docs/SETUP.md)** - Complete step-by-step instructions for deployment.

<details>
<summary>Using Claude Code for guided setup (optional)</summary>

[Claude Code](https://claude.ai/claude-code) can walk you through deployment step-by-step, executing commands and troubleshooting as you go.

```bash
npm install -g @anthropic-ai/claude-code
cd arr-stack-ugreennas && claude
```

Ask Claude to help deploy the stack - it reads the [`.claude/instructions.md`](.claude/instructions.md) file automatically.

</details>

---

## Features

- **VPN-protected networking** via Gluetun + Surfshark for privacy
- **Auto-recovery** - VPN-dependent services automatically restart when VPN reconnects (via deunhealth)
- **Automated SSL/TLS** certificates via Traefik + Cloudflare
- **Media library management** with Sonarr, Radarr, Prowlarr, Bazarr
- **Media streaming** with Jellyfin (or Plex - see below)
- **Request management** with Jellyseerr (or Overseerr for Plex)
- **Remote access** via WireGuard VPN
- **Ad-blocking DNS** with Pi-hole
- **Service monitoring** with Uptime Kuma

## Services Included

| Service | Description | Local Port | Domain URL |
|---------|-------------|------------|------------|
| **Traefik** | Reverse proxy with automatic SSL | 8080 | traefik.yourdomain.com |
| **Gluetun** | VPN gateway for network privacy | - | Internal |
| **qBittorrent** | BitTorrent client (VueTorrent UI included) | 8085 | qbit.yourdomain.com |
| **Sonarr** | TV show library management | 8989 | sonarr.yourdomain.com |
| **Radarr** | Movie library management | 7878 | radarr.yourdomain.com |
| **Prowlarr** | Search aggregator | 9696 | prowlarr.yourdomain.com |
| **Bazarr** | Subtitle management | 6767 | bazarr.yourdomain.com |
| **Jellyfin** | Media streaming server | 8096 | jellyfin.yourdomain.com |
| **Jellyseerr** | Media request system | 5055 | jellyseerr.yourdomain.com |
| **Pi-hole** | DNS + Ad-blocking | 53, 80 | pihole.yourdomain.com |
| **WireGuard** | VPN server for remote access | 51820/udp | wg.yourdomain.com |
| **Uptime Kuma** | Service monitoring | 3001 | uptime.yourdomain.com |
| **FlareSolverr** | CAPTCHA solver | 8191 | Internal |
| **deunhealth** | Auto-restart on VPN recovery | - | Internal |

> **Prefer Plex?** See `docker-compose.plex-arr-stack.yml` for an untested Plex/Overseerr variant.

## Deployment Options

### Option A: With Domain (Full Features)

Buy a cheap domain (~$10/year) and get:
- **Remote access** from anywhere via Cloudflare Tunnel
- **SSL/HTTPS** with automatic certificates
- **Pretty URLs** like `jellyfin.yourdomain.com`
- **WireGuard VPN** for secure remote access to your home network

**Requirements:** Domain name, Cloudflare account (free), VPN subscription

> **Cloudflare:** This stack is configured for Cloudflare (DNS + Tunnel). Other DNS providers work but you'll need to modify `docker-compose.traefik.yml` and `traefik/traefik.yml`. See [Traefik ACME docs](https://doc.traefik.io/traefik/https/acme/).
>
> **VPN:** Configured for Surfshark but Gluetun supports 30+ providers (NordVPN, PIA, Mullvad, etc.). See [Gluetun providers](https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers).

### Option B: Local Network Only (No Domain)

Skip the domain and access services directly via IP:port. All services work out of the box:
- `http://NAS_IP:8096` → Jellyfin
- `http://NAS_IP:5055` → Jellyseerr
- `http://NAS_IP:8989` → Sonarr
- `http://NAS_IP:7878` → Radarr
- `http://NAS_IP:9696` → Prowlarr
- `http://NAS_IP:8085` → qBittorrent
- `http://NAS_IP:6767` → Bazarr
- `http://NAS_IP:3001` → Uptime Kuma
- `http://NAS_IP:53` → Pi-hole DNS

**What works:** All media automation, VPN-protected downloads, Pi-hole DNS, local streaming

**What you lose:** Remote access, HTTPS, subdomain routing, WireGuard remote VPN

**To deploy local-only:**
1. Skip `docker-compose.traefik.yml` and `docker-compose.cloudflared.yml`
2. Deploy: `docker compose -f docker-compose.arr-stack.yml up -d`
3. Access via `http://NAS_IP:PORT`


## Documentation Strategy

This project separates public documentation from private configuration:

| Type | Location | Git Tracked | Contains |
|------|----------|-------------|----------|
| **Public docs** | `docs/*.md`, `README.md` | ✅ Yes | Generic instructions with placeholders (`yourdomain.com`, `YOUR_NAS_IP`) |
| **Private config** | `.claude/config.local.md` | ❌ No (gitignored) | Actual hostnames, IPs, usernames for your deployment |
| **Credentials** | `.env` | ❌ No (gitignored) | Passwords, API tokens, private keys |

**Why?** This allows sharing the project publicly while keeping your specific configuration private. If using Claude Code, your `config.local.md` provides your environment details.

**Setup**: Copy `.claude/config.local.md.example` to `.claude/config.local.md` and fill in your values.

---

## Project Structure

```
arr-stack-ugreennas/          # Git repo (source of truth)
├── docker-compose.traefik.yml      # Traefik reverse proxy
├── docker-compose.arr-stack.yml    # Main media stack (Jellyfin)
├── docker-compose.plex-arr-stack.yml  # Plex variant (untested)
├── docker-compose.cloudflared.yml  # Cloudflare tunnel
├── traefik/                        # Traefik configuration
│   ├── traefik.yml                 # Static config
│   └── dynamic/
│       ├── tls.yml                 # TLS settings
│       ├── vpn-services.yml        # Service routing (Jellyfin)
│       └── vpn-services-plex.yml   # Service routing (Plex variant)
├── .env.example                    # Environment template
├── .env                            # Your configuration (gitignored)
├── docs/                           # Documentation
│   ├── SETUP.md                    # Complete setup guide
│   └── LEGAL.md                    # Legal notice
├── .claude/
│   ├── instructions.md             # AI assistant instructions (tracked)
│   ├── config.local.md.example     # Private config template (tracked)
│   └── config.local.md             # Your private config (gitignored)
└── README.md                       # This file
```

### NAS Deployment Structure

On the NAS, only operational files are deployed:

```
/volume1/docker/arr-stack/    # NAS deployment (operational files only)
├── docker-compose.*.yml      # Compose files
├── .env                      # Configuration
├── traefik/                  # Traefik configs
└── [app-data]/               # Service data directories
```

**Note**: Documentation and config templates stay in git repo only - not deployed to NAS.

## Architecture

### Network Topology

```
Internet → Router Port Forward (80→8080, 443→8443)
                            │
                            ▼
           Traefik (listening on 8080/8443 on NAS)
                            │
                            ├─► Jellyfin, Jellyseerr, Bazarr (Direct)
                            │
                            └─► Gluetun (VPN Gateway)
                                    │
                                    └─► qBittorrent, Sonarr, Radarr, Prowlarr
                                        (Privacy-protected services)

Note: Ugreen NAS nginx uses 80/443, so Traefik uses 8080/8443.
Router port forwarding maps external 80→8080, 443→8443.
```

### Three-File Architecture

This project uses **three separate Docker Compose files** (not one):

- **`docker-compose.traefik.yml`** - Infrastructure layer (reverse proxy, SSL, networking)
- **`docker-compose.arr-stack.yml`** - Application layer (media services)
- **`docker-compose.cloudflared.yml`** - Tunnel layer (external access via Cloudflare)

**Why?** This separation provides:
- Independent lifecycle management (update services without affecting Traefik)
- Scalability (one Traefik can serve multiple stacks)
- Clean architecture (infrastructure vs. application vs. tunnel concerns)
- Easier troubleshooting (isolated logs and configs)

**Deployment order matters**: Deploy Traefik first (creates network), then cloudflared, then arr-stack.

### Storage Structure

```
/volume1/
├── Media/
│   ├── downloads/          # qBittorrent downloads
│   ├── tv/                 # TV shows
│   └── movies/             # Movies
│
└── docker/
    └── arr-stack/          # Application configs
        ├── gluetun-config/
        ├── traefik/
        ├── uptime-kuma/
        └── ...
```

## Configuration

### Required Environment Variables

Edit `.env` with your values:

```bash
# Domain
DOMAIN=yourdomain.com

# Cloudflare
CF_DNS_API_TOKEN=your_cloudflare_api_token

# Surfshark VPN
SURFSHARK_USER=your_username
SURFSHARK_PASSWORD=your_password

# Passwords
PIHOLE_UI_PASS=your_pihole_password
WG_PASSWORD_HASH=bcrypt_hash_here
TRAEFIK_DASHBOARD_AUTH=htpasswd_hash_here
```

See [`.env.example`](.env.example) for complete configuration.


## Updating

```bash
# Pull latest images
docker compose -f docker-compose.arr-stack.yml pull

# Recreate containers
docker compose -f docker-compose.arr-stack.yml up -d
```

## Backup

Important volumes to backup:
- All `*-config` Docker volumes
- `/volume1/docker/arr-stack/` directory
- `/volume1/Media/` directory (optional, can be large)

```bash
# Example: Backup Sonarr config
docker run --rm \
  -v sonarr-config:/data \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/sonarr-config-$(date +%Y%m%d).tar.gz -C /data .
```

## Troubleshooting

Having issues? Check the [Troubleshooting section](docs/SETUP.md#troubleshooting) in the Setup Guide.

Common issues:
- VPN not connecting → Check VPN credentials in `.env`
- SSL certificates not working → Verify Cloudflare API token permissions
- Services not accessible → Check Cloudflare Tunnel status, verify Traefik is running
- VPN services unreachable → Check `docker logs gluetun` for connection status

## Security Considerations

- All services use HTTPS with automatic SSL certificates
- Network traffic routed through VPN for privacy
- Pi-hole provides DNS-level ad-blocking
- WireGuard enables secure remote access

### IMPORTANT: Configure Authentication

**Many services default to NO authentication!** After deployment, you MUST enable authentication on:

| Service | Default Auth | Action Required |
|---------|--------------|-----------------|
| Bazarr | Disabled (exposes API key!) | Enable Forms auth, regenerate API key |
| Sonarr/Radarr/Prowlarr | Disabled for Local Addresses | Set to Forms + Enabled |
| qBittorrent | Bypass localhost | Disable bypass, change default password |
| Uptime Kuma | None | Create admin account (forced on first access) |

**Why this matters with Cloudflare Tunnel**: Traffic through the tunnel appears to come from localhost, bypassing "Disabled for Local Addresses" authentication!

See the [Security section](docs/SETUP.md#59-security-enable-authentication) in the Setup Guide for detailed instructions.

## Customization

### Using a Different VPN Provider

Edit `docker-compose.arr-stack.yml`:

```yaml
gluetun:
  environment:
    - VPN_SERVICE_PROVIDER=nordvpn  # or protonvpn, etc.
```

See [Gluetun providers](https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers) for full list.

### Adding Services

1. Add service to `docker-compose.arr-stack.yml`
2. Add Traefik labels for reverse proxy
3. Add DNS record in Cloudflare
4. Deploy: `docker compose -f docker-compose.arr-stack.yml up -d`

## Support & Resources

- **Setup Guide**: [docs/SETUP.md](docs/SETUP.md)
- **Gluetun**: https://github.com/qdm12/gluetun
- **Traefik**: https://doc.traefik.io/
- **Servarr Wiki**: https://wiki.servarr.com/
- **LinuxServer.io**: https://docs.linuxserver.io/

## License

This project is provided as-is for personal use. Service-specific licenses apply to individual components.

## Acknowledgments

Originally forked from [TheRealCodeVoyage/arr-stack-setup-with-pihole](https://github.com/TheRealCodeVoyage/arr-stack-setup-with-pihole).

Thanks to [@benjamin-awd](https://github.com/benjamin-awd) for contributions via fork (VPN config improvements, healthcheck tuning).

Built with:
- [Traefik](https://traefik.io/) - Reverse proxy
- [Gluetun](https://github.com/qdm12/gluetun) - VPN gateway
- [LinuxServer.io](https://www.linuxserver.io/) - Container images
- [Servarr](https://wiki.servarr.com/) - Automation suite
- [Jellyfin](https://jellyfin.org/) - Media server

## References

Official documentation for included software:
- [Jellyfin Documentation](https://jellyfin.org/docs/) - Media server setup and configuration
- [Servarr Wiki](https://wiki.servarr.com/) - Sonarr, Radarr, Prowlarr guides
- [Traefik Documentation](https://doc.traefik.io/traefik/) - Reverse proxy configuration
- [Gluetun Wiki](https://github.com/qdm12/gluetun-wiki) - VPN container setup

**This project provides**:
- Ugreen NAS DXP4800+-specific configuration and testing
- Cloudflare Tunnel support for CGNAT bypass
- Comprehensive documentation for production deployment
- Troubleshooting guides based on real-world deployment
- Security best practices and sanitized configuration examples

---

**Need help?** Start with the [Setup Guide](docs/SETUP.md).
