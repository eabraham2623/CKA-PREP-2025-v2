#!/bin/bash
# Cleanup script for Question 11 - Gateway API
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../scripts/lib/variant.sh
source "$REPO_ROOT/scripts/lib/variant.sh"
# shellcheck source=variants.bash
source "$SCRIPT_DIR/variants.bash"

echo "Cleaning up Question 11: Gateway API..."

# Remove every preset's resources, not just the recorded variant's, so
# switching variants and re-running cleanup is safe after a partial attempt.
for ((v = 1; v <= VARIANT_COUNT; v++)); do
  variant_config "$v"
  kubectl delete httproute "$HTTPROUTE" -n "$NS" --ignore-not-found --wait=true --timeout=30s >/dev/null 2>&1 || true
  kubectl delete gateway "$GATEWAY" -n "$NS" --ignore-not-found --wait=true --timeout=30s >/dev/null 2>&1 || true
  kubectl delete gatewayclass "$GATEWAY_CLASS" --ignore-not-found --wait=true --timeout=30s >/dev/null 2>&1 || true
  kubectl delete ingress "$INGRESS" -n "$NS" --ignore-not-found --wait=true --timeout=30s >/dev/null 2>&1 || true
  kubectl delete secret "$TLS_SECRET" -n "$NS" --ignore-not-found --wait=true --timeout=30s >/dev/null 2>&1 || true
  kubectl delete service "$SERVICE" -n "$NS" --ignore-not-found --wait=true --timeout=30s >/dev/null 2>&1 || true
  kubectl delete deployment "$DEPLOYMENT" -n "$NS" --ignore-not-found --wait=true --timeout=60s >/dev/null 2>&1 || true
done

rm -f "$HOME/gw.yaml" "$HOME/http.yaml"
cka_variant_clear "$SCRIPT_DIR"

echo "[OK] Question 11 cleanup complete"
echo "NOTE: Gateway API CRDs are left in place as they are cluster-wide."
