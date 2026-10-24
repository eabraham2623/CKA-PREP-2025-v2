#!/bin/bash
# Validation script for Question 14 - Storage Class
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../scripts/lib/variant.sh
source "$REPO_ROOT/scripts/lib/variant.sh"
# shellcheck source=variants.bash
source "$SCRIPT_DIR/variants.bash"

VARIANT="$(cka_variant_read "$SCRIPT_DIR" "$VARIANT_COUNT")" || exit 1
variant_config "$VARIANT" || exit 1

PASS=0
FAIL=0
TOTAL=0

check() {
  local description="$1"
  shift
  TOTAL=$((TOTAL + 1))
  if "$@" >/dev/null 2>&1; then
    echo "  PASS: $description"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $description"
    FAIL=$((FAIL + 1))
  fi
}

sc_field() {
  kubectl get storageclass "$1" -o jsonpath="$2" 2>/dev/null
}

is_not_default() {
  local value
  value="$(sc_field "$1" '{.metadata.annotations.storageclass\.kubernetes\.io/is-default-class}')"
  [[ -n "$value" && "$value" != "true" ]]
}

count_defaults() {
  kubectl get storageclass -o json 2>/dev/null | python3 -c '
import json, sys
data = json.load(sys.stdin)
count = 0
for sc in data["items"]:
    annotations = sc["metadata"].get("annotations", {})
    if annotations.get("storageclass.kubernetes.io/is-default-class") == "true":
        count += 1
print(count)
'
}

echo "============================================"
echo " Validating Question 14: Storage Class"
echo " Variant: $VARIANT/$VARIANT_COUNT"
echo " Expected: StorageClass $SC_NAME"
echo "           provisioner $PROVISIONER"
echo "           volumeBindingMode $VOLUME_BINDING_MODE"
echo "           $SC_NAME is the only default class"
echo "============================================"

# 1. The StorageClass selected for this variant exists.
check "StorageClass '$SC_NAME' exists" \
  kubectl get storageclass "$SC_NAME"

# 2. Its provisioner matches the variant exactly.
check "StorageClass '$SC_NAME' provisioner is '$PROVISIONER'" \
  test "$(sc_field "$SC_NAME" '{.provisioner}')" = "$PROVISIONER"

# 3. Its volume binding mode matches the task.
check "VolumeBindingMode is '$VOLUME_BINDING_MODE'" \
  test "$(sc_field "$SC_NAME" '{.volumeBindingMode}')" = "$VOLUME_BINDING_MODE"

# 4. The new class is the default.
check "StorageClass '$SC_NAME' is the default" \
  test "$(sc_field "$SC_NAME" '{.metadata.annotations.storageclass\.kubernetes\.io/is-default-class}')" = "true"

# 5. The pre-existing class must still be present.
check "Existing StorageClass '$EXISTING_SC' still exists" \
  kubectl get storageclass "$EXISTING_SC"

# 6. The pre-existing class must no longer be the default.
check "Existing StorageClass '$EXISTING_SC' is not default" \
  is_not_default "$EXISTING_SC"

# 7. Exactly one StorageClass in the cluster is marked default.
check "Only one default StorageClass exists" \
  test "$(count_defaults)" = "1"

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
if (( FAIL == 0 )); then
  echo "All checks passed!"
  exit 0
else
  echo "Some checks failed."
  exit 1
fi
