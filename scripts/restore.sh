#!/bin/bash
# Restore from an encrypted Google Drive backup.
# Usage:
#   ./restore.sh            — pulls latest backup from Google Drive then restores
#   ./restore.sh --local    — skips rclone pull, restores from local backup/ dir

set -euo pipefail

BASE=/opt/homelab
BACKUP_DIR="$BASE/backup"
RCLONE_REMOTE="gdrive-crypt"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

LOCAL_ONLY=false
if [[ "${1:-}" == "--local" ]]; then LOCAL_ONLY=true; fi

# ── Pull files from remote ────────────────────────────────────────────────────
if [ "$LOCAL_ONLY" = false ]; then
  log "Pulling files from $RCLONE_REMOTE:files ..."
  rclone sync "$RCLONE_REMOTE:files" "$BASE" \
      --exclude "backup/**" \
      --log-level=INFO

  log "Pulling latest DB dumps..."
  LATEST_DUMP=$(rclone lsd "$RCLONE_REMOTE:db-dumps" | sort | tail -1 | awk '{print $NF}')
  if [ -n "$LATEST_DUMP" ]; then
    log "  Latest dump set: $LATEST_DUMP"
    rclone copy "$RCLONE_REMOTE:db-dumps/$LATEST_DUMP" "$BACKUP_DIR/restore-$LATEST_DUMP"
    log "  Downloaded to $BACKUP_DIR/restore-$LATEST_DUMP"
  else
    log "  No remote dumps found."
  fi
fi

# ── Stop all services ─────────────────────────────────────────────────────────
log "Stopping all services..."
bash "$BASE/scripts/stop.sh"

# ── Restart services ──────────────────────────────────────────────────────────
log "Starting services..."
bash "$BASE/scripts/start.sh"

log "Services restarted."

# ── DB import reminder ────────────────────────────────────────────────────────
cat <<'EOF'

════════════════════════════════════════════════════════════════
  DB dumps are NOT auto-imported. Run these after services are up:

  DUMP_DIR="/opt/homelab/backup/restore-<DATE>"
  SECRETS="/opt/homelab/secrets"

  # Nextcloud (MariaDB)
  MARIADB_PASS=$(cat "$SECRETS/mariadb_password")
  zcat "$DUMP_DIR/nextcloud-db.sql.gz" | \
    docker exec -i nextcloud-db mysql -u nextcloud -p"$MARIADB_PASS" nextcloud

  # Vaultwarden (PostgreSQL)
  zcat "$DUMP_DIR/vaultwarden-db.sql.gz" | \
    docker exec -i vaultwarden-db psql -U vaultwarden vaultwarden

  # LibreChat (MongoDB)
  MONGO_URI=$(grep '^MONGO_URI=' /opt/homelab/services/librechat/config/librechat.env | cut -d= -f2-)
  zcat "$DUMP_DIR/librechat-mongodb.archive.gz" | \
    docker exec -i librechat-mongodb mongorestore --uri="$MONGO_URI" --archive

  # Re-enable Nextcloud after import
  docker exec -u www-data nextcloud php occ maintenance:mode --off
════════════════════════════════════════════════════════════════

EOF
