#!/bin/bash
# Stop all server services in reverse dependency order.
# Edit BASE to match where your compose files live.
set -euo pipefail

BASE=/opt/homelab

stop() {
  local name="$1"
  echo "  ■ $name"
  docker compose -f "$BASE/services/$name/compose.yml" down
}

echo "=== Stopping services ==="
stop watchtower
stop code-server
stop librechat     # includes ollama
stop vaultwarden
stop nextcloud
stop authentik
stop traefik       # removes the shared traefik network; includes cloudflared
stop dns           # last: DNS down only after all services are gone
echo "=== All services stopped ==="
