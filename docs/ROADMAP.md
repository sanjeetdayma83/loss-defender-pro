# Build Roadmap — STATUS SYNC (2026-08)

## DONE (verified by regression)
- Auth login/register/JWT/refresh, invite+tempPassword (dev)
- Account lock fields + failedLoginCount (see auth.service)
- Forgot/reset/verify-email/accept-invite endpoints
- Multi-tenant companyId, warehouses, users, orders, scanner
- Recordings start/pause/resume/checksum/stop
- Evidence on stop + frame placeholders
- Claims/Returns workflows
- Marketplace connections + sync stub + webhooks
- Storage B2 presign (configured when keys set)
- Health, metrics, CI, unit tests (12), load smoke

## P0 remaining (harden)
- [ ] SMTP real delivery (without SMTP_HOST → DEV MAIL log — OK for demo)
- [ ] SanitizeInterceptor production strip of tempPassword/devCode
- [ ] Audit coverage on all mutations (interceptor / per-service)
- [ ] Recording segment PUT to B2 + register segment E2E from Flutter
- [ ] Real FFmpeg frame extract (placeholders OK for MVP demo)
- [ ] Full order transition matrix automated tests

## P1+
- Real marketplace SP-API, offline queue flush, evidence viewer, WebSocket floor view
