#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .runtime
pids=()
cleanup() { if [ ${#pids[@]} -gt 0 ]; then kill "${pids[@]}" 2>/dev/null || true; fi; }
trap cleanup EXIT INT TERM
for service in promotion-service rule-engine-service customer-service eligibility-service redemption-service api-gateway; do
  jar="backend/$service/target/$service-0.1.0.jar"
  if [ ! -f "$jar" ]; then echo "Missing $jar; run mvn package in backend first." >&2; exit 1; fi
  java -Xms64m -Xmx256m -jar "$jar" --spring.profiles.active=local > ".runtime/$service.log" 2>&1 &
  pids+=("$!")
done
echo 'Starting services on loopback ports 8080–8085. Logs: .runtime/. Stop with Ctrl+C.'
wait
