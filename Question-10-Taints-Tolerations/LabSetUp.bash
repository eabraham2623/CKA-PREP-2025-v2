#!/bin/bash
# LabSetUp.bash for Question 10 - Taints & Tolerations
set -euo pipefail

if (( $# > 1 )); then
  echo "Usage: $0 [variant]" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../scripts/lib/variant.sh
source "$REPO_ROOT/scripts/lib/variant.sh"
# shellcheck source=variants.bash
source "$SCRIPT_DIR/variants.bash"

if ! kubectl get node "$NODE" >/dev/null 2>&1; then
  echo "Error: node '$NODE' not found. Run this lab in a cluster with a worker named $NODE." >&2
  exit 1
fi

VARIANT="$(cka_variant_select "$SCRIPT_DIR" "$VARIANT_COUNT" "${1:-}")"
variant_config "$VARIANT"

echo "============================================================"
echo " Question 10: Taints & Tolerations"
echo " Variant $VARIANT/$VARIANT_COUNT selected for this run"
echo " $VARIANT_SUMMARY"
echo "============================================================"
echo

# Start from a clean slate: remove every preset's taint and the pods from an
# earlier attempt. The selected taint is deliberately not applied here; adding
# it is part of the exercise.
echo "Removing resources from earlier attempts or variants..."
for ((v = 1; v <= VARIANT_COUNT; v++)); do
  variant_config "$v"
  kubectl taint nodes "$NODE" "${TAINT_SPEC}-" >/dev/null 2>&1 || true
done
variant_config "$VARIANT"

kubectl delete pod "$POD_NAME" "$POD_NAME-fail" -n "$POD_NAMESPACE" \
  --ignore-not-found --wait=true >/dev/null 2>&1 || true

echo
variant_question "$VARIANT"
