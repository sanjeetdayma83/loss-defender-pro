# Loss Defender Pro — Data Flow & Sequence Diagrams

**Enterprise Warehouse Intelligence Platform**

| | |
|:---|:---|
| **Document Version** | 3.0 |
| **Status** | Production Design Specification |
| **Companion Docs** | SRS, Architecture, Database Design, OpenAPI |
| **Date** | 05 August 2026 |

> **CONFIDENTIAL — Engineering Use Only**

---

## Table of Contents

### Part A — Data Flow Diagrams
1. Context Diagram (Level 0)
2. Level-1 DFD — Major Processes
3. Data Stores Catalogue
4. External Entities & Data Flows Summary

### Part B — Sequence Diagrams
5. Authentication (Register / Login / Refresh / Forgot Password)
6. Company & User Onboarding (Invite flow)
7. Order Ingestion (Marketplace Sync + Manual Create)
8. Packing Flow (Assign → Scan → Record → Upload → Evidence)
9. Dispatch & Shipment Status Update
10. Claim Lifecycle (Create → Evidence → Decide)
11. Return Lifecycle
12. Marketplace Webhook Handling
13. Notification Delivery
14. Background Worker Flows (AI, Email, Sync)

### Part C — Component Interaction
15. Runtime Component Communication Map
16. Error & Retry Patterns

---

## Part A — Data Flow Diagrams

### 1. Context Diagram (Level 0)

The system as a single process interacting with external entities. Shows what crosses the system boundary.

```mermaid
flowchart TB
    subgraph External_Entities["External Entities"]
        OP["Packing Operator<br/>(Flutter)"]
        ADMIN["Company Admin<br/>(Web/App)"]
        MKT["Marketplace<br/>(Amazon, Flipkart, Meesho...)"]
        NOTIF["Notification Providers<br/>(Email/SMS/FCM/WA)"]
    end

    subgraph System["LOSS DEFENDER PRO SYSTEM"]
        LDP[" "]
    end

    subgraph Data_Stores["External Data Stores"]
        NEON["Neon PostgreSQL<br/>(all state)"]
        B2["Backblaze B2<br/>(videos, imgs)<br/>private media"]
    end

    OP -->|scan / record / upload| LDP
    LDP -->|order status, evidence| OP

    ADMIN -->|APIs| LDP
    LDP -->|sync, webhook| ADMIN

    MKT -->|sync, webhook| LDP
    LDP -->|webhook| MKT

    LDP -->|Email/SMS/Push/WA| NOTIF

    LDP <-->|all state| NEON
    LDP <-->|private media| B2
```

**External entities:** Packing Operator (Flutter), Company Admin (Web/App), Marketplaces, Notification providers.
**Data stores outside process:** Neon DB, Backblaze B2.

---

### 2. Level-1 DFD — Major Processes

The system decomposed into major processes. Arrows are labelled data flows; cylinders are data stores.

```mermaid
flowchart TB
    subgraph Actors["Actors"]
        OP1["[Operator]"]
        AD1["[Admin]"]
        MK1["[Marketplace]"]
    end

    subgraph Processes["Major Processes"]
        P1["P1<br/>Auth & Sess"]
        P2["P2<br/>Org Mgmt"]
        P3["P3<br/>Order<br/>Ingestion"]
        P4["P4<br/>Packing &<br/>Scanner"]
        P5["P5<br/>Rec<br/>Upload"]
        P6["P6<br/>Evid<br/>Generate"]
        P7["P7<br/>Disp<br/>atch"]
        P8["P8<br/>Claims &<br/>Returns"]
    end

    subgraph DataStores["Data Stores"]
        D1["D1 Users/Sessions"]
        D2["D2 Companies/WH"]
        D3["D3 Orders"]
        D4["D4 Recordings/Seg"]
        D5["D5 Evidence"]
        D6["D6 Claims"]
        D7["D7 Marketplace Accts"]
        D8["D8 Audit/Notif"]
        D9["D9 AI Jobs"]
    end

    subgraph Physical["Physical Storage"]
        NEON1["[Neon DB]"]
        B21["[Backblaze B2]"]
    end

    OP1 -->|scan/record| P1
    AD1 -->|config/invite| P2
    MK1 -->|orders/webhooks| P3

    P1 --> D1
    P2 --> D2
    P3 --> D3
    P4 --> D3
    P5 --> D4
    P6 --> D5
    P7 --> D3
    P8 --> D6

    P5 --> B21
    P6 --> B21

    D1 --> NEON1
    D2 --> NEON1
    D3 --> NEON1
    D4 --> NEON1
    D5 --> NEON1
    D6 --> NEON1
    D7 --> NEON1
    D8 --> NEON1
    D9 --> NEON1
```

#### 2.1 Process Catalogue

| ID | Process | Responsibility |
|:---|:---|:---|
| P1 | Auth & Sessions | Register, login, JWT, refresh, OTP, sessions |
| P2 | Org Management | Company profile, warehouses, stations, user invite, RBAC |
| P3 | Order Ingestion | Marketplace sync, webhooks, manual order create, mapping |
| P4 | Packing & Scanner | Queue, operator assign, barcode validate, qty checks |
| P5 | Recording Upload | Start/stop session, multipart upload to B2, segment tracking |
| P6 | Evidence Generate | Frame extract, overlays, checksum, signed URLs, AI hooks |
| P7 | Dispatch | Status → dispatched/shipped, AWB, courier, story |
| P8 | Claims & Returns | Claim/return lifecycle, evidence attach, decide, marketplace reply |
| P9 | Notify (implied) | Enqueue email/SMS/push/in-app based on events |
| P10 | Analytics (implied) | Aggregate KPIs from orders/claims/recordings |

---

### 3. Data Stores Catalogue

| Store | Physical | Primary Content | Written by | Read by |
|:---|:---|:---|:---|:---|
| D1 Users/Sessions | Neon | users, sessions, tokens, roles | P1, P2 | P1–P8 |
| D2 Companies/WH | Neon | companies, warehouses, stations | P2 | P2–P8 |
| D3 Orders | Neon | orders, order_items, status_history | P3, P4, P7 | P3–P8 |
| D4 Recordings | Neon + B2 | recordings, segments metadata; video in B2 | P5 | P5, P6, P8 |
| D5 Evidence | Neon + B2 | evidence, frames; images in B2 | P6 | P6, P8 |
| D6 Claims/Returns | Neon | claims, returns, attachments | P8 | P8, Analytics |
| D7 Mkt Accounts | Neon | OAuth/API credentials (encrypted) | P3 | P3 |
| D8 Audit/Notif | Neon | audit_logs, notifications | All | Admin, P9 |
| D9 AI Jobs | Neon + Redis | ai_jobs queue state | P6, Workers | Workers |
| Redis | Redis | OTP, rate-limit, BullMQ jobs, cache | P1, Workers | P1, Workers |

---

### 4. Key Data Flows Summary

| From → To | Data | Trigger |
|:---|:---|:---|
| Marketplace → P3 | Order / shipment / claim payload | Webhook or scheduled sync |
| P3 → D3 | Normalised order + items | After mapping |
| Operator → P4 | Barcode, orderId | Scan action |
| P4 → D3 | scanned_qty, status=scanned | Validation OK |
| Operator → P5 | Start/stop, segments | Record packing |
| P5 → B2 | Video segment bytes | Multipart upload |
| P5 → D4 | Segment keys, checksums, status | Upload complete |
| P6 → B2 | Frame images, manifest | Evidence generation job |
| P6 → D5 | Evidence row + frame metadata | Job success |
| Claims Exec → P8 | Decision, notes | Review complete |
| P8 → Marketplace | Claim reply / evidence link | Approved/rejected |
| Any P* → D8 | Audit event | Critical mutation |
| Any P* → P9 | Notification intent | Domain event |
| P9 → Provider | Email/SMS/Push payload | Worker dequeue |

---

## Part B — Sequence Diagrams

Actors and components on the top; time flows downward. Focus is on happy path + important error/branch.

---

### 5. Authentication Sequences

#### 5.1 Register (Company + Owner)

```mermaid
sequenceDiagram
    participant C as Flutter/Web
    participant A as API (NestJS)
    participant N as Neon DB
    participant E as Email Worker

    C->>A: POST /auth/register<br/>{company, owner, email, password}
    A->>A: validate DTO
    A->>A: hash password
    A->>N: BEGIN TX
    A->>N: INSERT company
    A->>N: INSERT user (role=owner)
    A->>N: INSERT email_verification
    A->>N: COMMIT
    A->>E: enqueue verify email job
    A->>A: issue JWT pair
    A-->>C: 201 {tokens, user, company}
    E->>E: send email via SMTP
```

**Errors:** 409 if email exists; 400 validation. Email always async (job queue).

---

#### 5.2 Login

```mermaid
sequenceDiagram
    participant C as Client
    participant A as API
    participant N as Neon
    participant R as Redis

    C->>A: POST /auth/login<br/>{email, password, deviceId}
    A->>R: rate-limit check
    A->>N: find user by email
    A->>A: verify password
    A->>N: check status/lock
    A->>N: INSERT session (refresh hash)
    A->>N: update last_login
    A-->>C: 200 {tokens, user, company}
```

**On failure:** increment failed_login_count; lock if threshold exceeded. 401 always generic.

---

#### 5.3 Token Refresh

```mermaid
sequenceDiagram
    participant C as Client
    participant A as API
    participant N as Neon

    C->>A: POST /auth/refresh<br/>{refreshToken}
    A->>N: hash token, find session
    A->>A: check not revoked / not expired
    A->>N: rotate: new refresh hash
    A-->>C: 200 {access, refresh}
```

**Reuse of an already-rotated refresh token → revoke all sessions (theft detection).**

---

#### 5.4 Forgot / Reset Password

```mermaid
sequenceDiagram
    participant C as Client
    participant A as API
    participant N as Neon
    participant RE as Redis/Email

    C->>A: POST forgot {email}
    A->>N: find user
    A->>RE: create token (hash+TTL)
    A->>RE: enqueue email
    A-->>C: 202 Accepted

    Note over C,RE: Later...

    C->>A: POST reset {token, pwd}
    A->>RE: validate token
    A->>N: update pwd
    A->>N: mark used
    A->>N: revoke sessions
    A-->>C: 204 No Content
```

---

### 6. User Invite Sequence

```mermaid
sequenceDiagram
    participant AC as Admin Client
    participant A as API
    participant N as Neon
    participant E as Email Worker
    participant NU as New User

    AC->>A: POST /users<br/>{email, role, warehouseId}
    A->>N: check quota
    A->>A: RBAC guard
    A->>N: INSERT user status=pending
    A->>N: INSERT invite token
    A->>E: enqueue invite
    A-->>AC: 201 {user}
    E->>NU: send invite link
    NU->>NU: opens link, sets password
    NU->>A: POST accept {token, pwd}
    A->>N: activate user
    A-->>NU: 204 / tokens
```

---

### 7. Order Ingestion

#### 7.1 Marketplace Scheduled Sync

```mermaid
sequenceDiagram
    participant S as Scheduler/Cron
    participant W as Sync Worker
    participant M as Marketplace API
    participant N as Neon

    S->>W: trigger job
    W->>N: load account + decrypt creds
    W->>M: GET orders (cursor/page)
    M-->>W: order list
    loop for each order
        W->>N: map → upsert order+items
    end
    W->>N: update last_sync / cursor
    W->>N: enqueue notify if new orders
```

---

#### 7.2 Manual Order Create

```mermaid
sequenceDiagram
    participant C as Client
    participant A as API
    participant N as Neon

    C->>A: POST /orders<br/>{marketplace, items, warehouseId, ...}
    A->>A: validate RBAC + warehouse belongs to company
    A->>N: INSERT order
    A->>N: INSERT items<br/>status=synced/queued
    A->>N: INSERT status_history
    A-->>C: 201 {order}
```

---

### 8. Packing Flow (Core Happy Path)

**Assign → Scan → Record → Upload segments → Evidence**

```mermaid
sequenceDiagram
    participant OA as Operator App
    participant A as API (Nest)
    participant N as Neon DB
    participant B as B2 Storage
    participant W as Workers

    Note over OA,W: 1. ASSIGN
    OA->>A: POST assign<br/>order→op/station
    A->>N: UPDATE order
    A-->>OA: 200 order

    Note over OA,W: 2. SCAN
    OA->>A: POST scanner/validate<br/>{orderId, barcode}
    A->>N: match SKU, incr scanned_qty
    A-->>OA: 200 {valid}

    Note over OA,W: 3. RECORD START
    OA->>A: POST recordings/start
    A->>N: INSERT recording status=started
    A->>N: UPDATE order status=recording
    A-->>OA: 201 recording

    Note over OA: local video capture...

    Note over OA,W: 4. UPLOAD INIT
    OA->>A: POST upload/init<br/>{recordingId, seq, size}
    A->>B: create multipart
    A->>N: INSERT segment row
    A-->>OA: 200 {parts, signed URLs}

    Note over OA,W: 5. UPLOAD PARTS
    OA->>B: PUT part → B2<br/>(direct, not via API)

    Note over OA,W: 6. UPLOAD COMPLETE
    OA->>A: POST upload/complete
    A->>B: complete multipart
    A->>N: mark segment uploaded
    A-->>OA: 200 ok

    Note over OA,W: 7. STOP RECORDING
    OA->>A: POST stop
    A->>N: status=completed
    A->>W: enqueue evidence job
    A-->>OA: 200 recording

    Note over W: Worker:<br/>pull video,<br/>extract frames,<br/>write B2,<br/>INSERT evidence + frames
    W->>B: write frames
    W->>N: INSERT evidence + frames
```

---

### 9. Dispatch Sequence

```mermaid
sequenceDiagram
    participant OM as Operator/Manager
    participant A as API
    participant N as Neon
    participant AN as Audit/Notify

    OM->>A: PATCH /orders/{id}<br/>{status: dispatched, awb, courier}
    A->>A: validate transition<br/>(must be evidence_ready or policy)
    A->>N: UPDATE order
    A->>N: INSERT history
    A->>AN: write audit_log
    A->>AN: enqueue notif
    A-->>OM: 200 order
```

---

### 10. Claim Lifecycle Sequence

```mermaid
sequenceDiagram
    participant CE as Claims Exec
    participant A as API
    participant N as Neon
    participant B as B2 (signed)
    participant M as Marketplace

    CE->>A: POST /claims<br/>{orderId, reason}
    A->>N: load order + evidence
    A->>N: INSERT claim status=open
    A-->>CE: 201 claim

    CE->>A: GET evidence
    A->>B: generate signed URLs
    A-->>CE: 200 frames + URLs

    Note over CE,M: (review...)

    CE->>A: POST decide<br/>{approved/rejected}
    A->>N: UPDATE claim
    A->>AN: audit + notif
    A->>M: (optional) push reply to mkt
    A-->>CE: 200 claim
```

---

### 11. Return Lifecycle (Summary)

Similar to claims: **create → receive** (optional unboxing recording via packing flow) **→ inspect → decide** (refund/restock/reject). Evidence/recording attached via `unboxing_recording_id`. Decision writes audit + notif.

---

### 12. Marketplace Webhook Sequence

```mermaid
sequenceDiagram
    participant M as Marketplace
    participant A as API (public)
    participant V as Verify Sig
    participant Q as Queue Worker
    participant N as Neon

    M->>A: POST /marketplace/webhook/{prov}<br/>+ signature hdr
    A->>V: verify HMAC/signature
    V-->>A: ok
    A->>Q: enqueue job (raw payload)
    A-->>M: 200 OK

    Q->>Q: map event type
    Q->>N: upsert order/claim/ship
```

**Notes:** Signature check + enqueue. Processing is async. Idempotency key = provider event id.

---

### 13. Notification Delivery Sequence

```mermaid
sequenceDiagram
    participant DE as Domain Event
    participant A as API/Service
    participant N as Neon (notif row)
    participant NW as Notify Worker
    participant P as Provider

    DE->>A: claim.decided /<br/>order.dispatched /<br/>etc.
    A->>N: INSERT notif status=pending
    A->>NW: enqueue job

    NW->>NW: load template
    NW->>NW: render body
    NW->>P: send
    P-->>NW: 200/ok
    NW->>N: UPDATE sent
```

---

### 14. Background Worker Flows

#### 14.1 Typical BullMQ / Redis Worker Pattern

```mermaid
sequenceDiagram
    participant P as Producer (API)
    participant R as Redis Queue
    participant W as Worker Process

    P->>R: add job {name, data, opts}
    R->>W: BRPOP / subscribe
    R-->>W: job payload

    W->>W: process<br/>(AI / email / sync / evidence)

    alt on success
        W->>R: ACK / complete
    else on failure
        W->>R: retry with backoff<br/>or move to DLQ
    end
```

---

#### 14.2 Worker Types

| Queue | Job types | Side effects |
|:---|:---|:---|
| email | verify, invite, reset, claim_update | SMTP/SendGrid |
| marketplace-sync | orders_pull, shipments, im | Upsert D3/D6; update D7 |
| evidence | generate_from_recording | Read B2 video; write frames; D5 |
| ai | object_detect, ocr, mry | Update ai_jobs + optional evidence |
| notify | push, sms, whatsapp | FCM/SMS/WA providers |

---

## Part C — Component Interaction

### 15. Runtime Component Communication Map

```mermaid
flowchart TB
    subgraph Clients["CLIENTS"]
        FL["Flutter App"]
        AW["Admin Web"]
    end

    subgraph API["API Layer"]
        NEST["NestJS API"]
    end

    subgraph DataLayer["Data & Storage Layer"]
        REDIS["Redis<br/>cache, queues, OTP"]
        NEON2["Neon<br/>PostgreSQL"]
        B22["Backblaze B2<br/>private objects"]
    end

    subgraph Workers2["Workers"]
        W2["Workers<br/>(same image or scaled)"]
    end

    subgraph External["External Services"]
        SMTP["SMTP"]
        FCM["FCM"]
        SMS["SMS"]
        MKTAPI["Marketplace APIs"]
    end

    FL <-->|HTTPS/WSS| NEST
    AW <-->|HTTPS| NEST

    NEST --> REDIS
    NEST --> NEON2
    NEST --> B22

    REDIS -->|jobs| W2
    W2 --> NEON2
    W2 --> B22
    W2 --> SMTP
    W2 --> FCM
    W2 --> SMS
    W2 --> MKTAPI

    B22 -->|signed PUT/GET| FL
```

**Critical Rule:** Clients never talk to Redis, Neon, or B2 directly (except B2 via short-lived signed URLs issued by the API). Workers share the same DB and B2 credentials as the API.

---

### 16. Error & Retry Patterns

#### 16.1 API Layer

| Scenario | Response | Details |
|:---|:---|:---|
| Validation errors | 400 | With field details |
| Auth failures | 401 | Generic message |
| RBAC / tenant mismatch | 403 | — |
| Missing resource | 404 | — |
| Invalid state transition / duplicate | 409 | — |
| Rate limit | 429 | + Retry-After header |
| Unexpected | 500 | + requestId (logged with stack) |

#### 16.2 Upload Resilience

- Client may retry `upload/init`; server returns existing in-progress multipart if same `recording+seq`.
- Part PUT failures retried client-side against same signed URL until expiry.
- `upload/complete` is idempotent if segment already completed.

#### 16.3 Worker Resilience

- Exponential backoff with jitter; max attempts then dead-letter queue.
- Jobs carry idempotency keys (`orderId`, `recordingId`, `eventId`).
- Poison messages inspected via admin tooling; re-queue after fix.

---

> **Closing Statement**
>
> These DFDs and sequence diagrams are the behavioural companion to the Architecture, Database Design, and OpenAPI documents. Implementers should treat the sequences as the authoritative interaction contracts between Flutter, NestJS, workers, Neon, and Backblaze.

---

*End of Volume 2B: Data Flow & Sequence Diagrams — Version 3.0 • Confidential • PrimeCore Technologies*
