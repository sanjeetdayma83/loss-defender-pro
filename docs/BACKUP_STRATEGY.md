# Backup strategy
## Neon Postgres: enable PITR; weekly export; branch before migrate
## B2: versioning on; 30-day prior versions; dual-bucket for critical evidence
## Redis: ephemeral
## Drill: restore URL → prisma migrate deploy → login + orders + evidence GET