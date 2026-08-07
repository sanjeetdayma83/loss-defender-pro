# Loss Defender Pro — Complete Production Documentation Suite

**Enterprise Warehouse Intelligence Platform**

---

| | |
|:---|:---|
| **Document Version** | 3.0 |
| **Status** | Production Ready Blueprint |
| **Target Release** | v1.0 |
| **Platform Owner** | PrimeCore Technologies |
| **Infrastructure** | NestJS · Neon PostgreSQL · Backblaze B2 · ExCloud VPS |
| **Clients** | Flutter (Mobile/Desktop) · React/Next.js (Admin) |
| **Date** | 05 August 2026 |

> **CONFIDENTIAL — For Internal Engineering Use Only**

---

## Table of Contents

1. Business Requirements Document (BRD) & Project Charter
2. Product Requirements Document (PRD)
3. Software Requirements Specification (SRS) — Introduction & Scope
4. Functional Requirements Specification (FRS)
5. Non-Functional Requirements (NFR)
6. System Architecture Document (HLD)
7. Repository Audit & Current State Analysis
8. Database Design & ER Model
9. Authentication, RBAC & Security Model
10. Core Domain Modules (Company, Warehouse, User, Orders)
11. Recording, Evidence, Scanner & Upload Engine
12. Claims, Returns & Marketplace Integration
13. Notifications, Analytics, Admin & Billing
14. Backend API Specification & JSON Contracts
15. Frontend Specification (Flutter + Web Admin)
16. Deployment, Infrastructure & DevOps
17. Security Checklist & Threat Model
18. Testing Strategy & Go-Live Checklist
19. Production Improvement Roadmap
20. Future Enterprise Roadmap
- Appendix A — Glossary & Domain Model
- Appendix B — Environment & Configuration Reference

---

## 1. Business Requirements Document (BRD) & Project Charter

### 1.1 Purpose

This document defines the business problem, goals, stakeholders, success criteria, and scope for transforming Loss Defender Pro into a production-ready Enterprise Warehouse Intelligence SaaS platform. It serves as the master reference for Product, Backend, Flutter, Web Admin, DevOps, QA, AI, and Marketplace integration teams.

### 1.2 Business Problem

E-commerce sellers and warehouses lose significant revenue every year due to:

- **Missing / wrong product in shipment** — operator packing errors leading to customer complaints
- **Courier theft and customer fraud** — packages tampered with or falsely reported as missing
- **Marketplace false claims and fake returns** — sellers penalised for disputes they cannot disprove
- **Wrong dispatch and operator mistakes** — incorrect items, quantities, or addresses shipped
- **Absence of tamper-proof digital evidence** — no verifiable proof of what was packed and when

**Loss Defender Pro solves this** by creating complete, timestamped, operator-linked, GPS-aware digital video evidence of every packing and dispatch operation, enabling rapid claim defence and return investigation.

### 1.3 Product Vision

> *Become the operating system of warehouse verification* — a cloud-native, multi-tenant, offline-first, mobile-first, API-first, AI-ready, event-driven, enterprise-secure SaaS platform.

### 1.4 Target Customers

| Segment | Size | Use Case |
|:---|:---|:---|
| Small & Medium Sellers | 1–10 operators | Basic order verification and claim defence |
| Medium & Enterprise Warehouses | 50–500 operators | Full warehouse management with stations |
| 3PL Companies | Multi-tenant | Managing multiple client warehouses |
| Marketplace Fulfilment Centres | 1000+ operators | High-volume, automated verification |
| Manufacturers & Distributors | B2B focus | Shipment proof for bulk orders |
| Retail Chains | Omni-channel | Unified online + store fulfilment |

### 1.5 Business Goals

#### Primary Goals

| # | Goal | KPI | Target |
|:---|:---|:---|:---|
| 1 | Reduce RTO and false claims | Claim win rate | >85% |
| 2 | Eliminate wrong dispatch | Packing accuracy | >99.5% |
| 3 | Improve packing accuracy | SKU mismatch rate | <0.5% |
| 4 | Generate irrefutable digital evidence | Evidence coverage | 100% of packed orders |
| 5 | Increase warehouse productivity | Orders per hour | +30% vs baseline |
| 6 | Reduce investigation time | Mean time to resolve | <5 minutes |

#### Secondary Goals

- Deep marketplace integration (Amazon, Flipkart, Meesho, Shopify, WooCommerce)
- AI-assisted verification (object detection, OCR, anomaly detection)
- Warehouse & operator analytics with productivity scoring
- Automated reports & customer trust dashboards
- Full enterprise SaaS monetisation with tiered plans

### 1.6 Stakeholders

| Role | Responsibility | Primary Concern |
|:---|:---|:---|
| **Platform Owner (PrimeCore)** | Overall product, billing, global features | Revenue, retention, platform stability |
| **Company Owner / Admin** | Tenant configuration, users, warehouses, marketplace accounts | Operational efficiency, cost control |
| **Warehouse Manager** | Orders, operators, stations, dispatch, claims | Throughput, accuracy, labour management |
| **Supervisor** | Live monitoring, recording approval, alerts | Quality control, real-time visibility |
| **Packing Operator** | Scan, record, upload, complete dispatch | Speed, ease of use, minimal friction |
| **QC Operator** | Review recordings, approve/reject packing | Quality standards, compliance |
| **Claims Executive** | Evidence search, marketplace proof upload, claim lifecycle | Win rate, response time |
| **Viewer** | Read-only access | Reporting, oversight |
| **Super Admin** | SaaS platform management, plans, feature flags | Platform health, multi-tenant isolation |

### 1.7 Success Criteria (Production Go-Live)

```
☑ 99.9% uptime (measured via external probe)
☑ Secure JWT + refresh rotation + multi-device session management
☑ Strict multi-tenant data isolation (verified via penetration test)
☑ End-to-end video evidence pipeline (< 2 min from stop to evidence ready)
☑ Marketplace order sync + claims + returns (3+ marketplaces)
☑ Full RBAC with audit logs (every critical mutation tracked)
☑ Secure private Backblaze B2 storage with signed URLs (TTL <= 15 min)
☑ Neon PostgreSQL production reliability (connection pooling, backups)
☑ ExCloud VPS deployment with Docker + Nginx + SSL (A+ rating)
☑ Zero hardcoded credentials (all secrets via env / secret manager)
☑ CI/CD pipeline with automated tests and zero-downtime deploys
```

### 1.8 In-Scope vs Out-of-Scope

| In Scope (MVP to Production) | Out of Scope / Future |
|:---|:---|
| Auth (email, forgot, OTP, sessions) | Full 2FA / hardware keys (v1.1) |
| Company, Warehouse, User, RBAC | Advanced billing automation (v1.2) |
| Orders lifecycle + scanner + recording | IoT smart cameras (v2.0) |
| Evidence generation + claims + returns | Multi-region active-active (v2.0) |
| Marketplace connect (Amazon/Flipkart/Meesho core) | Full LLM claim assistant (v1.3) |
| Notifications (email, push, in-app) | Slack/Teams advanced rules (v1.2) |
| Basic analytics & reports | Warehouse heatmaps / live video wall (v2.0) |
| Docker + Nginx + CI/CD on ExCloud | Kubernetes multi-cluster (v2.0) |


---

## 2. Product Requirements Document (PRD)

### 2.1 Product Overview

Loss Defender Pro combines **Warehouse Management, Recording System, Order Verification, Barcode Validation, Marketplace Synchronisation, Claims Management, Returns Investigation, AI Verification, and Enterprise Analytics** into one unified platform.

### 2.2 Supported Platforms

| Layer | Technology | Role |
|:---|:---|:---|
| Mobile App | Flutter (Android primary) | Packing operators, supervisors |
| Desktop | Flutter Desktop (Windows) | Supervisor mode, bulk review |
| Web Admin | React / Next.js (recommended) | Company admin, analytics, billing, marketplace |
| Backend API | NestJS + TypeScript | REST + WebSocket + workers |
| Database | Neon PostgreSQL | Primary transactional store |
| Object Storage | Backblaze B2 (S3-compatible) | Videos, images, evidence |
| Server | ExCloud VPS (Ubuntu LTS) | Docker, Nginx, PM2 |
| Cache / Queue | Redis (recommended) | Sessions, OTP, BullMQ, rate-limit |

### 2.3 Core Product Modules & Priority

| Module | Purpose | Priority | Status Target |
|:---|:---|:---|:---|
| Authentication | Login, security, sessions | Critical | v1.0 |
| Company Management | Multi-tenant organisations | Critical | v1.0 |
| Warehouse Management | Warehouses & packing stations | Critical | v1.0 |
| User Management | Employees & operators | Critical | v1.0 |
| Role & Permission (RBAC) | Enterprise access control | Critical | v1.0 |
| Orders | Marketplace order lifecycle | Critical | v1.0 |
| Scanner | Barcode & QR validation | Critical | v1.0 |
| Recording | Video capture sessions | Critical | v1.0 |
| Evidence | Digital proof generation | Critical | v1.0 |
| Upload | Secure media upload | Critical | v1.0 |
| Dispatch | Shipment completion | Critical | v1.0 |
| Claims | Marketplace dispute management | High | v1.0 |
| Returns | Return investigation | High | v1.0 |
| Marketplace | Amazon / Flipkart / Meesho sync | High | v1.0 |
| Notifications | Email, Push, WhatsApp, In-App | High | v1.0 |
| Reports & Analytics | KPIs & dashboards | High | v1.1 |
| Audit Logs | Compliance tracking | High | v1.0 |
| Settings | Tenant configuration | High | v1.0 |
| Billing | Subscription management | Medium | v1.1 |
| AI Services | Automated verification | Future | v1.2+ |

---

## 3. Software Requirements Specification (SRS) — Introduction & Scope

### 3.1 Document Purpose

This SRS defines every functional and technical requirement required to ship a production-ready Loss Defender Pro. Every feature implemented must comply with this document across:

- UI/UX Design
- Backend API Development
- Database Schema & Migrations
- Input Validation & Business Rules
- Security & Authentication
- Audit Logging
- Notification Delivery
- Error Handling & Recovery
- Offline Support
- Analytics & Reporting

### 3.2 Product Type Attributes

| Attribute | Description | Implementation |
|:---|:---|:---|
| **Cloud Native SaaS** | Multi-tenant, subscription-based | Company-scoped data, plan tiers |
| **Multi Tenant** | Strict company isolation | `companyId` on every query, JWT claim |
| **Offline First** | Works without continuous connectivity | Flutter local queue, resumable upload |
| **Mobile First** | Optimised for warehouse operators | Large touch targets, minimal steps |
| **API First** | All clients consume same API | Versioned REST, OpenAPI contract |
| **AI Ready** | Extensible for computer vision | Hook-based evidence processing |
| **Event Driven** | Async notifications and audit | Domain events + BullMQ workers |
| **Enterprise Secure** | Production-grade security | OWASP compliance, encryption, RBAC |
| **Horizontally Scalable** | Scale workers independently | Stateless API, queue-based workers |

### 3.3 Functional Module Hierarchy

```
Loss Defender Pro
├── Authentication
│   ├── Register / Login / Logout
│   ├── Forgot / Reset Password
│   ├── OTP Verification
│   ├── Session Management
│   └── Token Refresh & Rotation
├── Organization / Company
│   ├── Profile & Branding
│   ├── Subscription & Billing
│   └── Storage Quotas
├── Warehouse & Packing Station
│   ├── Warehouse CRUD
│   ├── Station Management
│   └── Device Assignment
├── Users & Roles (RBAC)
│   ├── Invitation Flow
│   ├── Role Assignment
│   └── Permission Matrix
├── Marketplace
│   ├── Account Connection (OAuth/API-key)
│   ├── Webhook Handling
│   └── Order Sync
├── Orders
│   ├── Manual Create
│   ├── Marketplace Sync
│   ├── Assignment
│   └── Status Lifecycle
├── Scanner
│   ├── Barcode Validation
│   ├── Duplicate Detection
│   └── SKU Matching
├── Recording
│   ├── Start / Pause / Stop
│   ├── Segment Management
│   └── Offline Queue
├── Evidence & Upload
│   ├── Multipart Upload
│   ├── Frame Extraction
│   └── Signed URL Generation
├── Dispatch
│   ├── AWB Capture
│   ├── Courier Selection
│   └── Status Transition
├── Returns & Claims
│   ├── Claim Creation
│   ├── Evidence Attachment
│   ├── Decision Workflow
│   └── Marketplace Reply
├── Dashboard / Reports / Analytics
│   ├── KPI Aggregation
│   ├── Operator Productivity
│   └── Warehouse Utilisation
├── Notifications
│   ├── Email / SMS / Push
│   ├── WhatsApp
│   └── In-App
├── Audit Logs
│   ├── Critical Mutation Tracking
│   └── Compliance Export
├── Billing & Settings
│   ├── Plan Management
│   ├── Usage Metering
│   └── Invoice Generation
└── AI Services
    ├── Object Detection
    ├── OCR
    └── Anomaly Detection
```


---

## 4. Functional Requirements Specification (FRS)

> **Every feature below must be implemented with UI + Backend API + Database + Validation + Security + Audit Log + Notification + Error Handling + Offline Support + Analytics. No feature is complete until all layers are production-ready.**

### 4.1 Authentication Module (Critical)

#### Features

| # | Feature | Description | Priority |
|:---|:---|:---|:---|
| 1 | Email + Password login | Standard credential-based authentication | P0 |
| 2 | Google OAuth (optional v1.1) | Social login for reduced friction | P2 |
| 3 | Forgot / Reset Password | Secure token-based password reset | P0 |
| 4 | OTP verification (email/SMS) | Two-step verification for sensitive actions | P1 |
| 5 | JWT Access Token + Refresh Token rotation | Short-lived access, rotating refresh | P0 |
| 6 | Logout (single & all devices) | Session revocation capabilities | P0 |
| 7 | Device session tracking | Per-device session management | P1 |
| 8 | Remember Me | Extended session for trusted devices | P1 |
| 9 | Multi-device support with active session list | View and manage all active sessions | P1 |
| 10 | Account lock after failed attempts | Brute-force protection | P0 |

#### Functional Flow

```mermaid
flowchart TD
    A["Open App"] --> B{"Session Exists?"}
    B -->|YES| C["Validate Token"]
    C -->|Valid| D["Role-Specific Dashboard"]
    C -->|Expired| E["Silent Refresh"]
    E -->|Success| D
    E -->|Failure| F["Login Screen"]
    B -->|NO| F
    F --> G["Authenticate"]
    G -->|Success| D
    G -->|Failure| H["Error: Invalid Credentials"]
    H --> F
```

#### Validation Rules

| Rule | Requirement | Error Response |
|:---|:---|:---|
| Email format | Valid RFC 5322 format | 400 — "Invalid email format" |
| Password length | Minimum 8 characters | 400 — "Password must be at least 8 characters" |
| Password complexity | At least 1 uppercase, 1 lowercase, 1 number (recommended) | 400 — "Password does not meet complexity requirements" |
| Failed login threshold | 5 consecutive failures -> 15 min lock | 429 — "Account locked. Try again in X minutes" |
| JWT presence | Required on all protected routes | 401 — "Authentication required" |
| Refresh token | Required for token renewal | 401 — "Invalid or expired refresh token" |

#### Success Output

```json
{
  "success": true,
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1NiIs...",
    "refreshToken": "dGhpcyBpcyBhIHJlZnJlc2g...",
    "expiresIn": 900,
    "tokenType": "Bearer",
    "user": {
      "id": "uuid",
      "name": "John Doe",
      "email": "john@company.com",
      "role": "packing_operator",
      "permissions": ["orders.read", "recordings.create", "scanner.use"],
      "avatar": "https://...",
      "status": "active",
      "lastLoginAt": "2026-08-05T10:30:00Z"
    },
    "company": {
      "id": "uuid",
      "name": "Acme Warehouse Pvt Ltd",
      "plan": "professional",
      "status": "active",
      "storageUsed": 157286400,
      "storageQuota": 10737418240,
      "logo": "https://..."
    }
  }
}
```

### 4.2 Organisation / Company Module

> Strict multi-tenant isolation. Every company is completely isolated at the data layer.

#### Features

| # | Feature | Description |
|:---|:---|:---|
| 1 | Create Company | Initial registration with owner |
| 2 | Update Profile | Modify company details, branding |
| 3 | Suspend / Activate | Administrative control over tenant |
| 4 | Subscription & Plan Management | Upgrade/downgrade plans |
| 5 | Storage Quota | Track and enforce storage limits |
| 6 | Warehouse Limit | Enforce plan-based warehouse count |
| 7 | User Limit | Enforce plan-based user count |
| 8 | Branding | Logo, primary colour, custom domain (future) |
| 9 | Marketplace Access Flags | Enable/disable marketplace integrations |

#### Company Fields

| Field | Type | Required | Notes |
|:---|:---|:---|:---|
| `id` | UUID | Auto | Primary key |
| `companyName` | String | Yes | Display name |
| `gst` | String | No | GST number (India) |
| `pan` | String | No | PAN number (India) |
| `address` | JSON | No | Structured address |
| `phone` | String | Yes | Primary contact |
| `email` | String | Yes | Unique globally |
| `website` | String | No | Company website |
| `timezone` | String | Yes | Default: Asia/Kolkata |
| `currency` | String | Yes | Default: INR |
| `storageUsed` | BigInt | Auto | Bytes used in B2 |
| `plan` | Enum | Yes | free / starter / professional / enterprise |
| `logo` | String | No | B2 signed URL |
| `status` | Enum | Auto | active / suspended / deleted |
| `createdAt` | Timestamp | Auto | — |
| `updatedAt` | Timestamp | Auto | — |

#### Validation Rules

- **Unique email:** No duplicate company emails globally
- **Unique GST:** Where applicable, GST must be unique
- **Unique company identifier:** Auto-generated slug or custom domain

### 4.3 Warehouse Module

> Every company may own multiple warehouses. Each warehouse contains stations, users, devices, orders, and evidence.

#### Warehouse Fields

| Field | Type | Required | Notes |
|:---|:---|:---|:---|
| `id` | UUID | Auto | Primary key |
| `companyId` | UUID | Yes | FK -> Company |
| `name` | String | Yes | Display name |
| `code` | String | Yes | Unique per company |
| `address` | JSON | Yes | Full address |
| `city` | String | Yes | — |
| `state` | String | Yes | — |
| `country` | String | Yes | Default: India |
| `timezone` | String | Yes | Override company default |
| `status` | Enum | Yes | active / inactive / maintenance |
| `createdAt` | Timestamp | Auto | — |

#### Packing Station

| Field | Type | Required | Notes |
|:---|:---|:---|:---|
| `id` | UUID | Auto | Primary key |
| `warehouseId` | UUID | Yes | FK -> Warehouse |
| `stationName` | String | Yes | Display name |
| `stationId` | String | Yes | Unique per warehouse |
| `camera` | JSON | No | Camera config |
| `scanner` | JSON | No | Scanner config |
| `printer` | JSON | No | Printer config |
| `status` | Enum | Yes | Online / Offline / Maintenance / Inactive |
| `lastHeartbeatAt` | Timestamp | No | For online detection |

### 4.4 User Management Module

#### Functions

| # | Function | Description | Actor |
|:---|:---|:---|:---|
| 1 | Create / Invite User | Send invitation email with token | Admin |
| 2 | Disable User | Soft-disable account | Admin |
| 3 | Delete User | Hard or soft delete | Admin |
| 4 | Reset Password | Force password reset | Admin / Self |
| 5 | Assign Role | Change user permissions | Admin |
| 6 | Assign Warehouse | Move user to different warehouse | Manager |
| 7 | Assign Station | Assign to packing station | Manager |

#### User Fields

| Field | Type | Required | Notes |
|:---|:---|:---|:---|
| `id` | UUID | Auto | Primary key |
| `companyId` | UUID | Yes | FK -> Company |
| `employeeId` | String | No | Internal ID |
| `name` | String | Yes | Full name |
| `phone` | String | Yes | Unique per company |
| `email` | String | Yes | Unique globally |
| `role` | Enum | Yes | See RBAC table |
| `warehouseId` | UUID | No | FK -> Warehouse |
| `stationId` | UUID | No | FK -> Station |
| `status` | Enum | Auto | Pending -> Active -> Suspended -> Deleted |
| `profilePhoto` | String | No | B2 signed URL |
| `joiningDate` | Date | No | — |
| `lastLoginAt` | Timestamp | No | — |
| `failedLoginCount` | Int | Auto | Reset on success |
| `lockedUntil` | Timestamp | No | Account lock expiry |

#### User Status Machine

```mermaid
stateDiagram-v2
    [*] --> Pending: Admin invites
    Pending --> Active: User accepts invite
    Active --> Suspended: Admin suspends
    Suspended --> Active: Admin reactivates
    Active --> Deleted: Admin deletes
    Suspended --> Deleted: Admin deletes
    Pending --> Deleted: Admin cancels invite
```

#### Invitation Flow

```mermaid
sequenceDiagram
    participant A as Admin
    participant API as Backend
    participant DB as Database
    participant EW as Email Worker
    participant U as New User

    A->>API: POST /users/invite
    API->>DB: INSERT user (status=Pending)
    API->>DB: INSERT invite_token
    API->>EW: enqueue invite email
    EW->>U: Send invite link
    U->>API: GET /invite/:token (validate)
    API-->>U: Show company + role
    U->>API: POST /invite/:token/accept {password}
    API->>DB: UPDATE user status=Active
    API->>DB: hash password
    API->>API: Issue JWT pair
    API-->>U: 200 {tokens, user, company}
```

### 4.5 RBAC — Enterprise Roles

| Role | Key Permissions | Data Scope |
|:---|:---|:---|
| **Super Admin** | All companies, billing, feature flags, global analytics | Global |
| **Company Admin / Owner** | Company profile, warehouses, users, marketplace, subscription | Own company |
| **Warehouse Manager** | Orders, operators, stations, recordings, dispatch, claims, returns | Assigned warehouse(s) |
| **Supervisor** | Approve/reject recordings, alerts, operator performance, device health | Assigned warehouse(s) |
| **Packing Operator** | Scan, record, upload, verify, complete dispatch | Assigned station |
| **QC Operator** | Review recording, approve/reject packing, remarks | Assigned warehouse(s) |
| **Claims Executive** | Search evidence, download, upload marketplace proof, manage claims/returns | Own company |
| **Marketplace Manager** | Connect accounts, sync orders, mapping rules | Own company |
| **Viewer** | Read-only across assigned warehouses | Assigned warehouse(s) |
| **Auditor / AI Reviewer** | Audit logs, AI job review (future) | Own company |

#### Permission Matrix (Sample)

| Permission | Owner | Manager | Supervisor | Operator | QC | Claims | Viewer |
|:---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| `companies.read` | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| `companies.update` | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| `warehouses.crud` | ✓ | ✓* | ✗ | ✗ | ✗ | ✗ | ✗ |
| `users.invite` | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| `users.read` | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ | ✓* |
| `orders.read` | ✓ | ✓ | ✓ | ✓ | ✗ | ✓ | ✓* |
| `orders.assign` | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ |
| `scanner.use` | ✓ | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ |
| `recordings.create` | ✓ | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ |
| `recordings.review` | ✓ | ✓ | ✓ | ✗ | ✓ | ✗ | ✗ |
| `evidence.read` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓* |
| `claims.decide` | ✓ | ✓ | ✗ | ✗ | ✗ | ✓ | ✗ |
| `audit.read` | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ |

> *✓* = scoped to assigned warehouses only


---

## 5. Non-Functional Requirements (NFR)

### 5.1 Performance

| Metric | Target | Measurement |
|:---|:---|:---|
| API p95 latency (CRUD) | < 300ms | New Relic / Datadog |
| API p95 latency (auth) | < 150ms | New Relic / Datadog |
| Video segment upload | Resume support for files > 500MB | Client-side test |
| List endpoint pagination | Default 20, max 100 | API contract |
| Dashboard KPI load | < 2s with Redis cache | Lighthouse |
| Search evidence | < 500ms for 30-day window | Load test |

### 5.2 Scalability

| Aspect | Strategy |
|:---|:---|
| API servers | Horizontal scaling of NestJS instances behind Nginx |
| Background jobs | Isolated workers: AI, email, marketplace sync, evidence |
| Queue system | Redis-backed BullMQ with separate queues per job type |
| Database | Neon PostgreSQL with connection pooling (PgBouncer) |
| Storage | Backblaze B2 with lifecycle rules for archival |
| Cache | Redis for sessions, OTP, rate limits, KPI cache |

### 5.3 Availability

| Target | 99.9% uptime |
|:---|:---|
| Health checks | `/health` (liveness), `/ready` (readiness) |
| Graceful degradation | Non-critical services (analytics, AI) can fail without affecting core packing flow |
| Recovery time | < 5 minutes for automated recovery |

### 5.4 Security

| Layer | Control |
|:---|:---|
| Transport | TLS 1.3 everywhere |
| Authentication | JWT short-lived (15 min) + refresh rotation + blacklist |
| Headers | Helmet middleware (HSTS, CSP, X-Frame-Options) |
| Rate limiting | Per IP (100 req/min) + per user (1000 req/hour) |
| Input validation | class-validator / class-transformer |
| Storage | Private B2 buckets + signed URLs (5–15 min TTL) |
| Secrets | Environment variables only; never in code or client bundles |

### 5.5 Offline & Resilience

| Feature | Implementation |
|:---|:---|
| Flutter offline queue | Local SQLite for recordings & scans |
| Resumable upload | Multipart with checksum verification |
| Idempotent APIs | Idempotency keys for POST/PUT operations |
| Marketplace sync retry | Exponential backoff: 1s, 2s, 4s, 8s, 16s, 32s, then DLQ |
| Circuit breaker | Fail marketplace sync after 5 consecutive errors |

### 5.6 Observability

| Signal | Tool | Data |
|:---|:---|:---|
| Logs | Structured JSON (Winston/Pino) | Request ID, user, action, duration |
| Errors | Sentry / Rollbar | Stack trace, context, user impact |
| Metrics | Prometheus / Grafana | Request rate, latency, queue depth, DB connections |
| Audit | Database table | Every critical action with before/after state |
| Traces | OpenTelemetry | End-to-end request flow |

---

## 6. System Architecture Document (High-Level Design)

### 6.1 Logical Architecture

```mermaid
flowchart TB
    subgraph Clients["CLIENTS"]
        FL["Flutter App (Android / Desktop)"]
        WA["Web Admin (React / Next.js)"]
    end

    subgraph Edge["EDGE LAYER"]
        CF["Cloudflare (CDN / WAF / DNS)"]
    end

    subgraph API["API LAYER"]
        NG["Nginx (SSL / Reverse Proxy)"]
        NS["NestJS API (REST + WebSocket)"]
    end

    subgraph Data["DATA LAYER"]
        NEON["Neon PostgreSQL (Primary Data)"]
        REDIS["Redis (Cache / OTP / Queues)"]
        B2["Backblaze B2 (Videos / Images)"]
    end

    subgraph Workers["WORKER LAYER"]
        W1["Email Worker"]
        W2["Marketplace Sync Worker"]
        W3["AI Worker"]
        W4["Evidence Worker"]
        W5["Notification Worker"]
    end

    subgraph External["EXTERNAL SERVICES"]
        SMTP["SMTP / SendGrid"]
        FCM["Firebase Cloud Messaging"]
        MKT["Marketplace APIs (Amazon / Flipkart / Meesho)"]
        WA_API["WhatsApp Business API"]
    end

    FL -->|HTTPS / WSS| CF
    WA -->|HTTPS| CF
    CF --> NG
    NG --> NS

    NS --> NEON
    NS --> REDIS
    NS -->|Signed URLs| B2

    REDIS -->|BullMQ Jobs| W1
    REDIS -->|BullMQ Jobs| W2
    REDIS -->|BullMQ Jobs| W3
    REDIS -->|BullMQ Jobs| W4
    REDIS -->|BullMQ Jobs| W5

    W1 --> SMTP
    W2 --> MKT
    W3 --> B2
    W4 --> B2
    W5 --> SMTP
    W5 --> FCM
    W5 --> WA_API
```

### 6.2 Key Architectural Decisions

| # | Decision | Rationale |
|:---|:---|:---|
| 1 | API versioning from day one | `/api/v1/...` prevents breaking changes |
| 2 | Multi-tenant by `companyId` | Every query filtered by JWT claim; prevents data leakage |
| 3 | Separate request path from long-running work | API responds fast; heavy work offloaded to queues |
| 4 | Videos never public | Only signed URLs with short TTL; prevents unauthorised access |
| 5 | Event-driven notifications | Decoupled; easy to add new channels |
| 6 | Docker Compose for local/prod parity | Same container image everywhere |
| 7 | Nginx reverse proxy + SSL | Terminates TLS, load balances, serves static assets |

### 6.3 Recommended Production Improvements (Immediate)

| # | Improvement | Impact | Effort |
|:---|:---|:---|:---|
| 1 | Introduce Redis | Caching, OTP, rate limiting, BullMQ, real-time events | Medium |
| 2 | WebSockets | Live packing status, recording progress, dashboard updates | Medium |
| 3 | Separate background workers | AI, video processing, email, marketplace sync | Medium |
| 4 | Resumable multipart uploads | Large video files, poor network resilience | Medium |
| 5 | Private media + signed URLs | Security compliance, prevent hotlinking | Low |
| 6 | Structured logging + metrics | Debuggability, alerting, capacity planning | Low |
| 7 | Full CI/CD | Lint, test, migrate, build, zero-downtime deploy | Medium |
| 8 | Audit log every critical action | Compliance, security forensics | Low |
| 9 | Strict company-level isolation | Prevent multi-tenant data leakage | Low |

---

## 7. Repository Audit & Current State Analysis

### 7.1 Source Repository

- **URL:** `https://github.com/sanjeetdayma83/loss-defender-pro-backend`
- **Stack:** NestJS + Prisma + PostgreSQL
- **Production Services:** Backblaze B2 (storage), ExCloud VPS (compute), Neon PostgreSQL (database)

### 7.2 Expected Module Layout

```
src/
├── auth/              # Authentication & session management
├── company/           # Tenant management
├── warehouse/         # Warehouse & station CRUD
├── orders/            # Order lifecycle
├── claims/            # Claim management
├── returns/           # Return investigation
├── upload/            # Multipart upload handling
├── notifications/     # Email, push, SMS, WhatsApp
├── recordings/        # Recording session control
├── evidence/          # Frame extraction & proof generation
├── ai/                # AI job management
├── users/             # User CRUD & invitation
├── marketplace/       # Marketplace sync & webhooks
├── common/            # Guards, interceptors, pipes, decorators
├── config/            # Environment configuration
└── prisma/            # Schema & migrations
```

### 7.3 Audit Dimensions (per module)

| Dimension | Check |
|:---|:---|
| Current implementation status | What exists vs. what is stubbed |
| Missing production features | Gaps blocking go-live |
| Security issues | Vulnerabilities, missing guards |
| Performance / scalability gaps | N+1 queries, missing indexes |
| Required improvements | Must-have before production |
| Future upgrades | Nice-to-have for v1.1+ |

### 7.4 Known Gaps (Production Readiness Analysis)

| # | Gap | Severity | Impact |
|:---|:---|:---|:---|
| 1 | Email verification, forgot/reset password, OTP flows incomplete | Critical | Users cannot recover accounts |
| 2 | Refresh token rotation & JWT blacklist not production-hardened | Critical | Session hijacking risk |
| 3 | Redis / queue workers for AI, email, marketplace sync not standard | Critical | Synchronous API calls will fail at scale |
| 4 | Resumable video upload & private signed URL policy need formalisation | High | Large file failures, security exposure |
| 5 | Full marketplace OAuth + webhook + retry + rate-limit handlers incomplete | High | Order sync unreliability |
| 6 | Comprehensive audit log framework missing on critical actions | High | Compliance failure |
| 7 | API versioning and OpenAPI contract not published | Medium | Client integration friction |
| 8 | CI/CD, blue-green / zero-downtime and automated migration pipeline needed | Medium | Deployment risk |
| 9 | Strict multi-tenant isolation must be verified on every query path | Critical | Data leakage risk |

---

## 8. Database Design & ER Model

### 8.1 Core Entities

| Entity | Key Relationships | Notes |
|:---|:---|:---|
| **Company** | Root tenant; owns Warehouses, Users, Orders, Subscription | Indexed by `email`, `status` |
| **Warehouse** | Belongs to Company; has Stations, Devices, Orders | Unique `(companyId, code)` |
| **User** | Belongs to Company; has Role, optional Warehouse/Station | Unique `email` globally |
| **Role / Permission** | RBAC matrix; many-to-many with User | Cached in JWT |
| **Order** | Marketplace origin; assigned to Warehouse; has items, status | Indexed by `marketplaceOrderId` |
| **Recording** | Linked to Order + Operator + Station; media keys in B2 | Lifecycle: started -> completed -> processed |
| **Evidence** | Derived from Recording; frames, overlays, checksums | Immutable after creation |
| **Claim** | Linked to Order; status machine; evidence references | Indexed by `status`, `createdAt` |
| **Return** | Linked to Order; unboxing video, condition, decision | Similar lifecycle to Claim |
| **Notification** | User / Company scoped; channel + payload | Queue-based delivery |
| **AIJob** | Background processing jobs | Status: queued -> processing -> completed / failed |
| **AuditLog** | Immutable; actor, action, entity, before/after, IP, timestamp | Partitioned by month |
| **MarketplaceAccount** | OAuth tokens, marketplace type, company scoped | Encrypted credentials |
| **RefreshToken / Session** | Device binding, rotation, revocation | Hashed storage |
| **PasswordReset / Invite / EmailVerify** | Token + expiry + used flag | Single-use, TTL enforced |

### 8.2 Indexing & Constraints Guidelines

```sql
-- Tenant isolation: every table MUST have companyId
CREATE INDEX idx_orders_company_status ON orders(company_id, status);
CREATE INDEX idx_orders_marketplace ON orders(marketplace_order_id);
CREATE INDEX idx_orders_created ON orders(created_at DESC);

-- User lookups
CREATE INDEX idx_users_company ON users(company_id, status);
CREATE UNIQUE INDEX idx_users_email ON users(email);

-- Evidence & claims
CREATE INDEX idx_claims_company_status ON claims(company_id, status);
CREATE INDEX idx_evidence_recording ON evidence(recording_id);

-- Audit logs (partitioned)
CREATE INDEX idx_audit_company ON audit_logs(company_id, created_at DESC);
CREATE INDEX idx_audit_actor ON audit_logs(actor_id, action);
```

**Constraints:**
- Foreign keys with `ON DELETE RESTRICT` or `CASCADE` per domain rules
- Soft-delete (`deletedAt`) preferred for Users, Warehouses, Orders
- All tenant-scoped tables MUST carry `companyId` and be filtered in every query

### 8.3 Order Status State Machine

```mermaid
stateDiagram-v2
    [*] --> Synced: Marketplace webhook
    [*] --> Synced: Manual create
    Synced --> Queued: Warehouse assigned
    Queued --> Packing: Operator assigned
    Packing --> Recording: Start recording
    Recording --> Scanned: Barcode validated
    Scanned --> EvidenceReady: Evidence generated
    EvidenceReady --> Dispatched: AWB captured
    Dispatched --> Shipped: Courier scan
    Shipped --> Closed: Delivered
    Shipped --> Claimed: Dispute raised
    Shipped --> Returned: RTO initiated
    Claimed --> Investigating: Evidence reviewed
    Investigating --> Closed: Approved / Rejected
    Returned --> Received: Package back
    Received --> Inspected: Unboxing recorded
    Inspected --> Closed: Refund / Restock / Reject
```


---

## 9. Authentication, RBAC & Security Model

### 9.1 Current vs Required

| Area | Current (Typical) | Required for Production |
|:---|:---|:---|
| **Login** | JWT + basic role guard | Email verify, forgot/reset, OTP, session list |
| **Tokens** | Access + Refresh | Rotation, blacklist, short access TTL |
| **Devices** | Limited | Device fingerprint, active sessions, revoke |
| **2FA** | Missing | Optional TOTP / SMS (v1.1+) |
| **OAuth** | Partial | Google / Microsoft (optional) |
| **RBAC** | Role strings | Fine-grained permission matrix + guards |
| **Audit** | Partial | Every critical mutation logged |

### 9.2 Recommended Token Policy

| Parameter | Value | Rationale |
|:---|:---|:---|
| Access token TTL | 15 minutes | Short window for compromise |
| Refresh token TTL | 7–30 days | Balance security vs. UX |
| Refresh token rotation | On every use | Detect token reuse (theft) |
| Refresh token storage | Hashed in DB | Prevent DB leak exposure |
| Logout behaviour | Revoke session | Immediate termination |
| Password change | Revoke all sessions | Force re-authentication |
| Role change | Revoke all sessions | Prevent privilege escalation |

**JWT Payload:**

```json
{
  "sub": "user-uuid",
  "companyId": "company-uuid",
  "role": "packing_operator",
  "permissions": ["orders.read", "scanner.use"],
  "iat": 1722830400,
  "exp": 1722831300,
  "jti": "unique-token-id"
}
```

---

## 10. Core Domain Modules

### 10.1 Company Management

- Create / update profile
- Invite users
- Suspend / delete users
- Subscription, storage quota, warehouse & user limits
- Billing hooks (Stripe integration)
- Audit logs for all admin actions

### 10.2 Warehouse Management

- CRUD warehouses
- Sections / zones / packing tables / lines
- Assign operators, devices, cameras
- Timezone, working hours, dispatch rules
- Station health monitoring (heartbeat)

### 10.3 User Management

- Invitation flow with email token
- Temporary password / force change on first login
- Status machine (Pending / Active / Suspended / Deleted)
- Last login, failed attempts, lock tracking
- Department, designation, reports-to (optional hierarchy)

### 10.4 Orders Module

Orders originate from marketplace sync or manual entry. Lifecycle covers assignment, packing queue, operator, recording, scan, evidence, dispatch and post-shipment.

#### Key Order Fields (Conceptual Schema)

```json
{
  "id": "uuid",
  "companyId": "uuid",
  "warehouseId": "uuid",
  "marketplace": "amazon|flipkart|meesho|shopify|woocommerce|manual",
  "marketplaceOrderId": "string",
  "status": "synced|queued|packing|recorded|dispatched|shipped|claimed|returned|closed",
  "items": [
    {
      "sku": "SKU-001",
      "qty": 2,
      "name": "Widget Pro",
      "scannedQty": 2,
      "status": "matched"
    }
  ],
  "assignedOperatorId": "uuid|null",
  "stationId": "uuid|null",
  "recordingId": "uuid|null",
  "evidenceId": "uuid|null",
  "awb": "string|null",
  "courier": "string|null",
  "dispatchedAt": "iso|null",
  "deliveredAt": "iso|null",
  "metadata": {},
  "timestamps": {
    "createdAt": "2026-08-05T10:00:00Z",
    "updatedAt": "2026-08-05T12:00:00Z"
  }
}
```

---

## 11. Recording, Evidence, Scanner & Upload Engine

### 11.1 Scanner Flow

```mermaid
flowchart TD
    A["Operator scans barcode"] --> B{"Valid format?"}
    B -->|NO| C["Red toast + haptic<br/>Invalid barcode"]
    B -->|YES| D{"On order?"}
    D -->|NO| E["Red toast + haptic<br/>Wrong SKU"]
    D -->|YES| F{"Already scanned?"}
    F -->|YES| G["Yellow toast<br/>Already scanned"]
    F -->|NO| H["Green flash<br/>Increment scannedQty"]
    H --> I{"All items matched?"}
    I -->|YES| J["Enable Continue"]
    I -->|NO| K["Show remaining items"]
```

#### Scanner Capabilities

| Feature | Description | Priority |
|:---|:---|:---|
| Barcode / QR scan | Camera or hardware scanner input | P0 |
| Duplicate detection | Prevent double-counting | P0 |
| Invalid barcode handling | Reject unknown formats | P0 |
| Wrong SKU / wrong quantity detection | Real-time mismatch alert | P0 |
| Optional weight & package verification | Integration with smart scales | P2 |

### 11.2 Recording Engine

| Feature | Specification |
|:---|:---|
| Start / Pause / Stop | Per order or per station session |
| Segmented upload | 30–60 second segments for resilience |
| Offline queue | Local SQLite queue; auto-sync when online |
| Encryption at rest | B2 SSE + optional client-side encryption |
| Compression | H.264 / HEVC with quality presets |
| Thumbnail generation | First frame + keyframe extraction |
| Checksum | SHA-256 per segment for integrity |
| Evidence generation | Selected frames + overlays (barcode, timestamp, operator) |

### 11.3 Evidence System

| Feature | Description |
|:---|:---|
| Timeline of frames | Barcode overlay, timestamp, operator name, GPS, warehouse, shift |
| AI analysis hooks | Object detection, SKU verification, human presence, missing-item detection |
| Storage lifecycle | Retention policy per company plan (30/90/365 days) |
| Immutable link | Claim / Return references evidence by ID; evidence never modified |
| Chain of custody | SHA-256 checksums + audit log for every access |

### 11.4 Upload Design Rules

| Rule | Implementation |
|:---|:---|
| Multipart resumable | Init -> Upload parts -> Complete; resume from last part |
| Private buckets only | No public B2 buckets |
| Signed URLs | Short TTL (5–15 min); generated server-side |
| Content validation | Strict MIME-type allow-list; size limits |
| Virus scan | Optional ClamAV worker for uploaded files |
| Background finalisation | Evidence job triggered after all segments complete |


---

## 12. Claims, Returns & Marketplace Integration

### 12.1 Claim Lifecycle

```mermaid
flowchart LR
    A["Claim Created"] --> B["Evidence Fetch"]
    B --> C["AI Review (optional)"]
    C --> D["Manual Review"]
    D --> E{"Decision"}
    E -->|Approved| F["Marketplace Reply"]
    E -->|Rejected| F
    E -->|Escalated| G["Senior Review"]
    G --> F
    F --> H["Archive"]
```

### 12.2 Return Lifecycle

| Stage | Action | Evidence |
|:---|:---|:---|
| Return request received | Notification to warehouse | — |
| Return received at warehouse | Unboxing video recording | Full unboxing recording |
| Condition check | Visual inspection + images | Photo evidence |
| Missing items detection | AI comparison vs. original order | AI report |
| Decision | Refund / Restock / Reject | Decision + notes |

### 12.3 Marketplace Integration Scope

**Primary marketplaces:** Amazon, Flipkart, Meesho
**Also supported:** Shopify, WooCommerce
**Couriers:** Shiprocket, Delhivery, Blue Dart, XpressBees, Ekart, DTDC, Shadowfax

#### Required Capabilities

| Capability | Description |
|:---|:---|
| OAuth / API-key connection | Per-company marketplace authentication |
| Webhook receivers | Signature verification (HMAC) for each provider |
| Order & shipment sync | Pagination, cursor-based, rate-limit handling |
| Retry with exponential backoff | 1s, 2s, 4s, 8s, 16s, 32s, then DLQ |
| Event mapping | Order / shipment / claim / return / cancellation / RTO |
| Idempotent sync jobs | Idempotency key = provider + eventId |

---

## 13. Notifications, Analytics, Admin & Billing

### 13.1 Notification Channels

| Channel | Provider | Use Case | Priority |
|:---|:---|:---|:---|
| Email | SMTP / SendGrid | Verification, invites, claim updates | P0 |
| SMS | Twilio / MSG91 | OTP, critical alerts | P1 |
| WhatsApp | WhatsApp Business API | Claim status, delivery updates | P1 |
| Push (FCM) | Firebase | Real-time alerts, assignment | P1 |
| In-App | WebSocket | Live notifications, badges | P1 |
| Slack / Teams | Webhooks | Manager alerts, daily summaries | P2 |

### 13.2 Admin Dashboard KPIs

| KPI | Calculation | Refresh |
|:---|:---|:---|
| Warehouse utilisation | Active stations / Total stations | Real-time |
| Claims & returns volume | Count per period | Hourly |
| Claims win rate | Approved / Total claims | Daily |
| Storage used vs quota | Bytes used / Quota | Real-time |
| AI job usage | Jobs processed / Quota | Hourly |
| Operator productivity | Orders packed / Hour | Real-time |
| Live recording count | Active recordings now | Real-time |

### 13.3 Analytics Dimensions

| Dimension | Metrics |
|:---|:---|
| Packing speed | Orders per hour, minutes per order |
| Operator productivity | Orders, accuracy rate, scan time |
| Claim % | Claims / Total orders by marketplace |
| Return % | Returns / Total orders by reason |
| By marketplace | Volume, claim rate, sync lag |
| By warehouse | Throughput, utilisation, error rate |
| By shift | Morning / afternoon / night performance |
| Storage & bandwidth | Usage trends, cost projection |

### 13.4 Billing (Medium Priority)

| Feature | Description | Target |
|:---|:---|:---|
| Plans with limits | Users, warehouses, storage, AI minutes | v1.1 |
| Usage metering | Real-time tracking against quotas | v1.1 |
| Invoice generation hooks | Stripe / Razorpay integration | v1.1 |
| Grace period | 7-day suspension warning | v1.1 |
| Suspension on non-payment | Read-only mode | v1.1 |

---

## 14. Backend API Specification & JSON Contracts

### 14.1 Base URL & Versioning

```
Base URL: https://api.lossdefender.pro
Version:  /api/v1
Auth:     Authorization: Bearer <accessToken>
```

### 14.2 Response Envelope

```json
{
  "success": true,
  "data": {},
  "error": null,
  "meta": {
    "page": 1,
    "limit": 20,
    "total": 150,
    "requestId": "req-uuid"
  }
}
```

### 14.3 Authentication Endpoints

| Method | Path | Purpose | Auth |
|:---|:---|:---|:---|
| POST | `/auth/register` | Company + owner registration | Public |
| POST | `/auth/login` | Email/password login | Public |
| POST | `/auth/refresh` | Rotate tokens | Public (refresh token) |
| POST | `/auth/logout` | Revoke session(s) | Bearer |
| POST | `/auth/forgot-password` | Send reset token | Public |
| POST | `/auth/reset-password` | Set new password with token | Public |
| POST | `/auth/verify-email` | Confirm email | Public (verify token) |
| GET | `/auth/sessions` | List active sessions | Bearer |
| DELETE | `/auth/sessions/:id` | Revoke one session | Bearer |

#### Register Request

```json
{
  "companyName": "Acme Warehouse Pvt Ltd",
  "ownerName": "Sanjeet Dayma",
  "email": "sanjeet@acme.com",
  "password": "SecurePass123!",
  "phone": "+91-9876543210"
}
```

#### Login Request / Response

```json
// Request
{
  "email": "sanjeet@acme.com",
  "password": "SecurePass123!",
  "deviceId": "flutter-android-abc123"
}

// Response
{
  "success": true,
  "data": {
    "accessToken": "eyJhbG...",
    "refreshToken": "dGhpcy...",
    "expiresIn": 900,
    "user": { "id", "name", "email", "role", "permissions" },
    "company": { "id", "name", "plan", "status" }
  }
}
```

### 14.4 Core Resource Endpoints

| Method | Path | Notes |
|:---|:---|:---|
| POST / GET | `/companies`, `/companies/:id` | Super-admin or owner scoped |
| POST / GET / PATCH | `/warehouses`, `/warehouses/:id` | Company scoped |
| POST / GET / PATCH | `/users`, `/users/:id` | Invite, role, warehouse assign |
| POST / GET / PATCH | `/orders`, `/orders/:id` | Create manual / list / update status |
| POST | `/orders/:id/assign` | Operator / station assignment |
| POST | `/scanner/validate` | Barcode validation against order |
| POST | `/recordings/start`, `/recordings/stop` | Recording session control |
| POST | `/upload/init`, `/upload/part`, `/upload/complete` | Multipart resumable to B2 |
| GET | `/evidence/:id` | Signed URL + metadata |
| POST / GET / PATCH | `/claims`, `/claims/:id` | Claim lifecycle |
| POST / GET / PATCH | `/returns`, `/returns/:id` | Return lifecycle |
| POST | `/marketplace/connect` | OAuth start / API key store |
| POST | `/marketplace/webhook/:provider` | Inbound events |
| GET | `/analytics/kpis` | Dashboard aggregates |
| GET | `/audit-logs` | Filtered audit trail |

### 14.5 Create Order Example

```json
{
  "marketplace": "amazon",
  "marketplaceOrderId": "AMZ-123456",
  "warehouseId": "uuid",
  "items": [
    { "sku": "SKU-001", "qty": 2, "name": "Widget Pro" }
  ],
  "customer": {
    "name": "Rahul Sharma",
    "phone": "+91-9876543210",
    "address": "..."
  }
}
```

### 14.6 Create Claim Example

```json
{
  "orderId": "uuid",
  "reason": "missing_item",
  "marketplace": "flipkart",
  "description": "Customer claims 1 item missing from package",
  "attachments": ["evidence-id-1", "evidence-id-2"]
}
```

> **Full OpenAPI / Swagger specification should be generated from NestJS decorators and published as the single source of truth for Flutter and Web Admin.**


---

## 15. Frontend Specification

### 15.1 Flutter Mobile / Desktop Screens

| Screen | Purpose | Priority |
|:---|:---|:---|
| Splash | Logo, version, silent auth check | P0 |
| Login / Register / Forgot Password / OTP | Authentication flows | P0 |
| Dashboard (role-aware) | Role-specific home screen | P0 |
| Scanner | Barcode capture and validation | P0 |
| Recording session UI | Video capture with controls | P0 |
| Evidence viewer | Frame-by-frame review | P1 |
| Claims list & detail | Claim management | P1 |
| Returns list & detail | Return investigation | P1 |
| Warehouse / Station selector | Context switching | P1 |
| Settings / Profile / Sessions | User preferences | P1 |
| Supervisor live view | Floor monitoring (desktop preferred) | P1 |

### 15.2 Web Admin (React / Next.js) Screens

| Screen | Purpose |
|:---|:---|
| Company management | Profile, branding, subscription |
| User & role management | Invite, assign, permissions |
| Warehouse configuration | CRUD, stations, devices |
| Marketplace connection wizard | OAuth/API-key setup |
| Orders overview | List, filter, detail, assign |
| Claims & returns workspace | Review, decide, reply |
| Analytics & reports | KPIs, charts, exports |
| Billing & usage | Plans, invoices, quotas |
| Audit log viewer | Filtered, exportable logs |
| Global settings | Notifications, security |

### 15.3 UX Principles

| Principle | Implementation |
|:---|:---|
| Mobile-first for operators | Large tap targets (>=48dp), offline indicators, minimal steps |
| Clear status colours | Colour-blind safe palette for order/claim/recording states |
| Optimistic UI | Only where rollback is safe; otherwise wait for server confirmation |
| Consistent error surfaces | Actionable messages, never generic "Something went wrong" |
| Skeleton loading | Lists show skeleton; buttons show spinner |
| Accessibility | Screen reader support, high contrast, font scaling |

---

## 16. Deployment, Infrastructure & DevOps

### 16.1 Target Stack

| Component | Choice | Notes |
|:---|:---|:---|
| Compute | ExCloud VPS — Ubuntu LTS | 4 vCPU, 8GB RAM minimum |
| Runtime | Docker + Docker Compose | Same image local/prod |
| Process / Proxy | Nginx (SSL termination) + PM2 inside containers | Reverse proxy, load balancing |
| Database | Neon PostgreSQL (managed) | Auto-backup, point-in-time recovery |
| Object Storage | Backblaze B2 | S3-compatible, cost-effective |
| Cache / Queue | Redis (self-hosted on VPS or managed) | BullMQ, sessions, OTP |
| CDN / WAF | Cloudflare (recommended) | DDoS protection, edge caching |
| CI/CD | GitHub Actions | Lint, test, build, deploy |

### 16.2 Deployment Workflow

```mermaid
flowchart LR
    A["Developer pushes to main"] --> B["GitHub Actions"]
    B --> C["Lint & Unit Tests"]
    C --> D["Build Docker Image"]
    D --> E["Run Migrations"]
    E --> F["Deploy to Staging"]
    F --> G["Smoke Tests"]
    G --> H{"Pass?"}
    H -->|YES| I["Blue-Green Deploy to Prod"]
    H -->|NO| J["Alert + Rollback"]
    I --> K["Health Check Gate"]
    K -->|PASS| L["Traffic Switch"]
    K -->|FAIL| M["Auto Rollback"]
```

### 16.3 Operational Checklist

| # | Check | Frequency |
|:---|:---|:---|
| 1 | Firewall (only 80/443 + SSH restricted) | Once |
| 2 | Automated backups of Neon + B2 lifecycle rules | Daily |
| 3 | Monitoring (uptime, disk, memory, queue lag, error rate) | Continuous |
| 4 | Log retention policy (30 days hot, 1 year cold) | Configured |
| 5 | Disaster recovery runbook (RPO: 1h, RTO: 4h) | Documented |
| 6 | SSL certificate renewal (auto via Let's Encrypt) | Auto |
| 7 | Security patches | Weekly |

---

## 17. Security Checklist & Threat Model

### 17.1 Application Security

| Control | Implementation | Verification |
|:---|:---|:---|
| Helmet middleware | Security headers | HTTP response inspection |
| Rate limiting | Per IP + per user | Load test |
| JWT rotation + blacklist | Short TTL, hashed refresh | Token reuse test |
| Input validation | class-validator / class-transformer | Fuzz testing |
| Parameterised queries | Prisma ORM | SQL injection test |
| CORS | Restricted to known origins | Penetration test |
| CSRF protection | Cookie sessions only | CSRF test |

### 17.2 Data & Storage Security

| Control | Implementation |
|:---|:---|
| All media private | Signed URLs only |
| Encryption at rest | Neon + B2 SSE |
| Secrets management | Environment variables / AWS Secrets Manager |
| PII minimisation | No emails/phones in logs |
| Data retention | Auto-purge per plan |

### 17.3 OWASP Top 10 Mapping

| OWASP Risk | Mitigation | Status |
|:---|:---|:---|
| Injection (SQL / NoSQL / Command) | Prisma ORM, parameterised queries | ✓ |
| Broken authentication | JWT rotation, account lock, session revocation | ✓ |
| Sensitive data exposure | Encryption at rest, signed URLs, TLS 1.3 | ✓ |
| Broken access control | RBAC guards, companyId filtering on every query | ✓ |
| Security misconfiguration | Docker hardening, minimal image, no dev tools | ✓ |
| XSS (admin panel) | CSP headers, output encoding, React auto-escape | ✓ |
| Insecure deserialization | JSON only, no native deserialization | ✓ |
| Insufficient logging & monitoring | Structured logs, Sentry, audit trail | ✓ |

### 17.4 File Upload Hardening

| Control | Specification |
|:---|:---|
| Content-type allow-list | `video/mp4`, `image/jpeg`, `image/png` only |
| Extension validation | `.mp4`, `.jpg`, `.jpeg`, `.png` |
| Size limits | 500MB per video, 10MB per image |
| Virus scan | Optional ClamAV worker |
| Storage location | Outside web root; serve only via signed URL |
| Filename sanitisation | UUID-based filenames; original name stored as metadata |

---

## 18. Testing Strategy & Go-Live Checklist

### 18.1 Test Pyramid

| Layer | Scope | Tools | Coverage Target |
|:---|:---|:---|:---|
| **Unit** | Services, validators, pure functions | Jest | >80% |
| **Integration** | API + DB + Redis + storage mocks | Jest + Supertest | >70% |
| **API / Contract** | OpenAPI conformance, auth guards | Dredd / Schemathesis | 100% endpoints |
| **Load / Stress** | Critical paths (login, order list, upload init) | k6 / Artillery | p95 < 300ms |
| **Flutter** | Widget + integration tests; offline queue | Flutter Test | >70% |
| **E2E** | Critical happy paths | Cypress / Playwright | 5 core flows |

#### E2E Critical Happy Path

```
Register -> Create Warehouse -> Add Station -> Connect Marketplace
-> Sync Order -> Assign Operator -> Scan Items -> Record Video
-> Upload Evidence -> Dispatch Order -> Create Claim -> Review Evidence
-> Approve Claim -> Generate Report
```

### 18.2 Go-Live Checklist (Minimum)

```
☐ All critical modules behind feature flags or fully implemented
☐ Production Neon project + connection pooling configured
☐ Backblaze B2 buckets private + lifecycle rules
☐ Redis available and health-checked
☐ SSL certificates valid; HSTS enabled
☐ Environment variables complete; no secrets in repo
☐ CI/CD pipeline green on main
☐ Backup & restore tested (full restore < 1 hour)
☐ Monitoring & alerting live (PagerDuty / Opsgenie)
☐ Runbook for common incidents:
    - Database full -> Scale Neon / archive old data
    - Queue backlog -> Scale workers / investigate dead letters
    - B2 outage -> Queue uploads / notify users
☐ Legal / privacy policy & data retention published
☐ Support channels and on-call rotation defined
☐ Load test passed (100 concurrent operators)
☐ Security audit passed (penetration test)
☐ Documentation complete (API, UX, Deployment)
```


---

## 19. Production Improvement Roadmap (Immediate)

| Priority | Item | Effort | Owner | Target |
|:---|:---|:---|:---|:---|
| **P0** | Complete auth suite: email verification, forgot/reset, OTP, session management, refresh rotation | 2 weeks | Backend | v1.0 |
| **P0** | Enforce multi-tenant isolation on every query and controller | 1 week | Backend | v1.0 |
| **P0** | Private B2 + signed URLs + resumable multipart upload | 1 week | Backend | v1.0 |
| **P0** | API versioning `/api/v1` and published OpenAPI | 3 days | Backend | v1.0 |
| **P1** | Introduce Redis + BullMQ workers for email, marketplace sync, AI jobs | 1 week | Backend | v1.0 |
| **P1** | WebSocket gateway for live packing / recording status | 1 week | Backend | v1.0 |
| **P1** | Full audit log framework on critical mutations | 3 days | Backend | v1.0 |
| **P1** | Marketplace connect + webhook + retry for Amazon / Flipkart / Meesho | 2 weeks | Backend | v1.0 |
| **P1** | CI/CD with tests, migrations, zero-downtime deploy on ExCloud | 1 week | DevOps | v1.0 |
| **P2** | Advanced RBAC permission matrix UI and guards | 1 week | Full Stack | v1.1 |
| **P2** | Analytics KPI endpoints + admin dashboard | 2 weeks | Full Stack | v1.1 |
| **P2** | Billing & quota enforcement | 1 week | Backend | v1.1 |
| **P3** | AI verification workers (object/SKU/missing-item) | 2 weeks | AI/Backend | v1.2 |
| **P3** | WhatsApp / SMS notification providers | 3 days | Backend | v1.2 |

---

## 20. Future Enterprise Roadmap

| Feature | Description | Target |
|:---|:---|:---|
| **AI Claim Assistant** | LLM-powered evidence summary and suggested replies | v1.3 |
| **Warehouse Heatmaps** | Visual floor utilisation and bottleneck detection | v2.0 |
| **Live Monitoring Video Wall** | Multi-station real-time view for supervisors | v2.0 |
| **Multi-Region Active-Active** | Geo-distributed deployment for global sellers | v2.0 |
| **Advanced Offline Sync** | CRDT-based conflict resolution for long offline periods | v1.3 |
| **IoT / Smart Camera Integration** | Direct IP camera feed without mobile device | v2.0 |
| **AI Fraud Detection** | Models trained on historical claims to predict fraud risk | v1.3 |
| **Multi-Marketplace Claim Automation** | Auto-submit evidence to marketplaces via APIs | v1.3 |
| **White-Label / Reseller** | Custom branding and subdomain per tenant | v2.0 |
| **Compliance Packs** | SOC2, ISO27001 readiness documentation and controls | v2.0 |

---

## Appendix A — Glossary & Domain Model

| Term | Definition |
|:---|:---|
| **Company / Tenant** | Isolated organisation that owns warehouses, users and data |
| **Warehouse** | Physical location under a company where packing occurs |
| **Packing Station** | Workstation with camera/scanner/printer assigned to an operator |
| **Operator** | User role that performs packing and recording |
| **Recording** | Video capture session linked to an order and station |
| **Evidence** | Processed proof (frames, overlays, checksum) derived from a recording |
| **Claim** | Marketplace or customer dispute requiring evidence defence |
| **Return / RTO** | Return-to-origin or customer return requiring investigation |
| **Marketplace Account** | Connected seller account (Amazon, Flipkart, etc.) |
| **AI Job** | Background job for computer-vision or LLM processing |
| **Audit Log** | Immutable record of who did what, when, on which entity |
| **Signed URL** | Time-limited, cryptographically signed link to private B2 object |
| **SKU** | Stock Keeping Unit — unique product identifier |
| **AWB** | Air Waybill — courier tracking number |
| **RTO** | Return to Origin — undelivered package return |
| **DLQ** | Dead Letter Queue — failed job storage for inspection |
| **SSE** | Server-Side Encryption — B2 encryption at rest |
| **CRDT** | Conflict-free Replicated Data Type — offline sync strategy |

---

## Appendix B — Environment & Configuration Reference

> **All secrets must live in environment variables or a secret manager. A `.env.example` (without real values) must be kept in the repository for documentation.**

### Typical Variables

```bash
# Application
NODE_ENV=production
PORT=3000
API_VERSION=v1

# Database
DATABASE_URL=postgresql://user:pass@neon.tech/db?sslmode=require
DATABASE_POOL_SIZE=20

# Redis
REDIS_URL=redis://localhost:6379
REDIS_PASSWORD=...

# JWT
JWT_ACCESS_SECRET=generate-strong-secret-32-chars
JWT_REFRESH_SECRET=different-strong-secret-32-chars
JWT_ACCESS_TTL=15m
JWT_REFRESH_TTL=7d

# Backblaze B2
B2_KEY_ID=...
B2_APPLICATION_KEY=...
B2_BUCKET=loss-defender-pro-media
B2_ENDPOINT=https://s3.us-west-002.backblazeb2.com
B2_SIGNED_URL_TTL=900

# Email
SMTP_HOST=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USER=apikey
SMTP_PASS=...
EMAIL_FROM=noreply@lossdefender.pro

# Firebase (Push Notifications)
FIREBASE_PROJECT_ID=...
FIREBASE_PRIVATE_KEY=...
FIREBASE_CLIENT_EMAIL=...

# Marketplace (example for Amazon SP-API)
AMAZON_CLIENT_ID=...
AMAZON_CLIENT_SECRET=...
AMAZON_REFRESH_TOKEN=...

# Security
BCRYPT_ROUNDS=12
RATE_LIMIT_WINDOW_MS=60000
RATE_LIMIT_MAX=100

# Monitoring
SENTRY_DSN=...
LOG_LEVEL=info
```

### Secret Management Best Practices

1. **Never commit secrets** to Git — use `.gitignore` for `.env` files
2. **Use a secret manager** in production (AWS Secrets Manager, HashiCorp Vault, or Doppler)
3. **Rotate secrets quarterly** — especially JWT secrets and API keys
4. **Use different secrets** per environment (dev, staging, prod)
5. **Audit secret access** — log who accessed what secret when

---

> **Closing Statement**
>
> This document set constitutes the canonical engineering blueprint for Loss Defender Pro. Implementation teams must treat it as the source of truth for scope, contracts, security and deployment. Any deviation requires explicit product and architecture approval.

---

*End of Loss Defender Pro Production Documentation Suite — Version 3.0 • Confidential • PrimeCore Technologies*
