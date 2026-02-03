# Personal Finance Stack - All SQLite

Consolidated docker-compose setup for personal finance applications, all using SQLite databases.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Traefik Proxy                           │
│                    (reverse-proxy-traefik)                      │
└─────────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│  Firefly III  │    │  IHateMoney   │    │   Wallos      │
│   (SQLite)    │    │   (SQLite)    │    │   (SQLite)    │
└───────────────┘    └───────────────┘    └───────────────┘
        │
        ▼
┌───────────────┐
│    Actual     │
│   (SQLite)    │
└───────────────┘
```

## Applications

| App | Purpose | Database | URL |
|-----|---------|----------|-----|
| **Firefly III** | Personal finance management | SQLite | `firefly.thinkcenter.dev` |
| **IHateMoney** | Shared expense tracking | SQLite | `ihatemoney.thinkcenter.dev` |
| **Actual Budget** | Envelope budgeting | SQLite | `actual.thinkcenter.dev` |
| **Wallos** | Subscription tracking | SQLite | `wallos.thinkcenter.dev` |

## Database Files

| App | SQLite File Location |
|-----|---------------------|
| Firefly III | `./firefly-db/database.sqlite` |
| IHateMoney | `./ihatemoney-db/ihatemoney.db` |
| Actual | `./actual-data/*.db` (multiple files) |
| Wallos | `./wallos-db/wallos.db` |

## Quick Start

### 1. Create Directories

```bash
mkdir -p firefly-db firefly-upload actual-data wallos-db wallos-logos ihatemoney-db
```

### 2. Configure IHateMoney

```bash
# Generate admin password hash
docker run -it --rm --entrypoint ihatemoney ihatemoney/ihatemoney:latest generate_password_hash

# Generate secret key
openssl rand -base64 32
```

Edit the docker-compose.yml file and update:
- `ADMIN_PASSWORD=` (use the hash you generated, replace `$$` with `$$$$`)
- `SECRET_KEY=` (use the random secret)

### 3. Configure Firefly III

Generate a random 32-character string:

```bash
openssl rand -base64 32 | head -c32
```

Edit `./config/firefly-iii.env` and set `APP_KEY` to the generated string.

### 4. Start Services

```bash
docker-compose up -d
```

### 5. Configure DNS

Add these entries to your DNS server or `/etc/hosts`:

```
your-server-ip  firefly.thinkcenter.dev
your-server-ip  ihatemoney.thinkcenter.dev
your-server-ip  actual.thinkcenter.dev
your-server-ip  wallos.thinkcenter.dev
```

### 6. Initial Setup

#### Firefly III
1. Open `https://firefly.thinkcenter.dev`
2. Create admin account
3. Configure currency (CAD)

#### IHateMoney
1. Open `https://ihatemoney.thinkcenter.dev`
2. Create a new project
3. Invite members via link

#### Actual Budget
1. Open `https://actual.thinkcenter.dev`
2. Create a new budget file
3. Start adding transactions

#### Wallos
1. Open `https://wallos.thinkcenter.dev`
2. Create admin account
3. Configure currency and start adding subscriptions

## Backup & Restore

### Backup All Databases

```bash
# Create backup directory
mkdir -p backup

# Backup all SQLite files
cp firefly-db/database.sqlite backup/firefly_$(date +%Y%m%d).sqlite
cp ihatemoney-db/ihatemoney.db backup/ihatemoney_$(date +%Y%m%d).db
cp wallos-db/wallos.db backup/wallos_$(date +%Y%m%d).db
cp -r actual-data backup/actual_$(date +%Y%m%d)/
```

### Automated Backup Script

Create `backup.sh`:

```bash
#!/bin/bash
BACKUP_DIR="./backup"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

# Backup SQLite files
cp firefly-db/database.sqlite "$BACKUP_DIR/firefly_$DATE.sqlite"
cp ihatemoney-db/ihatemoney.db "$BACKUP_DIR/ihatemoney_$DATE.db"
cp wallos-db/wallos.db "$BACKUP_DIR/wallos_$DATE.db"
cp -r actual-data "$BACKUP_DIR/actual_$DATE/"

# Keep last 30 days only
find "$BACKUP_DIR" -name "*.sqlite" -o -name "*.db" -mtime +30 -delete
find "$BACKUP_DIR" -type d -name "actual_*" -mtime +30 -exec rm -rf {} + 2>/dev/null

echo "Backup completed: $DATE"
```

Run it automatically via cron:

```bash
# Add to crontab (daily at 2 AM)
0 2 * * * /path/to/docker-compose/backup.sh
```

### Restore

```bash
# Stop services first
docker-compose down

# Restore from backup
cp backup/firefly_20240115.sqlite firefly-db/database.sqlite
cp backup/ihatemoney_20240115.db ihatemoney-db/ihatemoney.db
cp backup/wallos_20240115.db wallos-db/wallos.db
cp -r backup/actual_20240115/* actual-data/

# Restart services
docker-compose up -d
```

## Maintenance

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f firefly-iii
docker-compose logs -f ihatemoney
```

### Restart Services

```bash
# Restart all
docker-compose restart

# Restart specific
docker-compose restart firefly-iii
```

### Update Services

```bash
# Pull latest images
docker-compose pull

# Recreate containers
docker-compose up -d --force-recreate
```

## Directory Structure

```
docker-compose/
├── docker-compose.yml
├── config/
│   └── firefly-iii.env
├── firefly-db/              # Firefly III SQLite database
├── firefly-upload/          # Firefly III uploaded files
├── ihatemoney-db/           # IHateMoney SQLite database
├── actual-data/             # Actual Budget files
├── wallos-db/               # Wallos SQLite database
├── wallos-logos/            # Wallos uploaded logos
└── backup/                  # Database backups
```

## Network

All services connect to `thinknetwork` which should be created by your Traefik setup.

If the network doesn't exist:

```bash
docker network create thinknetwork
```

## Troubleshooting

### Database locked error

SQLite can have issues with concurrent writes. If you see "database is locked":

```bash
# Restart the affected service
docker-compose restart firefly-iii
```

### Service won't start

```bash
# Check configuration
docker-compose config

# Check logs
docker-compose logs [service-name]
```

### Permission issues

```bash
# Fix SQLite file permissions
chmod 644 firefly-db/database.sqlite
chmod 644 ihatemoney-db/ihatemoney.db
chmod 644 wallos-db/wallos.db
```

## SQLite vs PostgreSQL

| Feature | SQLite | PostgreSQL |
|---------|--------|------------|
| Setup | Simple (single file) | Requires separate container |
| Performance | Good for single-user | Better for concurrent access |
| Backups | Copy file | Dump/restore required |
| Scaling | Limited | Highly scalable |
| Use case | Home server, personal use | Multi-user, high traffic |

For a home/personal server, SQLite is perfectly adequate and much simpler to manage.

## Security Notes

1. **Set secure passwords** before deploying
2. **Regular backups** - Use the backup script
3. **TLS/HTTPS** - Handled by Traefik proxy
4. **Firewall** - Only expose ports 80/443
5. **File permissions** - Keep database files private

## Future Additions

- [ ] Finance Importer API (`finance-importer/`)
- [ ] Automated backup script with cron
- [ ] Monitoring dashboard
- [ ] Grafana dashboards for spending visualization
