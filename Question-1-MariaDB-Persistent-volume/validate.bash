#!/bin/bash
# Validation script for Question 1 - MariaDB Persistent Volume
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

pvc_access_mode_is_rwo() {
  [[ "$(kubectl get pvc "$PVC" -n "$NS" -o jsonpath='{.spec.accessModes[0]}')" == "ReadWriteOnce" ]]
}

pvc_size_is_expected() {
  [[ "$(kubectl get pvc "$PVC" -n "$NS" -o jsonpath='{.spec.resources.requests.storage}')" == "$SIZE" ]]
}

pvc_is_bound() {
  [[ "$(kubectl get pvc "$PVC" -n "$NS" -o jsonpath='{.status.phase}')" == "Bound" ]]
}

pv_capacity_is_expected() {
  [[ "$(kubectl get pv "$PV" -o jsonpath='{.spec.capacity.storage}')" == "$SIZE" ]]
}

pv_claim_ref_is_expected() {
  [[ "$(kubectl get pv "$PV" -o jsonpath='{.spec.claimRef.namespace}/{.spec.claimRef.name}')" == "$NS/$PVC" ]]
}

pv_is_bound() {
  [[ "$(kubectl get pv "$PV" -o jsonpath='{.status.phase}')" == "Bound" ]]
}

deployment_uses_pvc() {
  kubectl get deployment "$DEPLOY" -n "$NS" \
    -o jsonpath='{range .spec.template.spec.volumes[*]}{.persistentVolumeClaim.claimName}{"\n"}{end}' \
    | grep -qx "$PVC"
}

deployment_is_available() {
  local available
  available="$(kubectl get deployment "$DEPLOY" -n "$NS" -o jsonpath='{.status.availableReplicas}' 2>/dev/null)"
  [[ -n "$available" && "$available" -ge 1 ]]
}

mariadb_pod_is_running() {
  kubectl get pods -n "$NS" -l "app=$DEPLOY" --no-headers 2>/dev/null | grep -q Running
}

echo "======================================"
echo " Validating Question 1: MariaDB PV"
echo " Variant: $VARIANT/$VARIANT_COUNT"
echo " Expected: namespace=$NS, PV=$PV, PVC=$PVC,"
echo "           deployment=$DEPLOY, storage=$SIZE"
echo "======================================"

# 1. PVC exists in the variant's namespace
check "PVC '$PVC' exists in namespace '$NS'" \
  kubectl get pvc "$PVC" -n "$NS"

# 2. PVC access mode is ReadWriteOnce
check "PVC access mode is ReadWriteOnce" \
  pvc_access_mode_is_rwo

# 3. PVC storage request matches the variant
check "PVC storage request is $SIZE" \
  pvc_size_is_expected

# 4. PVC is Bound
check "PVC is in Bound state" \
  pvc_is_bound

# 5. PV exists
check "PV '$PV' exists" \
  kubectl get pv "$PV"

# 6. PV capacity matches the variant
check "PV capacity is $SIZE" \
  pv_capacity_is_expected

# 7. PV is bound to the expected PVC
check "PV is bound to '$NS/$PVC'" \
  pv_claim_ref_is_expected

# 8. PV is Bound
check "PV '$PV' is Bound" \
  pv_is_bound

# 9. Deployment exists in the variant's namespace
check "Deployment '$DEPLOY' exists in namespace '$NS'" \
  kubectl get deployment "$DEPLOY" -n "$NS"

# 10. Deployment references the variant's PVC
check "Deployment uses PVC '$PVC'" \
  deployment_uses_pvc

# 11. Deployment is available (at least 1 ready replica)
check "Deployment has at least 1 available replica" \
  deployment_is_available

# 12. Pod is Running
check "MariaDB pod is Running" \
  mariadb_pod_is_running

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
if [[ $FAIL -eq 0 ]]; then
  echo "All checks passed!"
  exit 0
else
  echo "Some checks failed."
  exit 1
fi
