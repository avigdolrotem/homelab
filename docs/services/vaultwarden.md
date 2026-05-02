# Vaultwarden

**Role:** Optional. Self-hosted Bitwarden-compatible password manager.

Vaultwarden is not protected by Authentik — it has its own login. Use the official Bitwarden app (mobile/desktop/browser extension) pointed at your `https://passwords.yourdomain.com` instance.

---

## Components

| Container | Purpose |
|-----------|---------|
| `vaultwarden` | Application server |
| `vaultwarden-db` | PostgreSQL database |

---

## Security settings explained

The compose file includes several security-hardening settings worth understanding:

| Setting | Value | Reason |
|---------|-------|--------|
| `SIGNUPS_ALLOWED` | `false` | No open registration — invite only |
| `SIGNUPS_VERIFY` | `true` | Email verification required for invited users |
| `SIGNUPS_DOMAINS_WHITELIST` | `yourdomain.com` | Only addresses from your domain can register |
| `PASSWORD_ITERATIONS` | `1000000` | High PBKDF2 iteration count — slows brute force |
| `REQUIRE_DEVICE_EMAIL` | `true` | New device login requires email verification |
| `DISABLE_ICON_DOWNLOAD` | `true` | Prevents SSRF via favicon fetching |
| `DISABLE_2FA_REMEMBER` | `true` | Forces 2FA on every login (no "remember this device") |
| `SHOW_PASSWORD_HINT` | `false` | No password hints (security risk) |
| `LOGIN_RATELIMIT_SECONDS` | `60` | 1 login attempt per minute from same IP |
| `ADMIN_RATELIMIT_SECONDS` | `300` | 1 admin panel attempt per 5 minutes |

---

## Admin panel

The admin panel at `https://passwords.yourdomain.com/admin` is protected by `ADMIN_TOKEN`. Use it to:
- Invite new users
- View registered users
- Send test emails

The admin token is stored in `secrets/vaultwarden_admin_token`. Generate a secure one:
```bash
openssl rand -base64 48
```

---

## Why monitor-only for Watchtower?

Vaultwarden is a password manager — the most critical service in this stack. Updates are set to monitor-only so you can review the changelog before updating. A bad update to your password manager is worse than being one version behind.

---

## Connecting Bitwarden clients

In the Bitwarden app (any platform):
1. Tap the region selector (usually shows "bitwarden.com")
2. Select **Self-hosted**
3. Server URL: `https://passwords.yourdomain.com`
4. Log in with your Vaultwarden credentials
