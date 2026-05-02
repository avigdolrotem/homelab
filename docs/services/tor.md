# Tor Browser

**Role:** Optional. Remote Tor Browser access via noVNC, protected by Authentik SSO.

Access at `https://tor.yourdomain.com`. An active Authentik session is required — do not expose this without authentication.

---

## What it is

A containerized Tor Browser running in a virtual display, exposed via noVNC. You get a full Tor Browser session in your browser window, routed through the Tor network.

---

## Stateless by design

No volumes are mounted. Every container restart gives you a fresh Tor Browser with a new identity. Session data is never persisted — no history, no cookies, no saved state.

This is intentional. If you need persistent state between sessions, mount `/home/user` to a volume — but understand the privacy trade-offs.

---

## Platform note

The image (`domistyle/tor-browser`) only has an `amd64` build. The `platform: linux/amd64` field ensures Docker uses Rosetta emulation on Apple Silicon Macs. Performance will be slower on ARM hosts.

---

## Authentication

Protected by Authentik via `authentik-auth@file` middleware. Any request to `tor.yourdomain.com` without an active Authentik session is redirected to the login page.

Do not remove the middleware or route this service through a public URL without auth — Tor Browser access should always be authenticated.
