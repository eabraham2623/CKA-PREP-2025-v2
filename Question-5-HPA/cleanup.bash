#!/bin/bash
# Cleanup script for Question 5 - HPA
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../scripts/lib/variant.sh
source "$REPO_ROOT/scripts/lib/variant.sh"
# shellcheck source=variants.bash
source "$SCRIPT_DIR/variants.bash"

echo "Cleaning up Question 5: HPA..."

# Clean every preset, not only the recorded one, so switching variants and
# re-running cleanup is safe even if an earlier run left stale resources.
for ((v = 1; v <= VARIANT_COUNT; v++)); do
  variant_config "$v"
  echo "  Removing variant $v resources (HPA '$HPA', deployment '$DEPLOY')..."
  kubectl delete hpa "$HPA" -n "$NS" --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete deployment "$DEPLOY" -n "$NS" --ignore-not-found \
    --cascade=foreground --wait=true --timeout=90s >/dev/null 2>&1 || true
  kubectl delete service "$DEPLOY" -n "$NS" --ignore-not-found >/dev/null 2>&1 || true
done

if kubectl get namespace "$NS" >/dev/null 2>&1; then
  echo "  Removing namespace '$NS'..."
  kubectl delete namespace "$NS" --ignore-not-found >/dev/null 2>&1 || true
  kubectl wait --for=delete "namespace/$NS" --timeout=60s 2>/dev/null || true
fi

echo "  Removing metrics-server..."
kubectl delete deployment metrics-server -n kube-system --ignore-not-found >/dev/null 2>&1 || true

rm -f ~/hpa.yaml hpa.yaml

cka_variant_clear "$SCRIPT_DIR"

echo "[OK] Question 5 cleanup complete"
