# Verification results — 11 October 2026

Performed on the developer workstation. Java runtime was Homebrew OpenJDK 25; Maven compiled all modules with release 21. No production/cloud guarantees are inferred from these results.

| Check | Actual result |
|---|---|
| Maven multi-module package | PASS: all six executable services plus common library |
| Java unit / local DB integration tests | PASS: 15 tests; lifecycle/approval, rule boundaries/unsafe expressions, decimal rounding/currency, concurrent cap enforcement, idempotency/conflicts, per-customer limit, repeated/concurrent cancellation and atomic outbox counts |
| PostgreSQL Testcontainers | 4 tests SKIPPED because Docker is unavailable; CI explicitly rejects skipped PostgreSQL suite |
| Real Java HTTP acceptance | PASS: all six services running on loopback; published rule, draft, submit, independent approve, activate, customer eligibility, same-key redemption retry and repeat cancellation via gateway |
| React TypeScript + Vite production build | PASS |
| Frontend unit suite | PASS: 4 tests |
| Chromium Playwright suite | PASS: 4 workflows — campaign search/rule simulation; independent approval/activation; full wizard/create/submit/approve/activate/customer/redeem; mobile navigation and no document horizontal overflow |
| Helm | PASS: lint and rendered YAML; 32 Kubernetes resources; no cluster deployment |
| YAML / event JSON | PASS: Compose, CI and monitoring configuration parsed; event schema JSON parsed |
| Terraform | PASS: terraform fmt and provider-backed validate; AWS provider 6.15.0 lockfile; no plan/apply or AWS resource creation |
| Container build / Compose / broker relay | NOT RUN: Docker unavailable |
| Load / chaos / security scan / accessibility audit | NOT RUN; source/configuration provided where stated, release gates remain |

The browser creation test caught an actual premature-submit issue when the Continue button was reconciled into Save on the final step. Separate button keys/types and a submit-step guard fixed it; the entire browser workflow subsequently passed. The cancellation test verifies refreshing the redemption after taking the shared campaign lock, preventing a cached stale status from releasing capacity twice.

Frontend build is roughly 950 kB uncompressed / 291 kB gzip before route-level lazy loading; acceptable for the demonstrator, but route/charts splitting and performance budgets are production work. Performance SLOs have not been measured. Container image pins and dependency scans must be reviewed before release.
