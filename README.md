# Promotion Studio — Singtel-oriented reference platform

An enterprise promotion management vertical slice with a React / TypeScript dashboard and independently deployable Java services. This is an interview/reference architecture, **not Singtel's actual internal platform**. All sample customer data is synthetic.

## What is implemented

- Promotion lifecycle, optimistic version checks, independent approval, scheduled activation / expiry, audit timeline.
- Immutable SHA-256 rule snapshots, typed AND / OR / NOT / EQ / IN / GTE expressions, bounded complexity, simulation and explanation.
- Customer lookup, eligibility composition, decimal discount calculation.
- Transactional redemption with pessimistic campaign locking, scoped unique idempotency keys, customer and campaign caps, budget enforcement, repeatable cancellation, transactional outbox and an at-least-once Kafka relay.
- API gateway routing, JWT verification in the production profile, role checks, correlation IDs, fixed request/time limits, and a local rate limiter.
- Responsive campaign overview, six-step wizard, rule builder, approvals, customer offers, redemption history and analytics; browser demo and API adapters.
- Buildable Maven modules, unit/concurrency tests, PostgreSQL Testcontainers suite, frontend tests, Playwright workflows, Docker Compose, Helm deployment baseline, AWS Terraform baseline, CI checks and operations documentation.

This is the explicitly requested first vertical slice. Notification/analytics microservices, durable event consumers, production OIDC browser login, Redis cache invalidation, distributed rate limiting, broad contract/resilience/security testing, and cloud validation remain in the next phases. The UI's operations pages disclose missing integrations rather than fabricate results. See [readiness](docs/production-readiness.md).

## Explore the dashboard

```sh
cd frontend
npm ci
npm run dev
```

Open http://127.0.0.1:5173. The default **synthetic demo** persists data in this browser's local storage. Choose Manager / Approver / Analyst / Admin in the header to inspect permissions. Browser storage and floating-point demo amounts are presentation aids; Java/PostgreSQL provide transactional correctness and decimal money.

Create a draft → submit from its details → switch to Approver → approve → switch back to Manager → activate → Customers → select a synthetic profile → inspect eligibility → redeem. C00002 is Postpaid. Rule versions are published directly in this slice; a separate editable rule-definition lifecycle is deferred.

## Run the Java slice

Prerequisites: JDK 21+ (compilation targets Java 21), Maven 3.9.11+, Node 22.12+ or 24, optionally Docker for PostgreSQL integration tests and Compose.

```sh
cd backend
mvn -B clean verify
cd ..
./scripts/start-local.sh
```

The default `local` profile uses a distinct persistent H2 database for each service and **explicit development-only authentication**. Services bind to loopback. `X-Demo-Role: MANAGER|APPROVER|ANALYST|ADMIN` chooses a synthetic server identity; do not expose this profile to external networks. `production` requires a reachable issuer and a signed JWT with `aud=promotion-platform` and top-level `roles` claim. Never deploy the local authentication profile in production.

```sh
python3 scripts/smoke.py
```

This exercises real HTTP endpoints through the gateway: publish rule → create → submit → approve with different identity → activate → evaluate → redeem twice with one key → cancel twice. `Ctrl+C` terminates the local Java processes started by the script.

To connect the React UI, set `frontend/.env.local`:

```dotenv
VITE_API_MODE=live
# Use Vite's same-origin proxy for local development.
VITE_API_URL=
VITE_LOCAL_AUTH=true
```

With `VITE_LOCAL_AUTH=true` the demo role header is sent explicitly for local Java APIs. For production omit it, provide a short-lived JWT in Settings, and front the APIs with the same origin. Manual token entry is for integration validation; a full OIDC authorization-code + PKCE login must replace it before production. No live credentials belong in frontend environment variables.

## Container deployment

```sh
cp .env.example .env
# Supply unique local credentials in .env (not committed).
docker compose up --build
```

Dashboard: http://127.0.0.1:3000; gateway: http://127.0.0.1:8080; identity provider: http://127.0.0.1:8180; Prometheus: http://127.0.0.1:9090; Grafana: http://127.0.0.1:3001. Databases, Redis and Kafka are reachable only on the private Compose network. Compose uses local authorization for the reference workflow; changing to production requires OIDC realm/clients/roles setup and issuer networking. Infrastructure images are pinned to tags; production must promote scanned digest references.

## Repository

```text
frontend/                 React, Vite, MUI, TanStack Query, RHF/Zod, Playwright
backend/
  platform-common/        Security, Problem Details, HTTP clients, outbox
  api-gateway/            Routing and external API entry point
  promotion-service/      Lifecycle, approval, budgets/terms, versioning
  rule-engine-service/    Immutable rule publication and evaluation
  customer-service/       Synthetic profile and subscription attributes
  eligibility-service/    Synchronous customer/promotion/rule composition
  redemption-service/     Authoritative capacity ledger and redemption
infra/                    Compose support, Helm, AWS Terraform baseline
observability/            Prometheus, collector and alert configuration
scripts/                  Local launch, real HTTP workflow smoke test, k6
.github/workflows/        Repeatable checks, tests, build and image scan
 docs/                    Requirements, architecture, API/events, runbooks/readiness
```

## Verification

`npm test`, `npm run build`, `npx playwright test` in frontend; `mvn verify` in backend. PostgreSQL concurrency tests automatically skip if Docker is unavailable; CI must run them with Docker and treat unexpected skips as a failed release gate. See [validation results](docs/validation.md) for what was actually run.

Read [requirements](docs/requirements.md), [architecture](docs/architecture.md), [contracts](docs/contracts.md), [operations](docs/runbooks.md), and [production readiness](docs/production-readiness.md) before treating this reference as a production deployment.
