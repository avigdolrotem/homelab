# Backup

`scripts/backup.sh` runs nightly and handles everything automatically:

1. **DB dumps** — live `mysqldump` / `pg_dump` / `mongodump` from running containers, compressed with gzip
2. **File sync** — `rclone sync` to an encrypted Google Drive remote, excluding runtime DB directories and model weights
3. **Retention** — DB dumps kept locally for 7 days, remotely for 30 days

---

## Setup

**1. Install rclone**
```bash
brew install rclone        # macOS
# or
apt install rclone         # Debian/Ubuntu
```

**2. Configure an encrypted Google Drive remote**
```bash
rclone config
```
- Create a remote named `gdrive` → type: `drive` → follow OAuth prompts
- Create a second remote named `gdrive-crypt` → type: `crypt` → remote: `gdrive:homelab-backup`
- Choose an encryption passphrase and store it somewhere safe (e.g. Vaultwarden)

The `gdrive-crypt` remote is what `backup.sh` writes to. Files on Google Drive are fully encrypted — Google cannot read them.

**3. Test the remote**
```bash
rclone ls gdrive-crypt:
```

**4. Run the backup manually once to verify**
```bash
bash /opt/homelab/scripts/backup.sh
tail -f /opt/homelab/backup/backup.log
```

**5a. Schedule it — macOS launchd (runs at 02:00 nightly)**
```bash
# Replace "yourusername" in the plist with your actual macOS username first
sed -i '' 's/yourusername/'"$USER"'/g' /opt/homelab/scripts/com.homelab.backup.plist

cp /opt/homelab/scripts/com.homelab.backup.plist \
   ~/Library/LaunchAgents/com.homelab.backup.plist

launchctl load ~/Library/LaunchAgents/com.homelab.backup.plist
```

Logs go to `~/Library/Logs/homelab-backup.log` and `homelab-backup-error.log`.

**5b. Schedule it — Linux cron**
```bash
0 2 * * * /bin/bash /opt/homelab/scripts/backup.sh >> /opt/homelab/backup/backup.log 2>&1
```

---

## Restore

```bash
# Pull latest backup from Google Drive and restart services
bash /opt/homelab/scripts/restore.sh

# Skip the rclone pull — restore from whatever is already in backup/
bash /opt/homelab/scripts/restore.sh --local
```

The restore script re-syncs files and restarts all services. Database imports are intentionally manual — the script prints the exact commands to run after services are healthy.

---

## What is and isn't backed up

| Included | Excluded |
|----------|----------|
| All compose files and configs | `services/nextcloud/db/` — MariaDB data files |
| All secrets | `services/nextcloud/html/` — Nextcloud's PHP runtime |
| DB dumps (gzipped SQL/archive) | `services/vaultwarden/db/` — PostgreSQL data files |
| rclone config (encryption keys) | `services/ollama/models/` — model weights (re-downloadable) |
| | `backup/` — the backup dir itself |

Database data files are excluded because copying them while the engine is running produces inconsistent backups. The dump step handles databases properly via each engine's native export tool.
