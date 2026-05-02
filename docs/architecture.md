# Architecture

How the stack fits together.

---

## Traffic paths

There are two ways traffic reaches your services:

### 1. Internet → Cloudflare Tunnel
```
Browser
  └── HTTPS → Cloudflare CDN (yourdomain.com)
                  └── Cloudflare Tunnel (outbound connection from server)
                            └── cloudflared container
                                    └── Traefik (port 80 internally)
                                            └── Service container
```
No ports are open on your router. Cloudflared establishes an outbound connection to Cloudflare, and all internet traffic flows through that tunnel.

### 2. LAN / Tailscale → Direct
```
Device on LAN or Tailscale
  └── HTTPS → YOUR_SERVER_LAN_IP:443 (or Tailscale IP:443)
                    └── Traefik (port 443, bound on all interfaces)
                            └── Service container
```
Devices on your local network or connected via Tailscale bypass Cloudflare entirely. This means:
- Lower latency (no round-trip to Cloudflare)
- Works even if Cloudflare is down
- Real client IPs are preserved in Traefik logs

---

## Docker networks

```
┌─────────────────────────────────────────────────────────┐
│  traefik (bridge, 172.20.0.0/16)                        │
│  ┌────────────┐  ┌───────────┐  ┌──────────┐  ┌──────┐ │
│  │  traefik   │  │ authentik │  │nextcloud │  │  …   │ │
│  │            │  │  -server  │  │          │  │      │ │
│  └────────────┘  └────┬──────┘  └────┬─────┘  └──┬───┘ │
└─────────────────────────────────────────────────────────┘
                         │              │            │
           ┌─────────────┘    ┌─────────┘           │
           ▼                  ▼                      ▼
 ┌─────────────────┐  ┌────────────────┐    ┌───────────────┐
 │ authentik-      │  │ nextcloud-     │    │  (per-stack   │
 │ internal        │  │ internal       │    │   internal    │
 │                 │  │                │    │   networks)   │
 │ authentik-db    │  │ nextcloud-db   │    │               │
 │ authentik-redis │  │                │    │               │
 └─────────────────┘  └────────────────┘    └───────────────┘
```

**Key principle:** Every service that has a database uses an `internal: true` network that connects only the app and its DB. Neither Traefik nor any other stack can reach a database directly.

**socket-proxy network:** An additional `internal: true` network just for Traefik ↔ socket-proxy. The socket proxy gives Traefik read-only access to Docker labels without exposing the full Docker API.

---

## Reverse proxy (Traefik)

Traefik discovers services automatically via Docker labels. Each service declares its own routing rules:

```yaml
labels:
  - traefik.enable=true
  - traefik.http.routers.myapp.rule=Host(`myapp.yourdomain.com`)
  - traefik.http.routers.myapp.entrypoints=websecure
  - traefik.http.routers.myapp.tls.certresolver=letsencrypt
  - traefik.http.services.myapp.loadbalancer.server.port=8080
```

No central routing config to update — add labels to a service, Traefik picks it up.

---

## TLS certificates

Traefik uses **ACME DNS challenge** via Cloudflare to issue Let's Encrypt wildcard certificates (`*.yourdomain.com`). 

Benefits:
- One cert covers all subdomains
- No port 80 inbound needed for certificate issuance
- Auto-renews before expiry
- Works even for services not exposed to the internet

Certs are stored in `traefik/letsencrypt/acme.json`.

---

## Authentication (Authentik)

Services can opt into SSO via Traefik's `forwardAuth` middleware.

**Flow for a protected service:**
```
Request → Traefik router
            └── authentik-auth@file middleware
                    └── Authentik outpost (/outpost.goauthentik.io/auth/traefik)
                            │
                    ┌───────┴──────────┐
                    │                  │
              Cookie valid?       No session
                    │                  │
              Forward to          Redirect to
              service             auth.yourdomain.com/login
```

The Authentik outpost runs as part of `authentik-server` (embedded outpost). No separate outpost container needed for this setup.

**Services protected by Authentik:** Traefik Dashboard, code-server, Tor Browser.

**Services with their own auth (not Authentik-protected):** Nextcloud, Vaultwarden, LibreChat. These have robust built-in authentication.

---

## Secret management

All secrets are stored as individual files in `secrets/` and mounted as Docker secrets:

```yaml
secrets:
  my_secret:
    file: /opt/homelab/secrets/my_secret

services:
  myapp:
    secrets:
      - my_secret
    environment:
      - MY_SECRET_FILE=/run/secrets/my_secret
```

Benefits:
- Secrets never appear in `docker inspect` or `docker ps` output
- Not in environment variables (which can leak via `/proc`)
- `secrets/` directory is gitignored — never ends up in version control

---

## Watchtower update strategy

Not all containers are equal for auto-updates:

| Label | Meaning |
|-------|---------|
| `watchtower.enable=true` | Auto-update when a new image is available |
| `watchtower.monitor-only=true` | Alert on new images but don't update |

Databases and apps with schema migrations (`nextcloud`, `nextcloud-db`, `vaultwarden-db`, `authentik`) are set to `monitor-only`. Everything else auto-updates on Sunday at 03:00.
