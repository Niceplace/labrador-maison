# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture Overview

This is a homelab configuration repository where all applications run as Docker containers behind a Traefik reverse proxy. All services are dynamically configured via Docker labels - Traefik watches the Docker daemon and automatically creates routes and TLS terminators.

### Core Components

| Component | Purpose |
|-----------|---------|
| **Traefik** | Reverse proxy with automatic HTTPS using self-signed certs |
| **Certificate Authority** | Self-signed CA in `root-certificate-authority/` for internal TLS |
| **thinknetwork** | Shared Docker network all services attach to |

### Service Discovery Pattern

All services follow this routing pattern:
- DNS entry: `<app>.thinkcenter.dev` → server IP (configured in Pi-hole)
- Docker label: `traefik.http.routers.<name>.rule=Host(\`<app>.thinkcenter.dev\`)`
- Docker label: `traefik.http.routers.<name>.entrypoints=websecure`

Traefik automatically handles TLS termination using the self-signed certificates from `reverse-proxy-traefik/certs/`.

## Services

| Service | Directory | Database | Purpose |
|---------|-----------|----------|---------|
| Firefly III | `docker-compose/firefly-iii/` | SQLite | Personal finance |
| IHateMoney | `docker-compose/ihatemoney/` | SQLite | Shared expense tracking |
| Actual Budget | `docker-compose/actual/` | SQLite | Envelope budgeting |
| Wallos | `docker-compose/wallos/` | SQLite | Subscription tracking |
| Concourse CI | `concourse-ci/` | PostgreSQL | CI/CD pipelines |
| Grafana Stack | `grafana-oss-stack/` | Volumes | Observability (Prometheus, Loki, Tempo, Alloy) |
| Container Registry | `container-registry/` | Volume | Private Docker registry with UI |
| Komodo | `komodo/` | MongoDB | Fleet management |

## Common Operations

### Start/Stop Services

All services use `docker-compose`:
```bash
cd <service-directory>
docker-compose up -d    # Start
docker-compose down     # Stop
docker-compose logs -f  # View logs
```

### Add a New Service

1. **Generate TLS certificate** using the CA scripts:
   ```bash
   # Server cert for Traefik
   root-certificate-authority/generate-server-cert.sh <appname> reverse-proxy-traefik/certs/
   ```

2. **Create docker-compose.yml** with required labels:
   ```yaml
   labels:
     - "traefik.enable=true"
     - "traefik.docker.network=thinknetwork"
     - "traefik.http.routers.myapp.rule=Host(\`myapp.thinkcenter.dev\`)"
     - "traefik.http.routers.myapp.entrypoints=websecure"
     - "traefik.http.services.myapp.loadbalancer.server.port=8080"
   networks:
     - thinknetwork
   ```

3. **Add DNS entry** to Pi-hole (manually or via scripts in `~/workspace/_scripts/`)

4. **Create thinknetwork** if it doesn't exist:
   ```bash
   docker network create thinknetwork
   ```

### Update Docker Images

Use the container registry cache warmer - it automatically pulls images referenced in Renovate PRs. To manually update:

```bash
docker-compose pull
docker-compose up -d --force-recreate
```

### Generate Certificates

```bash
# Server certificate (for Traefik-terminated services)
root-certificate-authority/generate-server-cert.sh <hostname> <output-dir>

# Client certificate (for mTLS)
root-certificate-authority/generate-client-cert.sh <output-dir>
```

Certificate files are named `wildcard.thinkcenter.dev.*.pem` and must be placed in `reverse-proxy-traefik/certs/`.

## Configuration Management

- Each service has a `.env.example` file - copy to `.env` and configure
- Sensitive values (passwords, keys) should use environment variables, never be committed
- Traefik static config: `reverse-proxy-traefik/config/traefik.yaml`
- Traefik dynamic config: `reverse-proxy-traefik/config/dynamic/`

## CI/CD

- **Renovate bot**: Runs weekly via GitHub Actions (`.github/workflows/renovate.yml`)
- **Concourse CI**: Pipeline definitions in `concourse-ci/pipelines/` for building Deno apps
- **Container registry**: Has a cache warmer that polls GitHub for Renovate PRs and pre-pulls images

## OTEL/Telemetry

Send OpenTelemetry data to Grafana Alloy:
- **gRPC**: `alloy:4317` (internal) or `alloy-otlp-grpc.thinkcenter.dev:4317`
- **HTTP**: `alloy:4318` (internal) or `alloy-otlp.thinkcenter.dev:4318`

## Important Notes

- All images are pinned to specific SHA digests for reproducibility
- Services use `restart: unless-stopped`
- `TZ=America/Toronto` timezone is standard
- SQLite databases are backed up to `./backup/` directories
- Grafana stack requires significant storage (~100GB+ for 30-day retention)
