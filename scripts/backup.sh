#!/bin/bash
# Loss Defender Pro - Backup Script
# Run daily via cron: 0 2 * * * /opt/loss-defender-pro/scripts/backup.sh

set -euo pipefail

# Configuration
BACKUP_DIR="/opt/loss-defender-pro/backups"
DB_NAME="lossdefender"
DB_USER="postgres"
DB_HOST="localhost"
DB_PORT="5432"
RETENTION_DAYS=30
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/lossdefender_${DATE}.sql.gz"

# Create backup directory
mkdir -p "${BACKUP_DIR}"

echo "Starting backup at $(date)"

# Dump database
echo "Dumping database..."
pg_dump -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" \
    --no-owner --no-privileges --clean --if-exists \
    | gzip > "${BACKUP_FILE}"

if [ $? -eq 0 ]; then
    echo "Database dump completed: ${BACKUP_FILE}"
    
    # Verify backup
    if gunzip -t "${BACKUP_FILE}"; then
        echo "Backup verification passed"
    else
        echo "ERROR: Backup verification failed!"
        exit 1
    fi
else
    echo "ERROR: Database dump failed!"
    exit 1
fi

# Cleanup old backups
echo "Cleaning up backups older than ${RETENTION_DAYS} days..."
find "${BACKUP_DIR}" -name "lossdefender_*.sql.gz" -mtime +${RETENTION_DAYS} -delete

echo "Backup completed at $(date)"
echo "Backup location: ${BACKUP_FILE}"

# Optional: Upload to S3/remote storage
# aws s3 cp "${BACKUP_FILE}" s3://your-bucket/backups/