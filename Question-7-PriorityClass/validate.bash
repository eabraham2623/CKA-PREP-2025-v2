#!/bin/bash
# Validation script for Question 7 - PriorityClass
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

echo "============================================"
echo " Validating Question 7: PriorityClass"
echo " Variant: $VARIANT/$VARIANT_COUNT"
echo " Expected: $TARGET_PC with value $EXPECTED_VALUE"
echo "           deployment $DEPLOYMENT in $NS uses it"
echo "============================================"

# 1. The PriorityClass selected for this variant exists.
check "PriorityClass '$TARGET_PC' exists" \
  kubectl get priorityclass "$TARGET_PC"

# 2. Its value is exactly one less than this variant's highest user-defined class.
check "PriorityClass '$TARGET_PC' value is $EXPECTED_VALUE" \
  test "$(kubectl get priorityclass "$TARGET_PC" -o jsonpath='{.value}')" = "$EXPECTED_VALUE"

# 3. It must not become the cluster default.
check "PriorityClass '$TARGET_PC' is not globalDefault" \
  test "$(kubectl get priorityclass "$TARGET_PC" -o jsonpath='{.globalDefault}')" != "true"

# 4. The existing Deployment is still present.
check "Deployment '$DEPLOYMENT' exists in namespace '$NS'" \
  kubectl get deployment "$DEPLOYMENT" -n "$NS"

# 5. The Deployment uses the new PriorityClass.
check "Deployment '$DEPLOYMENT' uses priorityClassName '$TARGET_PC'" \
  test "$(kubectl get deployment "$DEPLOYMENT" -n "$NS" -o jsonpath='{.spec.template.spec.priorityClassName}')" = "$TARGET_PC"

# 6. The Deployment's pod is running.
check "Deployment '$DEPLOYMENT' pods are Running" \
  bash -c "kubectl get pods -n '$NS' -l app='$APP_LABEL' --no-headers 2>/dev/null | grep -q Running"

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
if (( FAIL == 0 )); then
  echo "All checks passed!"
  exit 0
else
  echo "Some checks failed."
  exit 1
fi
