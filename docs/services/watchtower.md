# Watchtower

**Role:** Optional. Automatic container image updates with email notifications.

Watchtower checks for new image versions and updates containers in-place, removing the old image after update.

---

## Schedule

Runs every **Sunday at 03:00** (server local time):
```
WATCHTOWER_SCHEDULE=0 0 3 * * 0
```
Cron format: `second minute hour day-of-month month day-of-week`

---

## Label-based selective updates

Not all containers should auto-update. Watchtower uses labels to decide:

```yaml
# Auto-update when new image available
- com.centurylinklabs.watchtower.enable=true

# Alert on new images but don't update
- com.centurylinklabs.watchtower.monitor-only=true
```

`WATCHTOWER_LABEL_ENABLE=true` means only labeled containers are considered. Unlabeled containers are ignored entirely.

### Update vs. monitor-only by service

| Service | Setting | Reason |
|---------|---------|--------|
| Traefik, cloudflared | `enable` | Safe to auto-update |
| Authentik server/worker | `monitor-only` | Occasional migration steps required |
| Nextcloud | `monitor-only` | Major upgrades need `occ upgrade` |
| Vaultwarden | `monitor-only` | Password manager — review before updating |
| MariaDB, PostgreSQL (Nextcloud) | `monitor-only` | Schema migrations |
| Ollama, LibreChat | `enable` | Generally safe |
| code-server, socket-proxy, etc. | `enable` | Safe |

---

## Email notifications

Watchtower sends a summary email after each run listing:
- Containers checked
- Images updated (or "no updates available")
- Any errors

It reuses the same SMTP credentials as Vaultwarden (`secrets/vaultwarden_smtp_password`).

---

## Checking Watchtower manually

To trigger an immediate check (useful for testing):
```bash
docker exec watchtower /watchtower --run-once
```
