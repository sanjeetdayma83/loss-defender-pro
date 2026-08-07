# Loss Defender Pro — Monorepo

Enterprise Warehouse Intelligence Platform. Rebuilt on a clean architecture per
`Loss_Defender_Pro_Complete_Production_Documentation_v3` and the DFD/Sequence spec.

## Layout

```
loss-defender-pro/
├── backend/      # NestJS + Prisma API (source of truth for business logic)
├── frontend/     # Flutter app — Android, iOS, Web, Windows, macOS, Linux (single codebase)
├── infra/        # nginx config, deployment notes for ExCloud VPS
├── docs/         # copy of the reference spec docs (kept for traceability)
├── setup.ps1     # one-shot bootstrap for Windows — see below
└── docker-compose.yml  # local dev: backend + postgres(local) + redis
```

## One-command setup (Windows)

Download `loss-defender-pro-scaffold.zip` and `setup.ps1` into the same folder, then:

```powershell
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```

This single command will:
1. Extract the zip into `.\loss-defender-pro\`
2. Verify Flutter + Node + git are installed
3. Run `flutter create` for **all platforms** (android, ios, web, windows, macos, linux) into `frontend/`
4. Add the required Flutter packages (dio, secure storage, go_router, riverpod, offline sqlite queue, camera/video) and write the starter architecture (`lib/core`, `lib/features/auth` fully wired to `/auth/login` + `/auth/register`, other feature folders as placeholders)
5. `npm install` the backend + generate the Prisma client
6. `git init` + first commit

**Prerequisites the script checks for and will stop on if missing:** Flutter SDK
(https://docs.flutter.dev/get-started/install/windows), Node.js 20 LTS
(https://nodejs.org). Git is recommended but not required to run the script.

## Status (this scaffold)

✅ Done (P0 — foundation):
- Monorepo structure, Docker Compose, env contracts
- Prisma schema: Company, Warehouse, Station, User, Session, PasswordResetToken,
  EmailVerificationToken, InviteToken, AuditLog (multi-tenant `companyId` on every table)
- Auth module: register, login, refresh (rotation), forgot/reset password, logout,
  session list/revoke — matches §14.3 of the spec
- Tenant isolation guard + RBAC roles guard + audit log interceptor (skeleton)
- Flutter app skeleton: routing (go_router), Dio API client with token injection,
  secure token storage, theme, Login screen wired end-to-end to the backend

⏳ Not yet built (do these next, in this order — see `docs/ROADMAP.md`):
1. Email verification + invite-accept flow wiring (DTOs exist, worker/queue missing)
2. Redis + BullMQ (email/marketplace-sync/evidence/notify workers)
3. Warehouses/Stations/Users CRUD controllers (schema is ready, controllers are stubs)
4. Orders module (ingestion, scanner, assignment)
5. Recording + Upload (B2 multipart) + Evidence generation
6. Claims / Returns
7. Marketplace connect + webhooks
8. Remaining Flutter screens (dashboard, orders, scanner, recording, evidence, claims, returns — currently placeholders)

## Manual local development (if not using setup.ps1)

```bash
cp backend/.env.example backend/.env   # fill in real values later; local defaults work for docker-compose
docker compose up -d postgres redis
cd backend
npm install
npx prisma migrate dev --name init
npm run start:dev
```

Backend runs on `http://localhost:3000/api/v1`.

```bash
cd frontend
flutter create --platforms=android,ios,web,windows,macos,linux .   # if not already created
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000/api/v1
```

## Pointing at real infra (Neon + Backblaze B2 + ExCloud)

This scaffold is written so that **only environment variables change** between local
and production — no code changes needed:

- `DATABASE_URL` → swap local postgres URL for your Neon connection string (`sslmode=require`)
- `B2_*` → your real Backblaze B2 bucket/keys (already used even in local dev — B2 doesn't
  need to be "local", it's cheap to just use a dev bucket)
- `REDIS_URL` → local redis for dev, managed/self-hosted Redis on ExCloud for prod
- Flutter: `--dart-define=API_BASE_URL=...` at build/run time — same code, different backend
- See `infra/DEPLOY.md` for the ExCloud + Nginx + Docker Compose production steps

## Pushing this to your existing GitHub repo

You already have `https://github.com/sanjeetdayma83/loss-defender-pro-backend.git`.
Recommended: keep that repo for backend-only history, OR repoint it as the new monorepo
root (your call). From inside this folder, on your machine:

```bash
git init
git add .
git commit -m "chore: fresh monorepo scaffold (auth + multi-tenant foundation)"

# Option A: reuse existing repo as the new monorepo
git remote add origin https://github.com/sanjeetdayma83/loss-defender-pro-backend.git
git branch -M main
git push -u origin main --force   # ⚠ only if you're OK replacing old history; otherwise push to a new branch first

# Option B (safer): push to a new branch, review, then merge
git checkout -b rebuild/v3-architecture
git push -u origin rebuild/v3-architecture
```

I'd recommend **Option B** — push to a branch, open a PR against `main`, review, then merge.
That way your old deployed code stays safe as a rollback point.
