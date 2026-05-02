# code-server

**Role:** Optional. VS Code in the browser, protected by Authentik SSO.

Access at `https://ide.yourdomain.com`. An active Authentik session is required — unauthenticated requests are redirected to the login page.

---

## Key configuration

### PUID / PGID

Set these to match your host user's UID and GID so file permissions are correct:
```bash
id -u   # → PUID
id -g   # → PGID
```

### Workspace volume

The workspace is mounted to `/config/workspace` inside the container. Your files persist across container restarts at `/opt/homelab/code-server/workspace` on the host.

### Password

code-server has its own password (`FILE__PASSWORD`) in addition to Authentik SSO. Both are required: Authentik validates the session first, then code-server's own password gate applies.

If you only want one gate, you can disable code-server's password by setting `PASSWORD=` (empty) in environment — but keeping both is more secure.

---

## Tailscale inside the container (optional)

The compose file includes `NET_ADMIN`, `SYS_MODULE`, and `/dev/net/tun` to support running Tailscale inside the code-server container. This lets you use code-server as a Tailscale node, giving it direct access to your Tailscale network from within the IDE.

If you don't need this, remove:
```yaml
cap_add:
  - NET_ADMIN
  - SYS_MODULE
devices:
  - /dev/net/tun:/dev/net/tun
secrets:
  - tailscale_authkey
```

---

## HTTPS internally

code-server serves HTTPS with a self-signed certificate. Traefik uses the `skip-verify@file` server transport (defined in `dynamic.yml`) to connect to it without certificate verification. This is applied per-service via label — it does not affect other services.

---

## Installing extensions

Extensions install normally from within the VS Code UI. They're persisted in `/opt/homelab/code-server/config`.
