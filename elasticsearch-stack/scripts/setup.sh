#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_DIR="$(dirname "$SCRIPT_DIR")"
SECRETS_FILE="$STACK_DIR/.secrets.env"

generate_password() {
  local length="${1:-24}"
  local chars='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
  local password=""
  local rand_bytes
  rand_bytes=$(openssl rand -hex "$length" 2>/dev/null)
  for (( i=0; i<length; i++ )); do
    local idx=$((16#${rand_bytes:$((i*2)):2} % ${#chars}))
    password+="${chars:$idx:1}"
  done
  printf '%s' "$password"
}

generate_base64() {
  local length="${1:-32}"
  openssl rand -base64 48 | tr -d '\n' | head -c "$length"
}

generate_htpasswd() {
  local username="$1"
  local password="$2"
  printf '%s:%s' "$username" "$(printf '%s' "$password" | openssl passwd -apr1 -stdin)"
}

if [ -f "$SECRETS_FILE" ]; then
  read -rp "WARNING: $SECRETS_FILE already exists. Overwrite? [y/N] " confirm
  if [[ "$confirm" != [yY] ]]; then
    echo "Aborted."
    exit 0
  fi
fi

ELASTIC_PASSWORD=$(generate_password 24)
KIBANA_ENCRYPTION_KEY=$(generate_base64 32)
ES_BASIC_AUTH=$(generate_htpasswd "elastic" "$ELASTIC_PASSWORD")

cat > "$SECRETS_FILE" <<EOF
ELASTIC_PASSWORD=${ELASTIC_PASSWORD}
KIBANA_ENCRYPTION_KEY=${KIBANA_ENCRYPTION_KEY}
ES_BASIC_AUTH=${ES_BASIC_AUTH}
EOF

chmod 600 "$SECRETS_FILE"

echo "Secrets generated: $SECRETS_FILE"
echo ""
echo "  ELASTIC_PASSWORD=${ELASTIC_PASSWORD}"
echo "  KIBANA_ENCRYPTION_KEY=${KIBANA_ENCRYPTION_KEY}"
echo "  ES_BASIC_AUTH=${ES_BASIC_AUTH}"
