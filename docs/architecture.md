# Architecture and design decisions

## Target topology

Solid paths represent implemented synchronous operations. The Kafka relay exists; downstream notification/reporting projections and Redis integration are the next phase. Cloud components are a deployment design, not deployed resources.

```mermaid
flowchart TB
  Staff[Staff React / TypeScript / MUI] --> ALB[AWS ALB + ACM TLS + Route 53]
  Staff <--> IdP[External OIDC provider / local Keycloak]
  ALB --> Gateway[API gateway: JWT / RBAC / correlation / limits]
  Gateway --> Promo[Promotion service]
  Gateway --> Customer[Customer service]
  Gateway --> Rules[Rule engine service]
  Gateway --> Eligibility[Eligibility service]
  Gateway --> Redemption[Redemption service]
  Eligibility --> Customer
  Eligibility --> Promo
  Eligibility --> Rules
  Redemption --> Eligibility
  Promo --> PDB[(Owned promotion database)]
  Customer --> CDB[(Owned customer database)]
  Rules --> RDB[(Owned rule database)]
  Redemption --> DDB[(Owned redemption database + ledger)]
  PDB --> Outbox[Transactional outbox relay]
  RDB --> Outbox
  DDB --> Outbox
  Outbox --> Kafka[Kafka / Amazon MSK: versioned events]
  Kafka -.-> Notifications[Next phase: notification service]
  Kafka -.-> Analytics[Next phase: analytics projection]
  Kafka -.-> Invalidation[Next phase: cache invalidation consumers]
  Eligibility -.-> Redis[(Next phase: Redis / ElastiCache)]
  Notifications -.-> Providers[Consent-aware SMS / email / push adapters]
  Gateway --> Telemetry[Prometheus / OTel collector / Grafana / CloudWatch]
```

Every business service owns its database. The local Compose database host has isolated databases for practicality; AWS RDS can share a managed cluster with separately scoped service credentials. Foreign keys never cross a service boundary. Kafka provides at-least-once delivery: a publish acknowledgment followed by a crash before marking the row can create a duplicate. Event consumers must commit a deduplication marker with their projection update. There are no implemented consumers yet, and no exactly-once claim.

## Promotion workflow

```mermaid
sequenceDiagram
  actor Manager
  actor Approver
  participant UI as React
  participant Rules as Rule Engine
  participant Promotion
  participant DB as Promotion DB / Outbox
  participant Kafka
  Manager->>UI: Build / simulate typed rule
  UI->>Rules: Publish validated immutable snapshot
  Rules-->>UI: Rule UUID + SHA-256 checksum
  Manager->>UI: Create offer, budget, dates, rule UUID
  UI->>Promotion: POST /promotions
  Promotion->>Rules: Verify published snapshot exists
  Promotion->>DB: Commit DRAFT + audit + outbox
  Manager->>Promotion: Submit with expected version
  Promotion->>DB: PENDING_APPROVAL + audit + outbox
  Approver->>Promotion: Approve with expected version
  Promotion->>Promotion: Verify role / different actor / state
  Promotion->>DB: APPROVED + audit + outbox
  Manager->>Promotion: Activate (or schedule)
  Promotion->>DB: ACTIVE + audit + outbox atomically
  DB->>Kafka: Relay committed event, retry after failure
```

## Redemption workflow

```mermaid
sequenceDiagram
  actor Staff
  participant Gateway
  participant Redemption
  participant Eligibility
  participant Sources as Customer / Promotion / Rule
  participant DB as Redemption DB
  participant Kafka
  Staff->>Gateway: POST redemption + Idempotency-Key
  Gateway->>Redemption: Verified token + correlation
  Redemption->>DB: Find existing actor + key
  alt Existing key
    DB-->>Redemption: Original transaction
    Redemption-->>Staff: Same result or conflicting-payload 409
  else New key
    Redemption->>Eligibility: Customer + promotion eligibility
    Eligibility->>Sources: Current facts / exact immutable rule
    Sources-->>Eligibility: Eligibility decision and explanation
    Eligibility-->>Redemption: Decision + offer terms + spend
    Redemption->>DB: Begin transaction, lock campaign ledger
    Redemption->>DB: Recheck key / own cap / campaign cap / budget
    Redemption->>DB: Commit ledger + redemption + outbox
    Redemption-->>Staff: Created redemption
    DB->>Kafka: At-least-once outbox relay
  end
```

## Major trade-offs

- **Typed rule AST rather than Drools:** the required boolean/comparison rules do not need agenda inference. This model is small, predictable, explainable and cannot execute user code. Drools becomes relevant if complex temporal rules or expert-maintained inference justify its operational complexity. Deterministic predicate order follows JSON child order; this slice applies each promotion independently and does not implement cross-offer priority/stacking conflict resolution.
- **PostgreSQL transaction/unique constraint/row lock:** guarantees budget/cap correctness within redemption ownership; Redis is not an authority. Creating a first ledger row can race, so the controller retries the whole rolled-back transaction up to three times after a uniqueness violation. Cancellation takes the same lock and refreshes the cached record before changing counters.
- **No distributed transaction:** eligibility is fetched before the redemption DB transaction. Campaign pause/customer change may race with redemption; this slice defines validity at eligibility read plus expiry recheck at commit. A strict “nothing commits after pause” policy requires authoritative reservations or revision fencing coordinated with promotion lifecycle. Do not claim that strict invariant here.
- **Outbox over dual-write:** committing business data and event record together prevents lost events from the DB/Kafka gap. The relay is simple; multiple replicas can publish duplicates. Production requires monitored retries, bounded backoff, poison-event handling and idempotent consumers.
- **No eligibility cache yet:** avoids introducing stale consent/usage decisions before event consumers exist. Future cache keys must include customer attribute version, rule checksum, campaign version and effective date; TTL must not exceed the next boundary, and transactional usage checks always occur at redemption.
- **REST for decisions, Kafka for projections:** lets a user receive an immediate explainable outcome while reporting/delivery stay off the transactional path. HTTP client has bounded connect/read timeouts and does not retry writes. Circuit breakers, bulkheads and provider retries remain a release gate.
- **Monorepo with separate executables:** one pinned BOM and reusable technical concerns reduce initial drift while every service remains an independent deployable JAR/image. No domain entity classes are shared across services. The first slice uses internal JSON maps for composition; harden these to generated versioned DTOs and contract tests next.
- **Security is enforced server-side:** production JWT issuer, signature, timestamps, audience and roles are checked by each service. Local profile identities are deliberately synthetic. Gateway limiting is per-process; WAF/distributed Redis limiting is needed for multi-replica enforcement.
