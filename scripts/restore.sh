#!/bin/bash
# Loss Defender Pro - Restore Script
# Usage: ./restore.sh <backup_file>

set -euo pipefail

# Configuration
DB_NAME="lossdefender"
DB_USER="postgres"
DB_HOST="localhost"
DB_PORT="5432"

if [ $# -ne 1 ]; then
    echo "Usage: $0 <backup_file.sql.gz>"
    echo "Example: $0 /opt/loss-defender-pro/backups/lossdefender_20240115_020000.sql.gz"
    exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "${BACKUP_FILE}" ]; then
    echo "ERROR: Backup file not found: ${BACKUP_FILE}"
    exit 1
fi

echo "Starting restore at $(date)"
echo "Backup file: ${BACKUP_FILE}"

# Verify backup file
echo "Verifying backup file..."
if ! gunzip -t "${BACKUP_FILE}"; then
    echo "ERROR: Backup file is corrupted!"
    exit 1
fi

# Create a temporary database for verification
TEMP_DB="lossdefender_restore_$(date +%s)"
echo "Creating temporary database: ${TEMP_DB}"
createdb -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" "${TEMP_DB}"

# Restore to temporary database
echo "Restoring to temporary database..."
gunzip -c "${BACKUP_FILE}" | psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${TEMP_DB}" -q

if [ $? -ne 0 ]; then
    echo "ERROR: Restore to temporary database failed!"
    dropdb -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" "${TEMP_DB}"
    exit 1
fi

# Verify data integrity
echo "Verifying data integrity..."
TABLE_COUNT=$(psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${TEMP_DB}" -t -c "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';" | xargs)
ROW_COUNTS=$(psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${TEMP_DB}" -c "
    SELECT schemaname, tablename, n_live_tup 
    FROM pg_stat_user_tables 
    WHERE schemaname = 'public' 
    ORDER BY n_live_tup DESC;
")

echo "Tables restored: ${TABLE_COUNT}"
echo "Row counts:"
echo "${ROW_COUNTS}"

# Prompt for confirmation before replacing production
echo ""
echo "=========================================="
echo "VERIFICATION COMPLETE"
echo "Tables: ${TABLE_COUNT}"
echo "=========================================="
echo ""
read -p "Replace production database '${DB_NAME}' with this restore? (yes/no): " CONFIRM

if [ "${CONFIRM}" != "yes" ]; then
    echo "Restore cancelled. Cleaning up temporary database..."
    dropdb -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" "${TEMP_DB}"
    exit 0
fi

# Backup current production database first
CURRENT_BACKUP="/tmp/${DB_NAME}_pre_restore_$(date +%Y%m%d_%H%M%S).sql.gz"
echo "Backing up current production database to ${CURRENT_BACKUP}..."
pg_dump -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" \
    --no-owner --no-privileges --clean --if-exists | gzip > "${CURRENT_BACKUP}"

# Drop and recreate production database
echo "Replacing production database..."
dropdb -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" --if-exists "${DB_NAME}"
createdb -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" "${DB_NAME}"

# Restore to production
echo "Restoring to production database..."
gunzip -c "${BACKUP_FILE}" | psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -q

if [ $? -eq 0 ]; then
    echo "Restore completed successfully at $(date)"
    
    # Run migrations if needed
    echo "Running migrations..."
    cd /opt/loss-defender-pro/backend
    npx prisma migrate deploy
    
    # Restart application
    echo "Restarting application..."
    pm2 restart ldp-api --update-env
    
    echo "Restore completed successfully at $(date)"
else
    echo "ERROR: Restore to production failed!"
    exit 1
fi

# Cleanup
dropdb -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" "${TEMP_DB}"