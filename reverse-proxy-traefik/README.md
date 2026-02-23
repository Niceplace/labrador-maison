# Traefik Reverse Proxy

Traefik serves as the reverse proxy for all services in the homelab, providing automatic HTTPS termination and routing.

## Authentication

Traefik provides authentication for various services. Currently configured:

- **Docker Registry**: Basic authentication required for push/pull operations
- **Registry UI**: No authentication (allows viewing and deleting images)

### Setting Up Docker Registry Authentication

The unified authentication script generates credentials, creates the htpasswd file for Traefik, and logs you into Docker's credential store.

**Option 1: Use random credentials (default)**

```bash
cd reverse-proxy-traefik
./scripts/registry-auth.sh
```

This generates random username and password, creates the htpasswd file, and logs you into the registry locally.

**Option 2: Use your own credentials via environment variables**

```bash
export REGISTRY_USERNAME="your_username"
export REGISTRY_PASSWORD="your_password"
cd reverse-proxy-traefik
./scripts/registry-auth.sh
```

### Deploying to thinkcenter

After running the setup script:

```bash
# Copy htpasswd file to thinkcenter (only htpasswd is needed)
scp reverse-proxy-traefik/auth/htpasswd thinkcenter:~/workspace/personal/labrador-maison/reverse-proxy-traefik/auth/

# Restart Traefik on thinkcenter
ssh thinkcenter "cd ~/workspace/personal/labrador-maison/reverse-proxy-traefik && docker-compose up -d"
```

### Credential Persistence

Credentials are stored in your system's credential store after the initial login:
- **macOS**: Keychain Access
- **Linux**: Depends on Docker credential helper (pass, secrets-service, etc.)

These credentials persist across reboots and are securely managed by your operating system.

### Files Generated

The setup script creates these files in `reverse-proxy-traefik/auth/`:

- `htpasswd` - Traefik Basic Auth credentials (bcrypt format)
- `credentials.txt` - Reference file with username/password

**Security Note**: The `auth/` directory is in `.gitignore` to prevent committing credentials.

### Using the Registry

After running the setup script, you can immediately push/pull images:

```bash
# Push
docker tag myimage registry.thinkcenter.dev/myimage:latest
docker push registry.thinkcenter.dev/myimage:latest

# Pull
docker pull registry.thinkcenter.dev/myimage:latest
```

No manual login required - Docker CLI uses the credentials from your system's credential store.

### Logging In From Another Machine

To access the registry from a different machine:

```bash
# Set credentials (from credentials.txt or remember them)
export REGISTRY_USERNAME="your_username"
export REGISTRY_PASSWORD="your_password"

# Login (stores in that machine's credential store)
docker login registry.thinkcenter.dev -u "$REGISTRY_USERNAME" --password-stdin <<< "$REGISTRY_PASSWORD"
```

### Regenerating Credentials

To regenerate credentials, simply run the setup script again:

```bash
# Option 1: Random credentials
./scripts/registry-auth.sh

# Option 2: Your own credentials
export REGISTRY_USERNAME="your_username"
export REGISTRY_PASSWORD="your_password"
./scripts/registry-auth.sh

# Option 3: Generate credentials only (for thinkcenter deployment)
./scripts/registry-auth.sh --no-login
```

Then:
1. Redeploy `htpasswd` to thinkcenter
2. Run the script on your local machine (credentials will be updated in credential store)

### Troubleshooting

**Login fails with "unauthorized: authentication required"**
- Ensure the `htpasswd` file was deployed to thinkcenter
- Restart Traefik: `docker-compose restart`

**Credentials not being used**
- Verify login was successful: check `docker info | grep Username`
- On macOS, credentials are in Keychain Access under "docker-credentials"

**Need to change credentials**
- Run `./scripts/registry-auth.sh` with new credentials
- Deploy new `htpasswd` to thinkcenter
- Run the script on your local machine (old credentials will be overwritten in credential store)

**Login to existing registry failed: unexpected status: 401 Unauthorized**
- This usually means the `htpasswd` file on thinkcenter doesn't match your local credentials
- Ensure both thinkcenter and local machine use the same username/password
