#!/bin/bash
# Cleanup script for Question 6 - CRDs (cert-manager)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../scripts/lib/variant.sh
source "$REPO_ROOT/scripts/lib/variant.sh"
# shellcheck source=variants.bash
source "$SCRIPT_DIR/variants.bash"

echo "Cleaning up Question 6: CRDs (cert-manager)..."

kubectl delete deployment "$DEPLOYMENT" -n "$NS" --ignore-not-found >/dev/null 2>&1 || true
kubectl delete namespace "$NS" --ignore-not-found --wait=true --timeout=120s >/dev/null 2>&1 || true
kubectl delete crd "${CERT_MANAGER_CRDS[@]}" --ignore-not-found >/dev/null 2>&1 || true

for ((v = 1; v <= VARIANT_COUNT; v++)); do
  variant_config "$v"
  rm -f "$FIELD_FILE"
done
rm -f "$RESOURCES_FILE"

cka_variant_clear "$SCRIPT_DIR"

echo "[OK] Question 6 cleanup complete"
