#!/bin/bash
# LabSetUp.bash for Question 14 - Storage Class
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

VARIANT="$(cka_variant_select "$SCRIPT_DIR" "$VARIANT_COUNT" "${1:-}")"
variant_config "$VARIANT"

echo "============================================================"
echo " Question 14: Storage Class"
echo " Variant $VARIANT/$VARIANT_COUNT selected for this run"
echo " $VARIANT_SUMMARY"
echo "============================================================"
echo

# This lab uses the Killercoda playground's built-in StorageClass as the
# pre-existing default that the learner must demote.
if ! kubectl get storageclass "$EXISTING_SC" >/dev/null 2>&1; then
  echo "Error: StorageClass '$EXISTING_SC' not found." >&2
  echo "This lab expects the Killercoda CKA playground (or an equivalent k3s cluster)." >&2
  exit 1
fi

# Start from a clean slate: remove every preset's target class so retrying or
# switching variants cannot leave a solved or half-created StorageClass behind.
echo "Removing StorageClasses from earlier attempts or variants..."
for ((v = 1; v <= VARIANT_COUNT; v++)); do
  variant_config "$v"
  kubectl delete storageclass "$SC_NAME" --ignore-not-found >/dev/null
done
variant_config "$VARIANT"

# Refuse to start from an unexpected baseline: any other default class would
# change the "only default" task for this run.
OTHER_DEFAULTS="$(kubectl get storageclass -o jsonpath='{range .items[*]}{.metadata.name}{"="}{.metadata.annotations.storageclass\.kubernetes\.io/is-default-class}{"\n"}{end}' \
  | awk -F= -v keep="$EXISTING_SC" '$2 == "true" && $1 != keep {print $1}')"
if [[ -n "$OTHER_DEFAULTS" ]]; then
  echo "Error: unexpected default StorageClass(es): $OTHER_DEFAULTS" >&2
  echo "This lab expects '$EXISTING_SC' to be the only default StorageClass." >&2
  exit 1
fi

# Restore the baseline: local-path is the only default class before the task.
echo "Restoring '$EXISTING_SC' as the default StorageClass..."
kubectl patch storageclass "$EXISTING_SC" \
  -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}' >/dev/null

rm -f "$ANSWER_FILE"

echo
echo "[OK] Question 14 setup complete."
echo "   - Existing default StorageClass: $EXISTING_SC"
echo "   - StorageClass to create: $SC_NAME (provisioner $PROVISIONER)"
echo

variant_question "$VARIANT"
