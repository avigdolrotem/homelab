# Backup

Two strategies are included — pick one or use both.

---

## Option A — Local / NAS backup with rsync

The simplest possible backup: rsync your config and secrets to an external drive or NAS. No extra tools required, and the result is a plain directory you can browse immediately.

```bash
rsync -av --delete \
  --exclude='services/nextcloud/html/' \
  --exclude='services/nextcloud/db/' \
  --exclude='services/vaultwarden/db/' \
  --exclude='services/librechat/db/' \
  --exclude='services/ollama/models/' \
  --exclude='backup/' \
  --exclude='.DS_Store' \
  /opt/homelab/ /Volumes/Backup/homelab/
```

What this does:
- `-a` — archive mode (preserves permissions, timestamps, symlinks)
- `--delete` — removes files from the destination that no longer exist at the source
- The `--exclude` lines skip large runtime data (database files, Nextcloud file store, Ollama model weights) that should be dumped properly instead of copied live

**Run it on a schedule (macOS):** add a cron entry or launchd agent.
```bash
# cron — every night at 02:00
0 2 * * * rsync -a --delete --exclude='services/*/db/' /opt/homelab/ /Volumes/Backup/homelab/
```

> rsync copies files — it does not dump databases. If you only do rsync, you will lose any data written to MariaDB/PostgreSQL/MongoDB since the last time the database files were cleanly flushed. Use rsync for configs + secrets; use proper DB dumps for your databases.

---

## Option B — Cloud backup with rclone (encrypted)

`scripts/backup.sh` handles the full nightly backup:

1. **DB dumps** — live `mysqldump` / `pg_dump` / `mongodump` from running containers, compressed with gzip, retained locally for 7 days
2. **File sync** — `rclone sync` to an encrypted Google Drive remote (`gdrive-crypt`), excluding runtime DB directories and model weights
3. **Remote retention** — remote DB dumps older than 30 days are pruned automatically

### Setup

**1. Install rclone**
```bash
brew install rclone        # macOS
# or
apt install rclone         # Debian/Ubuntu
```

**2. Configure an encrypted remote**
```bash
rclone config
# Create a new remote → name it "gdrive"   → type: Google Drive
# Create another remote → name it "gdrive-crypt" → type: crypt → remote: gdrive:homelab-backup
# Choose your encryption passphrase and save it somewhere safe (Vaultwarden)
```

**3. Test**
```bash
rclone ls gdrive-crypt:
```

**4. Run the backup once manually**
```bash
bash /opt/homelab/scripts/backup.sh
```

**5. Schedule it (macOS launchd)**
```bash
# Edit the plist to replace "yourusername" with your actual macOS username
cp /opt/homelab/scripts/com.homelab.backup.plist \
   ~/Library/LaunchAgents/com.homelab.backup.plist

launchctl load ~/Library/LaunchAgents/com.homelab.backup.plist
```

The job runs every night at 02:00. Logs go to `~/Library/Logs/homelab-backup.log`.

**5. Schedule it (Linux cron)**
```bash
0 2 * * * /bin/bash /opt/homelab/scripts/backup.sh >> /opt/homelab/backup/backup.log 2>&1
```

---

## Restore

```bash
# Pull from cloud and restart services
bash /opt/homelab/scripts/restore.sh

# Or restore from local backup only (no rclone pull)
bash /opt/homelab/scripts/restore.sh --local
```

The restore script re-syncs files and restarts services. Database imports are intentionally manual — the script prints the exact commands to run after services are healthy.

---

## What is and isn't backed up

| Included | Excluded |
|----------|----------|
| All compose files and configs | `services/nextcloud/db/` — MariaDB data files |
| All secrets | `services/nextcloud/html/` — Nextcloud's PHP runtime |
| DB dumps (gzipped SQL/archive) | `services/vaultwarden/db/` — PostgreSQL data files |
| rclone config (crypt keys) | `services/ollama/models/` — model weights (re-downloadable) |
| | `backup/` — the backup dir itself |

Database data files are excluded because copying them while the engine is running produces inconsistent backups. The dump step handles databases properly.
