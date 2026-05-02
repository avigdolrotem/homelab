#!/bin/bash
# Generate all secrets for the homelab stack.
#
# Usage:
#   bash generate-secrets.sh [secrets-dir]
#
# Defaults to /opt/homelab/secrets if no argument is given.
# Existing secrets are never overwritten — safe to re-run.
set -euo pipefail

SECRETS_DIR="${1:-/opt/homelab/secrets}"

echo "Secrets directory: $SECRETS_DIR"
mkdir -p "$SECRETS_DIR"
chmod 700 "$SECRETS_DIR"
echo ""

# ── Helpers ───────────────────────────────────────────────────────────────────

# Generate a random base64 secret (32 bytes → 43 chars)
gen_random() {
  local file="$SECRETS_DIR/$1"
  if [ -f "$file" ]; then
    echo "  ✓ $1 (exists, skipping)"
  else
    openssl rand -base64 32 | tr -d '\n=' > "$file"
    chmod 600 "$file"
    echo "  ✓ $1 (generated)"
  fi
}

# Generate a long hex secret (64 bytes → 128 chars) — for JWT and encryption keys
gen_hex() {
  local file="$SECRETS_DIR/$1"
  if [ -f "$file" ]; then
    echo "  ✓ $1 (exists, skipping)"
  else
    openssl rand -hex 64 | tr -d '\n' > "$file"
    chmod 600 "$file"
    echo "  ✓ $1 (generated)"
  fi
}

# Create a placeholder that must be filled in manually
gen_manual() {
  local file="$SECRETS_DIR/$1"
  if [ -f "$file" ]; then
    echo "  ✓ $1 (exists, skipping)"
  else
    echo "REPLACE_ME" > "$file"
    chmod 600 "$file"
    echo "  ⚠  $1 (placeholder — edit manually before starting)"
  fi
}

# ── Auto-generated secrets ────────────────────────────────────────────────────
echo "=== Auto-generated (random) ==="

# Authentik
gen_random authentik_pg_password
gen_hex    authentik_secret_key     # Authentik requires a long secret key

# Nextcloud / MariaDB
gen_random mariadb_root_password
gen_random mariadb_password

# Vaultwarden / PostgreSQL
gen_random postgres_password

# LibreChat / MongoDB
gen_random mongodb_password

# ── Traefik users (htpasswd format) ──────────────────────────────────────────
echo ""
echo "=== Traefik basic auth users ==="
TRAEFIK_USERS_FILE="$SECRETS_DIR/traefik_users"
if [ -f "$TRAEFIK_USERS_FILE" ]; then
  echo "  ✓ traefik_users (exists, skipping)"
else
  # Check if htpasswd is available
  if command -v htpasswd &> /dev/null; then
    read -rp "  Enter username for Traefik dashboard (emergency fallback): " TF_USER
    read -rsp "  Enter password: " TF_PASS
    echo ""
    htpasswd -nbB "$TF_USER" "$TF_PASS" > "$TRAEFIK_USERS_FILE"
    chmod 600 "$TRAEFIK_USERS_FILE"
    echo "  ✓ traefik_users (generated with htpasswd)"
  else
    echo "  ⚠  htpasswd not found. Install apache2-utils (Debian) or httpd-tools (RHEL)."
    echo "     Then run: htpasswd -nbB admin 'yourpassword' > $TRAEFIK_USERS_FILE"
    echo "     Or generate online: https://bcrypt-generator.com/"
    gen_manual traefik_users
  fi
fi

# ── Secrets requiring manual values ──────────────────────────────────────────
echo ""
echo "=== Manual secrets (you must provide these) ==="

# code-server IDE passwords
gen_manual ide_password
gen_manual ide_sudo_password

# Cloudflare API token — Zone:DNS:Edit permission required
# Get from: https://dash.cloudflare.com/profile/api-tokens
gen_manual cloudflare_token

# Cloudflare Tunnel token
# Get from: Zero Trust dashboard → Networks → Tunnels → your tunnel → Configure
gen_manual cloudflare_tunnel_token

# SMTP password — shared by Vaultwarden and Watchtower
gen_manual vaultwarden_smtp_password

# Tailscale auth key (only needed if running Tailscale inside code-server container)
# Get from: https://login.tailscale.com/admin/settings/keys
gen_manual tailscale_authkey

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "=== Done ==="
echo ""
echo "Next steps:"
echo "  1. Edit any secrets marked ⚠  above:"
echo "     $SECRETS_DIR/"
echo ""
echo "  2. Copy and fill env.example files:"
echo "     cp services/authentik/config/authentik.env.example services/authentik/config/authentik.env"
echo "     cp services/vaultwarden/config/vaultwarden.env.example services/vaultwarden/config/vaultwarden.env"
echo "     cp services/librechat/config/librechat.env.example services/librechat/config/librechat.env"
echo ""
echo "  3. Fill authentik.env with the actual values from:"
echo "     cat $SECRETS_DIR/authentik_pg_password"
echo "     cat $SECRETS_DIR/authentik_secret_key"
echo ""
echo "  4. Replace yourdomain.com and /opt/homelab in all compose files"
echo ""
echo "  5. Run: bash scripts/start.sh"
