# Loss Defender Pro — Go-Live Checklist

## Application
- [ ] P0 PR merged and production CI green
- [ ] P1 PR merged and production CI green
- [ ] P2 PR merged and production CI green
- [ ] Database migrations applied with `prisma migrate deploy`
- [ ] Production Flutter web build verified
- [ ] Mobile release builds signed and tested

## Secrets
- [ ] JWT access/refresh secrets are unique production values
- [ ] Marketplace credential encryption key is 32-byte hex
- [ ] SMTP credentials configured and tested
- [ ] B2 credentials configured and tested
- [ ] Marketplace provider credentials configured
- [ ] FRONTEND_ORIGIN is explicitly configured

## Billing / quota
- [ ] Real payment provider credentials configured
- [ ] Webhook signature verification tested
- [ ] Subscription lifecycle tested
- [ ] Plan quotas verified

## Security
- [ ] Permission matrix reviewed by product owner
- [ ] Authentication/authorization E2E tests green
- [ ] Dependency audit clean or accepted findings documented
- [ ] External penetration test completed before public production exposure

## Reliability
- [ ] k6 load profile executed against staging
- [ ] PostgreSQL backup completed
- [ ] Restore drill completed successfully
- [ ] Redis persistence/retention verified
- [ ] Monitoring and alert routing tested
- [ ] `/api/v1/ready` reports ready

## Deployment
- [ ] DNS points to production server
- [ ] TLS certificate valid
- [ ] Nginx config validated
- [ ] Backend/frontend containers healthy
- [ ] Rollback image/tag documented
- [ ] First production smoke test completed
