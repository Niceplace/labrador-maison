#!/bin/bash
# Backup script for all finance app SQLite databases
# Add to crontab with: 0 2 * * * /path/to/docker-compose/backup.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$SCRIPT_DIR/backup"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

echo "Starting backup at $DATE"

# Backup Firefly III
if [ -f "$SCRIPT_DIR/firefly-db/database.sqlite" ]; then
    cp "$SCRIPT_DIR/firefly-db/database.sqlite" "$BACKUP_DIR/firefly_$DATE.sqlite"
    echo "Backed up Firefly III"
fi

# Backup IHateMoney
if [ -f "$SCRIPT_DIR/ihatemoney-db/ihatemoney.db" ]; then
    cp "$SCRIPT_DIR/ihatemoney-db/ihatemoney.db" "$BACKUP_DIR/ihatemoney_$DATE.db"
    echo "Backed up IHateMoney"
fi

# Backup Wallos
if [ -f "$SCRIPT_DIR/wallos-db/wallos.db" ]; then
    cp "$SCRIPT_DIR/wallos-db/wallos.db" "$BACKUP_DIR/wallos_$DATE.db"
    echo "Backed up Wallos"
fi

# Backup Actual (directory)
if [ -d "$SCRIPT_DIR/actual-data" ] && [ "$(ls -A $SCRIPT_DIR/actual-data)" ]; then
    cp -r "$SCRIPT_DIR/actual-data" "$BACKUP_DIR/actual_$DATE/"
    echo "Backed up Actual Budget"
fi

# Keep last 30 days only (skip actual directories as they're large)
find "$BACKUP_DIR" -name "*.sqlite" -mtime +30 -delete
find "$BACKUP_DIR" -name "*.db" -mtime +30 -delete

# For Actual, keep only last 7 backups (due to size)
ls -dt "$BACKUP_DIR"/actual_* 2>/dev/null | tail -n +8 | xargs rm -rf 2>/dev/null || true

echo "Backup completed: $DATE"
echo "Backup location: $BACKUP_DIR"
