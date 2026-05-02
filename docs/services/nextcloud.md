# Nextcloud

**Role:** Optional. Self-hosted cloud storage, contacts, and calendar.

Nextcloud is not protected by Authentik in this stack — it has its own login system. You access it at `https://cloud.yourdomain.com` with a Nextcloud username/password.

---

## What it provides

- **Files** — web UI + desktop/mobile sync clients
- **Contacts** — CardDAV server, sync via DAVx⁵ (Android) or macOS/iOS Contacts
- **Calendar** — CalDAV server, sync via DAVx⁵ (Android) or macOS/iOS Calendar
- **Notes** — basic notes app (or use Joplin/Obsidian with Nextcloud as storage backend)

---

## Components

| Container | Purpose |
|-----------|---------|
| `nextcloud` | Application (PHP-FPM + Apache) |
| `nextcloud-db` | MariaDB database |

---

## CalDAV / CardDAV

The compose file includes Traefik redirect rules that handle `.well-known/carddav` and `.well-known/caldav` auto-discovery. Clients that query the standard RFC paths will be automatically redirected to Nextcloud's actual DAV endpoint at `/remote.php/dav`.

On Android, install **DAVx⁵** and connect to `https://cloud.yourdomain.com` with your Nextcloud credentials. Contacts and calendar sync immediately.

---

## Why monitor-only for Watchtower?

Nextcloud **major version upgrades** (e.g. 30 → 31 → 32) require running maintenance steps:

```bash
docker exec -u www-data nextcloud php occ upgrade
docker exec -u www-data nextcloud php occ maintenance:mode --off
```

Skipping these and just pulling the new image can corrupt the database. Watchtower will notify you of new images but won't update automatically.

**Minor updates** (32.x → 32.y) are safe to auto-update, but this setup uses monitor-only for the entire service to be safe.

---

## First run

On first startup, Nextcloud will perform its initial installation. This can take 2–3 minutes. Visit `https://cloud.yourdomain.com` — if you see a setup screen, fill in:
- Admin username/password
- Data folder: `/var/www/html/data` (already set via volume)
- Database: MySQL/MariaDB, credentials from your `mariadb_password` secret, host `nextcloud-db`

After setup, install recommended apps via Admin → Apps.

---

## Trusted domains

If you see "Access through untrusted domain" errors, add your domain:

```bash
docker exec -u www-data nextcloud php occ config:system:set trusted_domains 1 --value=cloud.yourdomain.com
```
