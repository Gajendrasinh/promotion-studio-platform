# Production readiness: deliberately NOT approved

The repository implements the first requested vertical slice and deployment baselines. It is not a complete production platform. Do not equate a successful build with enterprise readiness.

## Release gates

- [x] Meaningful independent service logic; typed rule model; no arbitrary expression execution.
- [x] Promotion state machine / independent approval / optimistic versions.
- [x] Decimal server money; transactionally enforced redemption caps, budgets and scoped idempotency.
- [x] Business changes + outbox records committed atomically.
- [x] React flows and explicit synthetic/demo identity distinction.
- [ ] Java 21 runtime test matrix (development host is Java 25, bytecode targets 21).
- [ ] Docker / PostgreSQL / Flyway / Kafka / Helm / Terraform end-to-end deployment verification.
- [ ] Spring Boot 3.x support contract confirmed. 3.5.16 is pinned and Java 21-compatible; as of October 2026 a 3.x production deployment needs extended support or a separately reviewed migration to Boot 4.x. Sources: https://docs.spring.io/spring-boot/3.5/system-requirements.html and https://spring.io/projects/spring-boot/.
- [ ] Security-validated OIDC authorization-code + PKCE login, secure token handling, service workload identity/token exchange, separate internal API scopes and customer subject checks.
- [ ] Uniform authentication Problem Details, strict production CORS, ingress body limit before allocation, WAF/distributed rate limit, CSP and CSRF review for chosen auth architecture.
- [ ] Editable/reapproval campaign versions, separate rule definitions and versions, precedence/stacking conflict policy, authoritative bill discount application, reservations and saga compensation.
- [ ] Strict pause/revoke vs in-flight redemption consistency policy and version fencing/reservation protocol.
- [ ] Rule DTO contract generation, active candidate pagination, safe cache keys + event-driven invalidation, bounded fan-out, circuit breakers/bulkheads.
- [ ] Idempotent event consumers, schema compatibility gate/registry, poison-event backoff/DLQ and durable notification status with consent.
- [ ] Analytics projection/exposure events and full date/segment APIs; operational UI connected to live health/delivery adapters.
- [ ] Complete requirements-level Testcontainers, WireMock, API contract, authorization/JWT, outbox crash/replay, timezone/DST, rounding, accessibility, chaos and load suites.
- [ ] Immutable separate audit transition tables, administrative audit, validated retention/deletion policy, encrypted backups and restored DR drill.
- [ ] Tracing agent/instrumentation validated, business metrics added, dashboards/alerts tuned against approved SLO and operational ownership.
- [ ] Multi-AZ RDS/Redis/Kafka, private data endpoints, Secrets Manager integration, resource identity, TLS between services, NetworkPolicy enforcement validated.
- [ ] Scanned image digests/SBOM/signatures, branch protections, quality gates, staged deploy/smoke/load/security gates, explicit production approval and rollback tested.

## Infrastructure baseline limitations

Helm supplies deployments/probes/resources/HPA/PDB/topology/network policy and external secrets references. It is a starting point; no public ingress is enabled by default. AWS Terraform provisions private networking, EKS managed nodes, ECR and an encrypted RDS baseline; managed Redis/MSK, ALB controller, ACM/Route53, secret provisioning, telemetry export and service-owned database roles must be connected before deployment. Terraform is not applied. State uses a separately configured encrypted remote backend; never use shared local state in production.

Pinning an image tag is reproducible only while the registry tag is immutable. Production promotion must use reviewed digests and continually scan/rebuild base images; dependency pinning alone is not evidence of current support or absence of vulnerabilities.

## Scale review

One campaign ledger row serializes redemption for a campaign. That gives a clear invariant and may constrain hotspot throughput. Measure lock wait / conflict rate / pool saturation before redesign. A reservation inventory with fenced, partitioned capacity can improve throughput, but is significantly harder to reconcile. Current eligibility fetches at most 100 campaigns; no high-scale claim is made. Budgets, caps, rule snapshots, cache TTL and pause semantics need a written policy shared by business and engineering.
