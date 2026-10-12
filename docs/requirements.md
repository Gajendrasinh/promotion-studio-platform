# Scope, requirements and acceptance criteria

## Assumptions

Singtel is the telecom design context, not an assertion of internal systems. Customer identities and plan/segment references come from authoritative upstream systems. This first slice is a staff-operated campaign platform; direct customer self-service and subscription/billing adapters need additional subject ownership checks. Development uses synthetic Singapore profiles and SGD. Spend is a supplied customer eligibility attribute; connecting bill-level offer application requires an authoritative billing quote and compensation workflow.

All service instants use UTC; UI dates display Asia/Singapore and wizard date-time inputs use the user's browser timezone. Validity is `[start, end)`. Monetary persistence uses DECIMAL and Java BigDecimal; redeemed money has two decimal places and HALF_UP rounding. Benefits have zero recorded discount cost until a benefit valuation adapter is introduced. Campaign terms are immutable after creation in this slice; edits and reapproval of new campaign versions are future work. No approval from the campaign creator is allowed, including administrators.

## User stories and acceptance criteria

| Actor | Story | Acceptance |
|---|---|---|
| Manager | Create and submit a campaign | Unique code, valid dates, positive caps/budget, percent <=100, published rule UUID; begins DRAFT; only DRAFT can submit |
| Approver | Independently review terms | Caller has approver/admin JWT role; creator differs from approver; only PENDING_APPROVAL can approve; every change appears in history |
| Manager | Activate or schedule an approved offer | ACTIVE requires current validity; SCHEDULED requires a future start; invalid transition returns 409; stale version returns 409 |
| Manager | Define explainable eligibility | Only whitelisted typed fields/operators; <=100 nodes, depth <=8, <=20 group children; immutable published SHA-256 snapshot; simulation explains each predicate and group |
| Staff | Look up a customer's offers | Only ACTIVE offers in validity; active customer; exact published rule evaluated; missing facts fail closed; downstream failures produce 503, not an eligible result |
| Staff | Redeem an eligible offer | Stable actor-scoped idempotency key; same parameters return same transaction; conflicting parameters return 409; customer/campaign/budget limits checked inside DB transaction |
| Staff | Cancel a redemption | Campaign lock serializes competing cancellations; capacity released once; original record retained and cancellation timestamp/event recorded |
| Analyst | Inspect performance | Metrics derived from redemption records; no invented conversion/exposure counts; segment/date selection and report export |
| Operations | Diagnose incidents | Correlation IDs, structured logs, actuator probes, Prometheus endpoint, durable pending outbox records; no public admin/data endpoints |

## Non-functional requirements needing agreement

Before release, business and operations must agree on peak eligibility/redemption QPS, campaign count, audience sizes, allowable staleness, SLO measurement windows, latency percentiles, RPO/RTO and retention. Proposed evaluation targets: 95% eligibility <250 ms at the agreed load; 99% redemption <500 ms excluding external billing; zero committed cap violations and zero duplicate committed offers per idempotency scope. These are validation targets, not availability guarantees.

Current eligibility calls are sequential and bounded to the first 100 campaign records; this is appropriate only for the reference slice. High-scale release requires server-side active candidate indexing, cursor pagination, bounded concurrent rule evaluation and versioned cache invalidation. Per-campaign ledger locking favors correctness; a popular campaign is a contention boundary. Benchmark with realistic bursts before deciding on partitioned inventory/reservations.

## Phases

1. Requirements and diagrams — delivered.
2. Service-owned schemas / API and event contracts — slice delivered; broad service contracts deferred.
3. Repository, builds and local configuration — delivered.
4. Five-service vertical slice + gateway and UI — delivered; edit/version workflow and full OIDC login deferred.
5. Containers / Kubernetes / cloud — deployment baselines delivered; deployment verification deferred.
6. Expand notification delivery, analytics projection, cache invalidation, billing reservations/compensation, event deduplication and registry compatibility gates.
7. Complete contract, authorization, accessibility, load, chaos, restore and multi-AZ tests; approve SLOs and production launch gates.
