# Operations and incident runbooks

## Signals and SLO agreement

Logs are structured JSON with a bounded correlation ID. `/actuator/health/liveness` and `/readiness` support probes; `/actuator/prometheus` exposes Micrometer HTTP/JVM/Hikari metrics. Keep `/actuator` internal; production metrics access currently requires an ADMIN token and Prometheus must receive one through secret-backed configuration. Compose uses local profile on a private network. Tracing is not automatically enabled by the included collector: connect a reviewed OpenTelemetry Java agent and configure OTLP for the next phase.

Agree latency, availability and error budgets with operations. Proposed SLIs: successful eligible-offer requests / valid requests; redemption p95/p99 latency; committed cap violation count (target zero); duplicate committed effects per idempotency key (zero); oldest pending outbox age; Kafka consumer lag when consumers exist. Measure saturation, pool pending connections and ledger lock wait. Do not publish an availability guarantee until the service budget, load model and failure tests support it.

| Incident | Investigation and safe action |
|---|---|
| Activation failure | Follow correlation ID; confirm state/version, independent approval, rule UUID and validity window; inspect scheduler/outbox; retry only after resolving conflict, never edit status directly in DB |
| Rule latency | Inspect HTTP/JVM metrics and AST sizes; reject over-complex inputs; reduce candidate fan-out; disable problematic new campaign revision through lifecycle; preserve immutable rule for audit |
| Duplicate redemption | Compare actor/key/payload and DB unique constraint; a retry should return original ID; inspect ledger against redeemed history; alert on multiple effects, preserve evidence; never reset keys to force another redemption |
| Concurrent cancellation | Confirm ledger lock and cancellation status; reconcile count/spend against REDEEMED records; repeated cancel must be a no-op; quarantine inconsistent campaign before manual repair |
| Kafka unavailable / relay lag | Check broker health/auth, pending rows, publisher errors and partition capacity; DB outbox retains committed events; repair connectivity then replay; duplicates are expected and consumers must deduplicate |
| Database saturation | Inspect Hikari pending/active and slow lock queries, hotspot campaign contention, disk/CPU; shed traffic at gateway; avoid increasing pool beyond DB capacity; fail safely rather than bypass checks |
| Deployment failed | Compare image digest/config/schema compatibility; check startup/readiness and logs; `helm rollback` to previous compatible version; database migration rollback needs explicit compatibility assessment, not blind destructive DDL |
| Cache inconsistency | No cache is active in this slice; when added, bypass/invalidate by version, inspect event offsets and expiration boundaries; always use transactional redemption checks |
| Security incident | Restrict ingress/revoke affected identity tokens, rotate compromised secret via approved process, preserve audit and trace evidence; notify organizational incident owner; follow privacy/legal retention policy |

## Disaster recovery and deployment

Use environment-separated accounts/namespaces/keys and immutable release tags. Back up RDS with PITR and test restore into an isolated environment. Kafka replay is limited by retention; outbox cleanup must respect consumer recovery windows. Store Terraform state remotely with locking, access controls and encryption; secrets may exist in state even when marked sensitive. Agree RPO/RTO and validate a cross-AZ failure/restore drill before production approval.

Roll forward only after readiness, synthetic promotion/eligibility/redemption smoke and error/latency criteria pass. Define health criteria and automatic rollback at the deployment controller; CI currently builds/tests/scans and does not pretend to run cloud promotion without configured environments. Production requires a protected environment with explicit approval.
