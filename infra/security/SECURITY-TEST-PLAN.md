# Security / penetration test plan

Before public production exposure, test:

1. Authentication: brute-force controls, refresh-token rotation/reuse, logout revocation, password reset and email verification.
2. Authorization: every role against every protected route; cross-tenant IDOR attempts on companies, users, warehouses, orders, recordings and evidence.
3. Marketplace: encrypted credentials, webhook HMAC replay/tampering, SSRF through configurable connector URLs.
4. Storage: tenant key traversal, signed URL expiry, upload ownership, multipart ownership.
5. WebSocket: invalid/expired JWT, forged company room, origin restrictions.
6. API: request-size limits, rate limits, malformed JSON, parameter pollution and error leakage.
7. Infrastructure: TLS, Nginx headers, exposed ports, container privileges, secrets in images/logs.

Record findings with severity, affected endpoint, reproduction, remediation and retest result. A clean internal test is not a substitute for an independent penetration test for a public SaaS launch.
