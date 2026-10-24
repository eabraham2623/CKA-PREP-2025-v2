#!/bin/bash
# Cleanup script for Question 10 - Taints & Tolerations
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../scripts/lib/variant.sh
source "$REPO_ROOT/scripts/lib/variant.sh"
# shellcheck source=variants.bash
source "$SCRIPT_DIR/variants.bash"

echo "Cleaning up Question 10: Taints & Tolerations..."

# Remove every preset's taint, not just the recorded variant's, so switching
# variants and re-running cleanup is safe even after a partial attempt.
for ((v = 1; v <= VARIANT_COUNT; v++)); do
  variant_config "$v"
  kubectl taint nodes "$NODE" "${TAINT_SPEC}-" >/dev/null 2>&1 || true
done

# Delete the pods created for this question in either the solution or the
# optional negative test.
kubectl delete pod "$POD_NAME" "$POD_NAME-fail" -n "$POD_NAMESPACE" \
  --ignore-not-found >/dev/null 2>&1 || true

cka_variant_clear "$SCRIPT_DIR"

echo "[OK] Question 10 cleanup complete"
