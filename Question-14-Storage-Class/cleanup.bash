#!/bin/bash
# Cleanup script for Question 14 - Storage Class
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../scripts/lib/variant.sh
source "$REPO_ROOT/scripts/lib/variant.sh"
# shellcheck source=variants.bash
source "$SCRIPT_DIR/variants.bash"

echo "Cleaning up Question 14: Storage Class..."

# Remove every preset's class, not just the recorded variant's, so switching
# variants and re-running cleanup is safe after a partial attempt.
for ((v = 1; v <= VARIANT_COUNT; v++)); do
  variant_config "$v"
  kubectl delete storageclass "$SC_NAME" --ignore-not-found >/dev/null 2>&1 || true
done

# Restore the playground's original default StorageClass.
kubectl patch storageclass "$EXISTING_SC" \
  -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}' \
  >/dev/null 2>&1 || true

rm -f "$ANSWER_FILE"
cka_variant_clear "$SCRIPT_DIR"

echo "[OK] Question 14 cleanup complete"
