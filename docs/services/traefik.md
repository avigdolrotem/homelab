# Traefik

**Role:** Core — required for everything else.

Traefik is the reverse proxy that sits in front of every service. It handles:
- Routing requests to the right container based on hostname
- TLS termination (HTTPS) with automatic Let's Encrypt certificates
- Applying middlewares (auth, rate limiting, security headers)
- Service discovery via Docker labels (no config file needed per service)

---

## Components

This stack runs three containers in the `traefik` compose file:

| Container | Purpose |
|-----------|---------|
| `traefik` | The reverse proxy itself |
| `socket-proxy` | Read-only Docker API proxy (security) |
| `cloudflare-tunnel` | Cloudflare Tunnel connector |

### Why socket-proxy?

Traefik needs to read Docker container labels to discover services. The naive approach is mounting `/var/run/docker.sock` directly. That's a significant security risk — any container escape would have full Docker API access (root on the host).

The socket proxy exposes only the specific API endpoints Traefik needs (`CONTAINERS`, `EVENTS`, `PING`, `INFO`) over a private internal network. Traefik never touches the real socket.

### Why Cloudflare Tunnel?

Your server has no open ports to the internet. The tunnel is an outbound connection from `cloudflared` to Cloudflare. Internet traffic flows: `Browser → Cloudflare → Tunnel → cloudflared → Traefik`.

LAN and Tailscale devices still connect directly to Traefik on port 80/443.

---

## TLS certificates

Traefik uses the **ACME DNS challenge** via Cloudflare to issue certificates. This means:
- No port 80 inbound needed for cert issuance (HTTP challenge not used)
- A single wildcard cert (`*.yourdomain.com`) covers all subdomains
- Auto-renews before expiry

Certificates are stored in `traefik/letsencrypt/acme.json`. Back this file up — losing it means rate-limit delays when re-requesting.

---

## Dynamic configuration (`dynamic.yml`)

Traefik's static config (entrypoints, providers, ACME) is in the compose `command:` flags.

Everything else — middlewares, TLS options, server transports — lives in `config/dynamic.yml`. This file is watched by Traefik and reloaded automatically on change. No container restart needed.

### Middlewares defined

| Name | Type | Purpose |
|------|------|---------|
| `security-headers` | Headers | Standard security headers for general apps |
| `secure-headers` | Headers | Stricter CSP + longer HSTS for sensitive apps |
| `authentik-auth` | ForwardAuth | Authentik SSO gate |
| `auth` | BasicAuth | Emergency fallback (not wired by default) |
| `rate-limit` | RateLimit | 50 req/s average, 100 burst |
| `compression` | Compress | Response compression (excludes SSE streams) |

Apply a middleware to a service via labels:
```yaml
- traefik.http.routers.myapp.middlewares=authentik-auth@file,rate-limit@file
```

---

## forwardedHeaders

```yaml
--entrypoints.websecure.forwardedHeaders.trustedIPs=172.20.0.0/16,127.0.0.1/32,100.64.0.0/10,192.168.0.0/16
```

This tells Traefik to trust `X-Forwarded-For` headers from these IP ranges. Without this, the real client IP would be lost and all requests would appear to come from the tunnel container.

- `172.20.0.0/16` — Docker bridge network (Cloudflare Tunnel container)
- `100.64.0.0/10` — Tailscale address space
- `192.168.0.0/16` — LAN

---

## TLS enforcement

TLS 1.3 is enforced globally via:
```yaml
# In compose command:
--entrypoints.websecure.http.tls.options=modern@file

# In dynamic.yml:
tls:
  options:
    modern:
      minVersion: "VersionTLS13"
```

---

## Adding a new service

1. Add the service to a new compose file under `services/yourservice/`
2. Attach it to the `traefik` external network
3. Add labels:

```yaml
networks:
  - traefik

labels:
  - traefik.enable=true
  - traefik.http.routers.yourservice.rule=Host(`yourservice.yourdomain.com`)
  - traefik.http.routers.yourservice.entrypoints=websecure
  - traefik.http.routers.yourservice.tls.certresolver=letsencrypt
  - traefik.http.services.yourservice.loadbalancer.server.port=8080
  # Optional: protect with Authentik
  - traefik.http.routers.yourservice.middlewares=authentik-auth@file
```

Traefik picks it up within seconds — no restart needed.
