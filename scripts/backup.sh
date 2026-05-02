#!/bin/bash
# Nightly backup: dump all databases, then sync everything to an encrypted
# Google Drive remote via rclone. Runs automatically via launchd on macOS
# (see com.homelab.backup.plist) or via cron on Linux.
#
# For a simpler local/NAS backup, see the rsync one-liner at the bottom of
# docs/backup.md.

set -uo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
BASE=/opt/homelab
SECRETS_DIR="$BASE/secrets"
BACKUP_DIR="$BASE/backup"
DUMP_DIR="$BACKUP_DIR/$(date +%Y-%m-%d_%H-%M-%S)"
LOG_FILE="$BACKUP_DIR/backup.log"
RCLONE_REMOTE="gdrive-crypt"                        # rclone remote name — run: rclone config
RCLONE_FILES_DEST="$RCLONE_REMOTE:files"
RCLONE_DUMPS_DEST="$RCLONE_REMOTE:db-dumps/$(date +%Y-%m-%d)"
LOCAL_DUMP_RETENTION_DAYS=7
REMOTE_DUMP_RETENTION_DAYS=30

# ── Logging ───────────────────────────────────────────────────────────────────
log()       { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"         | tee -a "$LOG_FILE"; }
log_error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*"  | tee -a "$LOG_FILE" >&2; }

ERRORS=0
fail() { log_error "$*"; ERRORS=$((ERRORS + 1)); }

# ── Preflight ─────────────────────────────────────────────────────────────────
log "====== Backup started ======"
mkdir -p "$DUMP_DIR"

if ! command -v rclone &>/dev/null; then
  log_error "rclone not found. Install with: brew install rclone  (or: apt install rclone)"
  exit 1
fi

if ! rclone listremotes | grep -q "^${RCLONE_REMOTE}:"; then
  log_error "rclone remote '${RCLONE_REMOTE}' not configured. Run: rclone config"
  exit 1
fi

# ── Copy rclone config into backup scope ─────────────────────────────────────
# rclone.conf lives outside BASE but contains the crypt keys — include it.
mkdir -p "$BASE/rclone"
cp "$HOME/.config/rclone/rclone.conf" "$BASE/rclone/rclone.conf" 2>>"$LOG_FILE" || \
  log_error "Could not copy rclone.conf — save it to your password manager manually"

# ── Database dumps ────────────────────────────────────────────────────────────

# Nextcloud — MariaDB
log "Dumping Nextcloud (MariaDB)..."
MARIADB_PASS=$(cat "$SECRETS_DIR/mariadb_password")
if docker exec nextcloud-db mysqldump \
    -u nextcloud -p"${MARIADB_PASS}" \
    --single-transaction --quick --skip-lock-tables \
    nextcloud 2>>"$LOG_FILE" | gzip > "$DUMP_DIR/nextcloud-db.sql.gz"; then
  log "  Nextcloud DB dump OK ($(du -sh "$DUMP_DIR/nextcloud-db.sql.gz" | cut -f1))"
else
  fail "Nextcloud DB dump failed"
fi
unset MARIADB_PASS

# Vaultwarden — PostgreSQL
log "Dumping Vaultwarden (PostgreSQL)..."
if docker exec vaultwarden-db pg_dump -U vaultwarden vaultwarden \
    2>>"$LOG_FILE" | gzip > "$DUMP_DIR/vaultwarden-db.sql.gz"; then
  log "  Vaultwarden DB dump OK ($(du -sh "$DUMP_DIR/vaultwarden-db.sql.gz" | cut -f1))"
else
  fail "Vaultwarden DB dump failed"
fi

# LibreChat — MongoDB
log "Dumping LibreChat (MongoDB)..."
MONGO_URI=$(grep '^MONGO_URI=' "$BASE/services/librechat/config/librechat.env" | cut -d= -f2-)
if [ -z "$MONGO_URI" ]; then
  fail "Could not read MONGO_URI from librechat.env"
else
  if docker exec librechat-mongodb mongodump \
      --uri="$MONGO_URI" --archive \
      2>>"$LOG_FILE" | gzip > "$DUMP_DIR/librechat-mongodb.archive.gz"; then
    log "  LibreChat MongoDB dump OK ($(du -sh "$DUMP_DIR/librechat-mongodb.archive.gz" | cut -f1))"
  else
    fail "LibreChat MongoDB dump failed (non-fatal, continuing)"
    ERRORS=$((ERRORS - 1))   # demote: MongoDB is not critical
  fi
fi
unset MONGO_URI

# ── Upload DB dumps ───────────────────────────────────────────────────────────
log "Uploading DB dumps to $RCLONE_DUMPS_DEST..."
if rclone copy "$DUMP_DIR" "$RCLONE_DUMPS_DEST" \
    --log-file="$LOG_FILE" --log-level=INFO; then
  log "  DB dumps uploaded OK"
else
  fail "DB dump upload failed"
fi

# ── File sync ─────────────────────────────────────────────────────────────────
log "Syncing files to $RCLONE_FILES_DEST..."
if rclone sync "$BASE" "$RCLONE_FILES_DEST" \
    --log-file="$LOG_FILE" --log-level=INFO \
    --exclude "services/ollama/models/**" \
    --exclude "services/nextcloud/html/**" \
    --exclude "services/nextcloud/db/**" \
    --exclude "services/vaultwarden/db/**" \
    --exclude "services/librechat/db/**" \
    --exclude "backup/**" \
    --exclude ".DS_Store" \
    --transfers=4 \
    --checkers=8 \
    --fast-list; then
  log "  File sync OK"
else
  fail "File sync failed or had errors"
fi

# ── Remote dump retention ─────────────────────────────────────────────────────
log "Pruning remote dumps older than ${REMOTE_DUMP_RETENTION_DAYS} days..."
rclone delete "$RCLONE_REMOTE:db-dumps" \
    --min-age "${REMOTE_DUMP_RETENTION_DAYS}d" \
    --log-file="$LOG_FILE" --log-level=INFO || true

# ── Local dump retention ──────────────────────────────────────────────────────
log "Pruning local dumps older than ${LOCAL_DUMP_RETENTION_DAYS} days..."
find "$BACKUP_DIR" -maxdepth 1 -type d -name "????-??-??_*" \
    -mtime +"$LOCAL_DUMP_RETENTION_DAYS" -exec rm -rf {} + 2>>"$LOG_FILE" || true

# ── Done ──────────────────────────────────────────────────────────────────────
if [ "$ERRORS" -eq 0 ]; then
  log "====== Backup completed successfully ======"
  exit 0
else
  log_error "====== Backup completed with $ERRORS error(s) — check log above ======"
  exit 1
fi
