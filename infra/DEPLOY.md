# ExCloud VPS Deployment (production)

1. Provision Ubuntu LTS VPS (4 vCPU / 8GB RAM min, per NFR §16.1).
2. Install Docker + Docker Compose.
3. Clone this repo, create `backend/.env` and `frontend/.env` with **real** values:
   - `DATABASE_URL` → Neon connection string
   - `B2_*` → real Backblaze B2 bucket/keys
   - `REDIS_URL` → your production Redis (self-hosted on VPS or managed)
   - JWT secrets → generate fresh 32+ char secrets, never reuse dev ones
4. Use a **production compose file without the local `postgres` service**
   (Neon replaces it) — copy `docker-compose.yml`, delete the `postgres` block,
   keep `redis`, `backend`, `frontend`.
5. `docker compose up -d --build`
6. `docker compose exec backend npx prisma migrate deploy`
7. Point Nginx (see `infra/nginx/nginx.conf`) + `certbot --nginx` for SSL.
8. Wire GitHub Actions (see `docs/ROADMAP.md` P1) for zero-downtime redeploys.
