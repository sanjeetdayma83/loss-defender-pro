#!/usr/bin/env bash
set -euo pipefail
cp -n backend/.env.example backend/.env 2>/dev/null || true
docker compose up -d redis 2>/dev/null || true
(cd backend && npm install && npx prisma generate)
(cd frontend && flutter pub get) 2>/dev/null || true
echo "Configure backend/.env then: cd backend && npm run start:dev"