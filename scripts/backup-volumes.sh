#!/bin/bash
#
# Backup essential Docker named volumes
#
# Usage:
#   ./scripts/backup-volumes.sh [OPTIONS] [BACKUP_DIR]
#
# Options:
#   --tar    Create a .tar.gz archive (easier to transfer off-NAS)
#
# Examples:
#   ./scripts/backup-volumes.sh                           # Backup to /tmp/arr-stack-backup-YYYYMMDD
#   ./scripts/backup-volumes.sh /path/to/backup           # Backup to custom directory
#   ./scripts/backup-volumes.sh --tar                     # Create tarball in /tmp
#   ./scripts/backup-volumes.sh --tar /path/to/backup     # Create tarball in custom directory
#
# To pull backup to local machine:
#   scp user@nas:/tmp/arr-stack-backup-YYYYMMDD.tar.gz ./backups/
#

set -e

# Parse arguments
CREATE_TAR=false
BACKUP_DIR=""

for arg in "$@"; do
  case $arg in
    --tar)
      CREATE_TAR=true
      ;;
    *)
      BACKUP_DIR="$arg"
      ;;
  esac
done

# Default to /tmp (writable by all users)
# Note: /tmp isn't accessible via SCP on Ugreen NAS - use --tar then copy manually
BACKUP_DIR="${BACKUP_DIR:-/tmp/arr-stack-backup-$(date +%Y%m%d)}"
mkdir -p "$BACKUP_DIR"

# Get current user for ownership fix
CURRENT_UID=$(id -u)
CURRENT_GID=$(id -g)

# Essential volumes only (small, hard to recreate)
# Excludes large volumes that can regenerate by re-scanning libraries
VOLUMES=(
  arr-stack_gluetun-config          # VPN settings
  arr-stack_qbittorrent-config      # Client settings, categories
  arr-stack_jellyseerr-config       # User accounts, requests
  arr-stack_bazarr-config           # Subtitle provider settings
  arr-stack_prowlarr-config         # Indexer configs
  arr-stack_wireguard-easy-config   # VPN peer configs (critical!)
  arr-stack_uptime-kuma-data        # Monitor configs
  arr-stack_pihole-etc-dnsmasq      # DNS settings (small)
)

# Optional: uncomment to include larger volumes that can regenerate
# VOLUMES+=(arr-stack_jellyfin-config)    # 407MB - re-scan library to rebuild
# VOLUMES+=(arr-stack_sonarr-config)      # 43MB  - re-scan library to rebuild
# VOLUMES+=(arr-stack_radarr-config)      # 110MB - re-scan library to rebuild
# VOLUMES+=(arr-stack_pihole-etc-pihole)  # 138MB - blocklists re-download automatically

echo "Backing up to: $BACKUP_DIR"
echo ""

for vol in "${VOLUMES[@]}"; do
  if docker volume inspect "$vol" &>/dev/null; then
    DEST_NAME="${vol#arr-stack_}"
    echo "Backing up $vol..."
    # Copy files and fix ownership in one container run
    docker run --rm \
      -v "$vol":/source:ro \
      -v "$BACKUP_DIR":/backup \
      alpine sh -c "cp -a /source/. /backup/$DEST_NAME/ && chown -R $CURRENT_UID:$CURRENT_GID /backup/$DEST_NAME"
  else
    echo "Skipping $vol (not found)"
  fi
done

echo ""
echo "Backup complete: $BACKUP_DIR"
du -sh "$BACKUP_DIR"

# Create tarball if requested
if [ "$CREATE_TAR" = true ]; then
  TARBALL="${BACKUP_DIR}.tar.gz"
  echo ""
  echo "Creating tarball: $TARBALL"
  tar -czf "$TARBALL" -C "$(dirname "$BACKUP_DIR")" "$(basename "$BACKUP_DIR")"
  echo "Tarball created: $(ls -lh "$TARBALL" | awk '{print $5}')"
  echo ""
  echo "To pull to local machine:"
  echo "  scp user@nas:$TARBALL ./backups/"
fi

echo ""
echo "To restore a volume:"
echo "  docker run --rm -v /path/to/backup/VOLUME_NAME:/source:ro -v arr-stack_VOLUME_NAME:/dest alpine cp -a /source/. /dest/"
