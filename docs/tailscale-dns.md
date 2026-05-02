# Tailscale + Split DNS (optional)

This setup enables devices connected via Tailscale to reach your homelab services at LAN speed — bypassing Cloudflare and going directly to your server.

Without this, Tailscale-connected devices resolve `cloud.yourdomain.com` to Cloudflare's IP, and traffic routes: device → Cloudflare → Tunnel → your server. With split DNS, they resolve directly to your server's LAN IP.

---

## How it works

CoreDNS runs on the server and acts as an authoritative resolver for `yourdomain.com`:
- All subdomains → `YOUR_SERVER_LAN_IP`
- Everything else → forwarded to `1.1.1.1` / `8.8.8.8`

Tailscale is configured to use your server's Tailscale IP as the DNS server for your domain.

---

## Setup

### 1. Run CoreDNS

```bash
docker compose -f services/dns/compose.yml up -d
```

Edit `services/dns/config/yourdomain.com.zone` and replace `YOUR_SERVER_LAN_IP` with your server's actual LAN IP.

### 2. Configure Tailscale split DNS

1. Go to [Tailscale Admin → DNS](https://login.tailscale.com/admin/dns)
2. Under **Nameservers**, add a **Split DNS** entry:
   - Domain: `yourdomain.com`
   - Nameserver: your server's Tailscale IP (e.g. `100.x.x.x`)
3. Make sure **"Override local DNS"** is off (you only want to override this domain, not all DNS)

### 3. Test

From a Tailscale-connected device:
```bash
dig cloud.yourdomain.com        # Should return YOUR_SERVER_LAN_IP
dig google.com                  # Should still work normally
```

In Traefik access logs, requests from Tailscale devices will show a `100.x.x.x` source IP.

---

For more on Tailscale DNS: [tailscale.com/kb/1054/dns](https://tailscale.com/kb/1054/dns)
