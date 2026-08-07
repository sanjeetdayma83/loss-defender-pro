# Build Roadmap (mirrors §19 of the Production Documentation)

Work top-to-bottom. Each item should ship with: API + validation + RBAC guard +
audit log + tests, per the spec's "no feature is complete until all layers are done" rule.

## P0 — Foundation (this scaffold covers the skeleton; you/Claude Code fill in logic + tests)
- [x] Prisma schema: Company, Warehouse, Station, User, Session, tokens, AuditLog
- [x] Auth: register / login / refresh (rotation) / forgot / reset / logout / sessions
- [ ] Email verification actually wired to a mail worker (currently a TODO stub)
- [ ] Multi-tenant isolation verified on every future query (guard exists, must be used everywhere)
- [ ] Private B2 bucket + signed URL helper module
- [ ] `/api/v1` versioning + OpenAPI publish (Swagger module — not yet added)

## P1
- [ ] Redis + BullMQ: email, marketplace-sync, evidence, notify queues
- [ ] WebSocket gateway (live packing/recording status)
- [ ] Full audit log framework wired into every mutating controller
- [ ] Marketplace connect + webhook receivers (Amazon/Flipkart/Meesho)
- [ ] CI/CD (GitHub Actions: lint, test, build, migrate, deploy)

## P2
- [ ] RBAC permission-matrix UI + fine-grained guards (roles exist, permissions table doesn't yet)
- [ ] Analytics KPI endpoints + admin dashboard
- [ ] Billing & quota enforcement

## P3
- [ ] AI verification workers
- [ ] WhatsApp / SMS providers

## Domain modules still needed (schema + controllers not yet started)
Orders, Scanner, Recording, Upload (B2 multipart), Evidence, Dispatch, Claims, Returns.
Reference: `docs/Loss_Defender_Pro_DataFlow_Sequence_Diagrams_v3.md` §7–14 for the exact
sequence each of these must follow.

## Flutter screens still needed
`lib/features/{dashboard,orders,scanner,recording,evidence,claims,returns}` are placeholder
widgets. Build each against the corresponding backend module above, in the same order —
a screen wired to a non-existent endpoint is wasted work.
