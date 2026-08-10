# Rollback
1. `git checkout <previous-sha>`
2. `docker compose -f docker-compose.prod.yml up -d --build`
3. `docker compose exec backend npx prisma migrate resolve` only if migration broke — prefer forward-fix migrations
4. Keep previous image tag: `docker tag ldp-backend:prev` before deploy
