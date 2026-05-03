#!/bin/bash
# Start all server services in dependency order.
# Edit BASE to match where your compose files live.
set -euo pipefail

BASE=/opt/homelab

start() {
  local name="$1"
  echo "  ▶ $name"
  docker compose -f "$BASE/services/$name/compose.yml" up -d
}

echo "=== Starting services ==="
start dns           # first: DNS must be up before anything needs name resolution
start traefik       # creates the traefik network; includes cloudflared
start authentik     # SSO — needs traefik network
start nextcloud
start vaultwarden
start code-server
start watchtower    # last: begins monitoring all other containers
echo "=== All services started ==="
