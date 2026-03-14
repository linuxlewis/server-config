#!/usr/bin/env bash
set -euo pipefail

# Restore script using restic
# Usage: ./restore.sh [snapshot-id]
# If no snapshot ID given, restores latest

SNAPSHOT="${1:-latest}"
RESTORE_TARGET="/"

log() { echo "[restore] $(date '+%Y-%m-%d %H:%M:%S') $*"; }

: "${RESTIC_REPOSITORY:?Set RESTIC_REPOSITORY}"
: "${RESTIC_PASSWORD:?Set RESTIC_PASSWORD}"

log "Available snapshots:"
restic snapshots

log "Restoring snapshot: $SNAPSHOT"

# Stop services before restore
log "Stopping Docker services..."
cd /opt/server-config/docker && docker compose down

# Restore files
log "Restoring files..."
restic restore "$SNAPSHOT" --target "$RESTORE_TARGET"

# Restart services
log "Starting Docker services..."
cd /opt/server-config/docker && docker compose up -d

# Wait for postgres to be ready
log "Waiting for PostgreSQL..."
sleep 10

# Restore database
if [ -f /opt/backups/postgres_dump.sql ]; then
    log "Restoring PostgreSQL databases..."
    docker exec -i postgres psql -U "${POSTGRES_USER:-dev}" < /opt/backups/postgres_dump.sql
fi

log "Restore complete!"
