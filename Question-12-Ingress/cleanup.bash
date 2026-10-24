#!/bin/bash
# Cleanup script for Question 12 - Ingress
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../scripts/lib/variant.sh
source "$REPO_ROOT/scripts/lib/variant.sh"
# shellcheck source=variants.bash
source "$SCRIPT_DIR/variants.bash"

echo "Cleaning up Question 12: Ingress..."

# Remove every preset's resources, not just the recorded variant's, so
# switching variants and re-running cleanup is safe after a partial attempt.
for ((v = 1; v <= VARIANT_COUNT; v++)); do
  variant_config "$v"
  kubectl delete ingress "$INGRESS" -n "$NS" --ignore-not-found --wait=true --timeout=30s >/dev/null 2>&1 || true
  kubectl delete service "$SERVICE" -n "$NS" --ignore-not-found --wait=true --timeout=30s >/dev/null 2>&1 || true
  kubectl delete deployment "$DEPLOYMENT" -n "$NS" --ignore-not-found --wait=true --timeout=60s >/dev/null 2>&1 || true
done

kubectl delete namespace "$NS" --ignore-not-found --wait=true --timeout=120s
rm -f "$HOME/ingress.yaml"
cka_variant_clear "$SCRIPT_DIR"

echo "[OK] Question 12 cleanup complete"
