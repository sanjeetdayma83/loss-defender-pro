#!/bin/bash
# Loss Defender Pro - Production Deployment Script
# Usage: ./deploy.sh [version|latest]

set -euo pipefail

PROJECT_DIR="/var/www/loss-defender-pro"
BACKEND_DIR="${PROJECT_DIR}/backend"
FRONTEND_DIR="${PROJECT_DIR}/frontend"
VERSION="${1:-latest}"

echo "=========================================="
echo "Loss Defender Pro Deployment"
echo "Version: ${VERSION}"
echo "=========================================="

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Check if running as correct user
if [ "$(whoami)" != "root" ] && [ "$(whoami)" != "www-data" ]; then
    log "WARNING: Not running as root or www-data"
fi

cd "${PROJECT_DIR}"

# 1. Stash any local changes
log "Stashing local changes..."
git stash

# 2. Pull latest code
log "Pulling latest code from origin/main..."
git fetch origin
git checkout main
git pull origin main

# 3. Backend deployment
log "Deploying backend..."
cd "${BACKEND_DIR}"

# Install dependencies
log "Installing backend dependencies..."
npm ci

# Generate Prisma client
log "Generating Prisma client..."
npx prisma generate

# Run database migrations
log "Running database migrations..."
npx prisma migrate deploy

# Build backend
log "Building backend..."
npm run build

# 4. Frontend deployment
log "Deploying frontend..."
cd "${FRONTEND_DIR}"

log "Cleaning Flutter build..."
flutter clean

log "Getting Flutter dependencies..."
flutter pub get

log "Building Flutter web (release)..."
flutter build web --release

# 5. Restart services
log "Restarting backend API..."
pm2 restart ldp-api --update-env

log "Verifying deployment..."
sleep 3

# Health check
if curl -sf "https://api.lossdefender.in/api/v1/health" > /dev/null; then
    log "��� API health check passed"
else
    log "��� API health check FAILED"
    exit 1
fi

if curl -sf "https://lossdefender.in/" > /dev/null; then
    log "��� Frontend health check passed"
else
    log "��� Frontend health check FAILED"
    exit 1
fi

log "=========================================="
log "Deployment completed successfully!"
log "Version: ${VERSION}"
log "Timestamp: $(date)"
log "=========================================="