# Development conventions

Keep service domain ownership local; only transport/security/outbox infrastructure belongs in platform-common. Use Java 21 language features, constructor injection, Jakarta Bean Validation DTOs, typed rule nodes, explicit transactions and BigDecimal for money. Never add cross-service ORM references or user-executable expressions. Current composition maps should migrate to generated typed contracts as the API stabilizes.

All changes to promotion/redemption state need an audit entry/event in the same local DB transaction. Every retried command needs a documented idempotency scope and conflict semantics. Evaluate eligibility before acquiring the campaign DB lock; never perform external HTTP calls while holding that lock. Do not retry arbitrary writes. Test invariants and failure boundaries rather than implementation details.

Frontend uses TypeScript strict mode, React Router, TanStack Query, RHF/Zod and MUI dialogs/fields. Prefer reusable table/metric/status/rule/timeline components and semantic keyboard-accessible controls. Preserve explicit loading/error/empty states and confirm irreversible business state changes. Browser demo logic is for synthetic product review, not the authority for security or transaction correctness. Use route-level splitting before expanding the current single application module significantly.

Pin dependencies and commit package-lock.json and Terraform provider lockfiles. Java transitive dependencies inherit the pinned Spring Boot BOM. Upgrade BOMs/images deliberately, scan resulting artifacts and rerun compatibility tests. Pin CI action references to reviewed SHA revisions before enabling releases. No real profile data, credentials or generated runtime database files belong in source control.

Run backend `mvn verify`, frontend `npm test && npm run build`, Playwright `npx playwright test`, Helm lint/template and Terraform fmt/validate. PostgreSQL tests must run in CI with Docker. Production support, secrets, policy, load/resilience/a11y and deployment validation gates are tracked in production-readiness.md.
