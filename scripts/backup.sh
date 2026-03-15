#!/usr/bin/env bash
set -euo pipefail

# Backup script using restic
# Prerequisites: restic installed, RESTIC_REPOSITORY and RESTIC_PASSWORD set

BACKUP_PATHS=(
    /home
    /opt/services
)

EXCLUDE_PATTERNS=(
    "*.tmp"
    "*.log"
    ".cache"
    "node_modules"
)

log() { echo "[backup] $(date '+%Y-%m-%d %H:%M:%S') $*"; }

# Check required env vars
: "${RESTIC_REPOSITORY:?Set RESTIC_REPOSITORY (e.g., /mnt/backup, s3:bucket/path)}"
: "${RESTIC_PASSWORD:?Set RESTIC_PASSWORD}"

# Initialize repo if needed
if ! restic snapshots &>/dev/null; then
    log "Initializing restic repository..."
    restic init
fi

# Build exclude args
EXCLUDE_ARGS=()
for pattern in "${EXCLUDE_PATTERNS[@]}"; do
    EXCLUDE_ARGS+=(--exclude "$pattern")
done

# Run backup
log "Starting backup..."
restic backup \
    "${EXCLUDE_ARGS[@]}" \
    "${BACKUP_PATHS[@]}"

# Prune old snapshots - keep 7 daily, 4 weekly, 6 monthly
log "Pruning old snapshots..."
restic forget \
    --keep-daily 7 \
    --keep-weekly 4 \
    --keep-monthly 6 \
    --prune

# Verify backup integrity
log "Verifying backup..."
restic check

log "Backup complete!"
