#!/bin/bash
# Validation script for Question 12 - Ingress
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

service_exists() {
  kubectl get service "$SERVICE" -n "$NS" >/dev/null 2>&1
}

service_type_matches() {
  [[ "$(kubectl get service "$SERVICE" -n "$NS" -o jsonpath='{.spec.type}' 2>/dev/null)" == "$SERVICE_TYPE" ]]
}

service_port_matches() {
  [[ "$(kubectl get service "$SERVICE" -n "$NS" -o jsonpath='{.spec.ports[0].port}' 2>/dev/null)" == "$SERVICE_PORT" ]]
}

service_target_port_matches() {
  [[ "$(kubectl get service "$SERVICE" -n "$NS" -o jsonpath='{.spec.ports[0].targetPort}' 2>/dev/null)" == "$TARGET_PORT" ]]
}

ingress_exists() {
  kubectl get ingress "$INGRESS" -n "$NS" >/dev/null 2>&1
}

ingress_host_matches() {
  [[ "$(kubectl get ingress "$INGRESS" -n "$NS" -o jsonpath='{.spec.rules[0].host}' 2>/dev/null)" == "$HOST" ]]
}

ingress_path_matches() {
  local path path_type
  path="$(kubectl get ingress "$INGRESS" -n "$NS" -o jsonpath='{.spec.rules[0].http.paths[0].path}' 2>/dev/null)"
  path_type="$(kubectl get ingress "$INGRESS" -n "$NS" -o jsonpath='{.spec.rules[0].http.paths[0].pathType}' 2>/dev/null)"
  [[ "$path" == "$PATH_VALUE" && "$path_type" == "$PATH_TYPE" ]]
}

ingress_backend_matches() {
  local name port
  name="$(kubectl get ingress "$INGRESS" -n "$NS" -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.name}' 2>/dev/null)"
  port="$(kubectl get ingress "$INGRESS" -n "$NS" -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.port.number}' 2>/dev/null)"
  [[ "$name" == "$SERVICE" && "$port" == "$SERVICE_PORT" ]]
}

service_has_endpoints() {
  local endpoints
  endpoints="$(kubectl get endpoints "$SERVICE" -n "$NS" -o jsonpath='{.subsets[0].addresses}' 2>/dev/null)"
  [[ -n "$endpoints" && "$endpoints" != "[]" ]]
}

echo "============================================================"
echo " Validating Question 12: Ingress"
echo " Variant: $VARIANT/$VARIANT_COUNT"
echo " Expected: Service $SERVICE ($SERVICE_TYPE, port $SERVICE_PORT -> $TARGET_PORT)"
echo "           Ingress $INGRESS for http://$HOST$PATH_VALUE"
echo "           backend $SERVICE:$SERVICE_PORT"
echo "============================================================"

check "Service '$SERVICE' exists in namespace '$NS'" service_exists
check "Service type is '$SERVICE_TYPE'" service_type_matches
check "Service port is $SERVICE_PORT" service_port_matches
check "Service targets container port $TARGET_PORT" service_target_port_matches
check "Ingress '$INGRESS' exists in namespace '$NS'" ingress_exists
check "Ingress host is '$HOST'" ingress_host_matches
check "Ingress path is '$PATH_VALUE' with pathType '$PATH_TYPE'" ingress_path_matches
check "Ingress backend references '$SERVICE' port $SERVICE_PORT" ingress_backend_matches
check "Service '$SERVICE' has endpoints (pods backing the service)" service_has_endpoints

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
if (( FAIL == 0 )); then
  echo "All checks passed!"
  exit 0
fi
echo "Some checks failed."
exit 1
