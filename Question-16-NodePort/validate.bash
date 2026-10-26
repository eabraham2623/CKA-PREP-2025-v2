#!/bin/bash
# Validation script for Question 16 - NodePort Service
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

container_port_is_expected() {
  [[ "$(kubectl get deployment "$DEPLOY" -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].ports[0].containerPort}' 2>/dev/null)" == "$CONTAINER_PORT" ]]
}

container_port_name_is_expected() {
  [[ "$(kubectl get deployment "$DEPLOY" -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].ports[0].name}' 2>/dev/null)" == "$PORT_NAME" ]]
}

container_port_protocol_is_expected() {
  [[ "$(kubectl get deployment "$DEPLOY" -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].ports[0].protocol}' 2>/dev/null)" == "$PROTOCOL" ]]
}

service_type_is_nodeport() {
  [[ "$(kubectl get service "$SVC" -n "$NS" -o jsonpath='{.spec.type}' 2>/dev/null)" == "NodePort" ]]
}

service_port_is_expected() {
  [[ "$(kubectl get service "$SVC" -n "$NS" -o jsonpath='{.spec.ports[0].port}' 2>/dev/null)" == "$SERVICE_PORT" ]]
}

service_target_port_is_expected() {
  [[ "$(kubectl get service "$SVC" -n "$NS" -o jsonpath='{.spec.ports[0].targetPort}' 2>/dev/null)" == "$TARGET_PORT" ]]
}

service_node_port_is_expected() {
  [[ "$(kubectl get service "$SVC" -n "$NS" -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)" == "$NODEPORT" ]]
}

service_protocol_is_expected() {
  [[ "$(kubectl get service "$SVC" -n "$NS" -o jsonpath='{.spec.ports[0].protocol}' 2>/dev/null)" == "$PROTOCOL" ]]
}

service_has_endpoints() {
  local addresses
  addresses="$(kubectl get endpoints "$SVC" -n "$NS" -o jsonpath='{.subsets[0].addresses[*].ip}' 2>/dev/null)"
  [[ -n "$addresses" ]]
}

echo "======================================"
echo " Validating Question 16: NodePort"
echo " Variant: $VARIANT/$VARIANT_COUNT"
echo " Expected: namespace=$NS, deployment=$DEPLOY, service=$SVC"
echo "           containerPort=$CONTAINER_PORT ($PORT_NAME/$PROTOCOL)"
echo "           servicePort=$SERVICE_PORT -> targetPort=$TARGET_PORT, nodePort=$NODEPORT"
echo "======================================"

# 1. Deployment exists in the variant's namespace.
check "Deployment '$DEPLOY' exists in namespace '$NS'" \
  kubectl get deployment "$DEPLOY" -n "$NS"

# 2. The deployment declares the expected containerPort.
check "Deployment has containerPort $CONTAINER_PORT configured" \
  container_port_is_expected

# 3. The container port has the expected name.
check "Container port name is '$PORT_NAME'" \
  container_port_name_is_expected

# 4. The container port protocol is TCP.
check "Container port protocol is $PROTOCOL" \
  container_port_protocol_is_expected

# 5. Service exists in the variant's namespace.
check "Service '$SVC' exists in namespace '$NS'" \
  kubectl get service "$SVC" -n "$NS"

# 6. Service type is NodePort.
check "Service type is NodePort" \
  service_type_is_nodeport

# 7. Service port matches the variant.
check "Service port is $SERVICE_PORT" \
  service_port_is_expected

# 8. Service targetPort matches the variant.
check "Service targetPort is $TARGET_PORT" \
  service_target_port_is_expected

# 9. Service nodePort matches the variant.
check "Service nodePort is $NODEPORT" \
  service_node_port_is_expected

# 10. Service protocol is TCP.
check "Service port protocol is $PROTOCOL" \
  service_protocol_is_expected

# 11. Service has active endpoints.
check "Service has active endpoints" \
  service_has_endpoints

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
if (( FAIL == 0 )); then
  echo "All checks passed!"
  exit 0
else
  echo "Some checks failed."
  exit 1
fi
