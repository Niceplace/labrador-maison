#!/bin/bash
set -e

# Configuration
AUTH_DIR="$(dirname "$0")/../auth"
HTPASSWD_FILE="$AUTH_DIR/htpasswd"
CREDENTIALS_FILE="$AUTH_DIR/credentials.txt"
REGISTRY_HOST="registry.thinkcenter.dev"

# Parse arguments
NO_LOGIN=false
for arg in "$@"; do
  case $arg in
    --no-login)
      NO_LOGIN=true
      shift
      ;;
    *)
      # Unknown option
      ;;
  esac
done

# Create auth directory
mkdir -p "$AUTH_DIR"

# Get credentials from environment variables or generate random ones
if [ -n "$REGISTRY_USERNAME" ] && [ -n "$REGISTRY_PASSWORD" ]; then
  USERNAME="$REGISTRY_USERNAME"
  PASSWORD="$REGISTRY_PASSWORD"
  CREDENTIALS_SOURCE="environment variables"
else
  USERNAME="labrador"
  PASSWORD=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-20)
  CREDENTIALS_SOURCE="randomly generated"
fi

echo "Setting up authentication for Docker registry..."
echo "Using credentials from: $CREDENTIALS_SOURCE"

# Generate bcrypt password for htpasswd
HTPASSWD_ENTRY=$(htpasswd -nbB "$USERNAME" "$PASSWORD" | sed -e 's/\$/\$\$/g')

# Create htpasswd file for Traefik
echo "$HTPASSWD_ENTRY" > "$HTPASSWD_FILE"
chmod 644 "$HTPASSWD_FILE"

# Save credentials for reference
cat > "$CREDENTIALS_FILE" <<EOF
Docker Registry Credentials
============================
Registry: $REGISTRY_HOST
Username: $USERNAME
Password: $PASSWORD
Source: $CREDENTIALS_SOURCE

Files created:
- $HTPASSWD_FILE (Traefik Basic Auth)
- $CREDENTIALS_FILE (This file)

To login to the registry from another machine:
  export REGISTRY_USERNAME="$USERNAME"
  export REGISTRY_PASSWORD="$PASSWORD"
  docker login $REGISTRY_HOST -u "\$REGISTRY_USERNAME" --password-stdin <<< "\$REGISTRY_PASSWORD"
EOF
chmod 644 "$CREDENTIALS_FILE"

echo "Authentication setup complete!"
echo "Credentials saved to: $CREDENTIALS_FILE"
echo ""

# Login to Docker registry (unless --no-login flag is set)
if [ "$NO_LOGIN" = false ]; then
  echo "Logging in to $REGISTRY_HOST as $USERNAME..."
  echo "$PASSWORD" | docker login "$REGISTRY_HOST" -u "$USERNAME" --password-stdin

  if [ $? -eq 0 ]; then
    echo ""
    echo "Successfully logged in! Credentials are stored in your system's credential store."
    echo "You can now push and pull images without re-authenticating."
  else
    echo ""
    echo "Login failed. Please check your credentials."
    echo ""
    echo "To manually login later:"
    echo "  export REGISTRY_USERNAME=\"$USERNAME\""
    echo "  export REGISTRY_PASSWORD=\"$PASSWORD\""
    echo "  docker login $REGISTRY_HOST -u \"\$REGISTRY_USERNAME\" --password-stdin <<< \"\$REGISTRY_PASSWORD\""
    exit 1
  fi
fi
