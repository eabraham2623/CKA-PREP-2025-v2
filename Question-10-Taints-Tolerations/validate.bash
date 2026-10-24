#!/bin/bash
# Validation script for Question 10 - Taints & Tolerations
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

node_has_expected_taint() {
  kubectl get node "$NODE" -o json 2>/dev/null | python3 -c '
import json, sys
data = json.load(sys.stdin)
key, effect, value = sys.argv[1:4]
for taint in data["spec"].get("taints", []):
    if (taint.get("key") == key
            and taint.get("effect") == effect
            and taint.get("value", "") == value):
        sys.exit(0)
sys.exit(1)
' "$TAINT_KEY" "$TAINT_EFFECT" "$TAINT_VALUE"
}

pod_is_running() {
  [[ "$(kubectl get pod "$POD_NAME" -n "$POD_NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null)" == "Running" ]]
}

pod_is_on_node() {
  [[ "$(kubectl get pod "$POD_NAME" -n "$POD_NAMESPACE" -o jsonpath='{.spec.nodeName}' 2>/dev/null)" == "$NODE" ]]
}

pod_has_expected_toleration() {
  kubectl get pod "$POD_NAME" -n "$POD_NAMESPACE" -o json 2>/dev/null | python3 -c '
import json, sys
data = json.load(sys.stdin)
key, effect, value, operator = sys.argv[1:5]
for toleration in data["spec"].get("tolerations", []):
    if toleration.get("key") != key or toleration.get("effect", "") != effect:
        continue
    tol_operator = toleration.get("operator", "Equal")
    if operator == "Exists":
        if tol_operator == "Exists" and toleration.get("value", "") == "":
            sys.exit(0)
    elif tol_operator == "Equal" and toleration.get("value", "") == value:
        sys.exit(0)
sys.exit(1)
' "$TAINT_KEY" "$TAINT_EFFECT" "$TAINT_VALUE" "$TOLERATION_OPERATOR"
}

echo "============================================================"
echo " Validating Question 10: Taints & Tolerations"
echo " Variant: $VARIANT/$VARIANT_COUNT"
echo " Expected: $NODE has taint $TAINT_SPEC"
echo "           pod $POD_NAME in namespace $POD_NAMESPACE is Running on $NODE"
echo "           toleration uses operator $TOLERATION_OPERATOR"
echo "============================================================"

# 1. The node has exactly the taint selected for this variant.
check "node $NODE has taint $TAINT_SPEC" node_has_expected_taint

# 2. The tolerating pod is Running.
check "pod $POD_NAME in namespace $POD_NAMESPACE is Running" pod_is_running

# 3. The tolerating pod is scheduled on node01.
check "pod $POD_NAME is scheduled on $NODE" pod_is_on_node

# 4. The pod's toleration matches the selected taint.
check "pod $POD_NAME has a toleration for $TAINT_SPEC using operator $TOLERATION_OPERATOR" \
  pod_has_expected_toleration

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
if (( FAIL == 0 )); then
  echo "All checks passed!"
  exit 0
fi
echo "Some checks failed."
exit 1
