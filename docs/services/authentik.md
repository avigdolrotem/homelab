# Authentik

**Role:** Core (if you want SSO). Required for: Traefik Dashboard, code-server, Tor Browser.

Authentik is a self-hosted Identity Provider (IdP). In this stack it does three things:
1. **SSO gate** — Traefik's `forwardAuth` middleware redirects unauthenticated requests to Authentik's login page
2. **Social login** — supports Google, GitHub, Microsoft, and more as secondary login methods
3. **MFA enforcement** — TOTP 2FA on all logins

---

## Components

| Container | Purpose |
|-----------|---------|
| `authentik-server` | Web UI + API + embedded outpost (proxy auth) |
| `authentik-worker` | Background tasks (email, flows, cleanup) |
| `authentik-db` | Dedicated PostgreSQL instance |
| `authentik-redis` | Session cache and task queue |

The **embedded outpost** handles `forwardAuth` requests from Traefik. No separate outpost container needed.

---

## ⚠️ Known bug: `__FILE` env vars (Authentik 2025.x)

**If you try to use `AUTHENTIK_POSTGRESQL__PASSWORD__FILE` in your environment, Authentik will crash with:**
```
TypeError: 'Attr' object does not support item assignment
```

**Root cause:** Authentik's config parser (`authentik/lib/config.py`) treats double-underscore as a nesting separator. `AUTHENTIK_POSTGRESQL__PASSWORD__FILE` is parsed as three levels: `postgresql → password → file` — treating `file` as a sub-key of `password`. When it tries to assign to an already-resolved leaf node (`Attr`), it fails.

**Workaround:** Use `env_file` pointing to `authentik.env` with actual secret values written inline:

```env
# authentik.env (chmod 600, gitignored)
AUTHENTIK_POSTGRESQL__PASSWORD=your_actual_password_value
AUTHENTIK_SECRET_KEY=your_actual_secret_key_value
```

This is different from how other services handle secrets — Authentik cannot use `__FILE` for nested keys. The Postgres container itself still accepts `POSTGRES_PASSWORD_FILE` fine (that's Postgres's own handling, not Authentik's parser).

---

## Initial setup

1. Start the stack and wait for all 4 containers to be healthy
2. Visit `https://auth.yourdomain.com/if/flow/initial-setup/`
3. Create your admin account
4. Keep these credentials somewhere safe — this is your master account

---

## Protecting a service with Authentik

### Step 1 — Create a Provider

Admin → Applications → Providers → Create → **Proxy Provider**
- Name: `yourservice`
- Authorization flow: `default-provider-authorization-implicit-consent`
- Forward auth (single application) → External host: `https://yourservice.yourdomain.com`

### Step 2 — Create an Application

Admin → Applications → Applications → Create
- Name: `yourservice`
- Slug: `yourservice`
- Provider: select the one you just created

### Step 3 — Wire the outpost

Admin → Applications → Outposts → `authentik Embedded Outpost` → Edit → Add `yourservice` to Applications

### Step 4 — Add middleware to Traefik label

```yaml
- traefik.http.routers.yourservice.middlewares=authentik-auth@file
```

The `authentik-auth` middleware is already defined in `traefik/config/dynamic.yml`.

---

## Google social login

1. Create OAuth 2.0 credentials in [Google Cloud Console](https://console.cloud.google.com)
   - Authorized redirect URI: `https://auth.yourdomain.com/source/oauth/callback/google/`
2. Admin → Directory → Federation & Social login → Create → **OAuth2/OpenID Source**
   - Slug: `google` (must match the URI above)
   - Consumer key: your Google Client ID
   - Consumer secret: your Google Client Secret
3. Add Google as a source to the identification stage:
   - Admin → Flows & Stages → Stages → `default-authentication-identification` → Edit → add Google to Sources
4. Link to your admin account:
   - Log in → User settings → Connected services → Google → Connect

> If your Google account email differs from your Authentik email, use manual linking via Connected Services. Authentik does not auto-link on email match by default.

---

## Enforcing TOTP 2FA

### Enroll your TOTP device

1. Log in to Authentik
2. Go to `https://auth.yourdomain.com/if/user/` → MFA Devices → TOTP Device → Enroll
3. Scan the QR code with your authenticator app (Google Authenticator, Aegis, etc.)

### Enforce 2FA in the login flow

1. Admin → Flows & Stages → Flows → `default-authentication-flow` → Stage Bindings
2. Click **Bind existing stage**
3. Stage: `default-authenticator-validation-stage`
4. Order: `30`
5. Save

All logins (including Google social login) will now require TOTP after password.

---

## Registration

In Authentik 2025.x, the `flow_enrollment` field was **removed from the Brand model**. Self-registration is off by default and there is no setting to re-enable it in the UI. The only way new users can be created is:

- Admin creates the account manually
- Invitation flow (create in Admin → Flows & Stages → Flows)
- Social login with "Allow users to enroll" turned ON (off by default)

You don't need to do anything to disable registration — it's already disabled.
