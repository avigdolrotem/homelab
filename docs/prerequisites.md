# Prerequisites

Everything you need before running the stack.

---

## 1. Docker

Install Docker Desktop (macOS/Windows) or Docker Engine + Docker Compose plugin (Linux).

- Minimum: Docker 24+, Compose v2
- Verify: `docker compose version`

---

## 2. A domain name

You need a domain you control. Any registrar works — Namecheap, Cloudflare Registrar, Porkbun, etc.

The domain **must be managed by Cloudflare** (even if registered elsewhere). This is required for:
- DNS challenge TLS certificate issuance (no open ports needed)
- Cloudflare Tunnel to work

---

## 3. Cloudflare account (free)

1. Create an account at [cloudflare.com](https://cloudflare.com)
2. Add your domain → follow the nameserver change instructions
3. Wait for nameserver propagation (usually under 30 minutes)

---

## 4. Cloudflare API token

Traefik uses this to create DNS records for TLS certificate issuance via ACME DNS challenge.

1. Go to [dash.cloudflare.com/profile/api-tokens](https://dash.cloudflare.com/profile/api-tokens)
2. Click **Create Token**
3. Use the **Edit zone DNS** template
4. Under Zone Resources → select your specific domain
5. Create and copy the token → save to `secrets/cloudflare_token`

---

## 5. Cloudflare Tunnel

The tunnel lets internet traffic reach your server without opening any ports on your router.

1. Go to [Cloudflare Zero Trust dashboard](https://one.dash.cloudflare.com)
2. Navigate to **Networks → Tunnels → Create a tunnel**
3. Choose **Cloudflared** connector type
4. Name your tunnel (e.g. `homelab`)
5. Copy the tunnel token → save to `secrets/cloudflare_tunnel_token`
6. Configure Public Hostnames in the tunnel dashboard:
   - Add a route for each subdomain: `cloud.yourdomain.com` → `http://traefik:80` (or HTTPS if applicable)
   - Or: add a single wildcard route `*.yourdomain.com` → `http://traefik:80`

> **Note:** Cloudflare Tunnel connects outbound from your server to Cloudflare. No inbound ports need to be opened on your router for internet access. Port 80/443 is still used for LAN/Tailscale direct access.

---

## 6. SMTP credentials

Used by Watchtower (update notifications) and Vaultwarden (email verification).

Any SMTP provider works: Zoho Mail (free tier), Gmail (app password), Mailgun, etc.

You need:
- SMTP host (e.g. `smtp.zoho.com`)
- Port (usually 587 for STARTTLS)
- Username (usually your email address)
- Password → save to `secrets/vaultwarden_smtp_password`

---

## 7. Server requirements

This stack runs comfortably on:
- **Minimum:** 4 GB RAM, 2 CPU cores, 50 GB storage
- **Recommended:** 8 GB RAM, 4 CPU cores, 100+ GB storage (especially if using Ollama/LibreChat)
- Tested on macOS with Docker Desktop; works on Linux with Docker Engine

### Port requirements

| Port | Protocol | Purpose |
|------|---------|---------|
| 80 | TCP | HTTP (redirects to HTTPS) |
| 443 | TCP | HTTPS (LAN + Tailscale direct access) |
| 53 | UDP+TCP | DNS (only if running CoreDNS) |

Internet traffic comes exclusively via Cloudflare Tunnel — no router port forwarding needed for that path.

---

## Optional: Tailscale

Tailscale creates a private encrypted mesh network between your devices. Combined with CoreDNS (see [tailscale-dns.md](tailscale-dns.md)), it lets your phone/laptop reach your services directly over LAN speeds when at home, without going through Cloudflare.

Get it at [tailscale.com](https://tailscale.com) — free for personal use.
