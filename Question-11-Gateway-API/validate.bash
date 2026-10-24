#!/bin/bash
# Validation script for Question 11 - Gateway API
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

gateway_exists() {
  kubectl get gateway "$GATEWAY" -n "$NS" >/dev/null 2>&1
}

gateway_class_matches() {
  [[ "$(kubectl get gateway "$GATEWAY" -n "$NS" -o jsonpath='{.spec.gatewayClassName}' 2>/dev/null)" == "$GATEWAY_CLASS" ]]
}

listener_protocol_port_match() {
  local protocol port
  protocol="$(kubectl get gateway "$GATEWAY" -n "$NS" -o jsonpath='{.spec.listeners[0].protocol}' 2>/dev/null)"
  port="$(kubectl get gateway "$GATEWAY" -n "$NS" -o jsonpath='{.spec.listeners[0].port}' 2>/dev/null)"
  [[ "$protocol" == "$PROTOCOL" && "$port" == "$LISTENER_PORT" ]]
}

listener_hostname_matches() {
  [[ "$(kubectl get gateway "$GATEWAY" -n "$NS" -o jsonpath='{.spec.listeners[0].hostname}' 2>/dev/null)" == "$HOST" ]]
}

listener_tls_mode_matches() {
  [[ "$(kubectl get gateway "$GATEWAY" -n "$NS" -o jsonpath='{.spec.listeners[0].tls.mode}' 2>/dev/null)" == "$TLS_MODE" ]]
}

listener_secret_matches() {
  [[ "$(kubectl get gateway "$GATEWAY" -n "$NS" -o jsonpath='{.spec.listeners[0].tls.certificateRefs[0].name}' 2>/dev/null)" == "$TLS_SECRET" ]]
}

httproute_exists() {
  kubectl get httproute "$HTTPROUTE" -n "$NS" >/dev/null 2>&1
}

httproute_parent_matches() {
  [[ "$(kubectl get httproute "$HTTPROUTE" -n "$NS" -o jsonpath='{.spec.parentRefs[0].name}' 2>/dev/null)" == "$GATEWAY" ]]
}

httproute_hostname_matches() {
  [[ "$(kubectl get httproute "$HTTPROUTE" -n "$NS" -o jsonpath='{.spec.hostnames[0]}' 2>/dev/null)" == "$HOST" ]]
}

httproute_path_matches() {
  local type value
  type="$(kubectl get httproute "$HTTPROUTE" -n "$NS" -o jsonpath='{.spec.rules[0].matches[0].path.type}' 2>/dev/null)"
  value="$(kubectl get httproute "$HTTPROUTE" -n "$NS" -o jsonpath='{.spec.rules[0].matches[0].path.value}' 2>/dev/null)"
  [[ "$type" == "$PATH_TYPE" && "$value" == "$PATH_VALUE" ]]
}

httproute_backend_name_matches() {
  [[ "$(kubectl get httproute "$HTTPROUTE" -n "$NS" -o jsonpath='{.spec.rules[0].backendRefs[0].name}' 2>/dev/null)" == "$SERVICE" ]]
}

httproute_backend_port_matches() {
  [[ "$(kubectl get httproute "$HTTPROUTE" -n "$NS" -o jsonpath='{.spec.rules[0].backendRefs[0].port}' 2>/dev/null)" == "$SERVICE_PORT" ]]
}

echo "============================================================"
echo " Validating Question 11: Gateway API"
echo " Variant: $VARIANT/$VARIANT_COUNT"
echo " Expected: Gateway $GATEWAY -> class $GATEWAY_CLASS, HTTPS/$LISTENER_PORT,"
echo "           host $HOST, TLS $TLS_MODE secret $TLS_SECRET"
echo "           HTTPRoute $HTTPROUTE -> parent $GATEWAY, backend $SERVICE:$SERVICE_PORT"
echo "============================================================"

# 1. Gateway exists with the expected class.
check "Gateway '$GATEWAY' exists" gateway_exists
check "Gateway uses gatewayClassName '$GATEWAY_CLASS'" gateway_class_matches

# 2. Gateway listener mirrors the Ingress HTTPS/TLS configuration.
check "Gateway listener uses $PROTOCOL on port $LISTENER_PORT" listener_protocol_port_match
check "Gateway listener hostname is '$HOST'" listener_hostname_matches
check "Gateway listener uses TLS mode '$TLS_MODE'" listener_tls_mode_matches
check "Gateway listener references TLS secret '$TLS_SECRET'" listener_secret_matches

# 3. HTTPRoute exists and is attached to the expected Gateway.
check "HTTPRoute '$HTTPROUTE' exists" httproute_exists
check "HTTPRoute references parentRef '$GATEWAY'" httproute_parent_matches

# 4. HTTPRoute hostname, path, and backend mirror the Ingress rules.
check "HTTPRoute hostname is '$HOST'" httproute_hostname_matches
check "HTTPRoute uses $PATH_TYPE path '$PATH_VALUE'" httproute_path_matches
check "HTTPRoute backend references service '$SERVICE'" httproute_backend_name_matches
check "HTTPRoute backend port is $SERVICE_PORT" httproute_backend_port_matches

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
if (( FAIL == 0 )); then
  echo "All checks passed!"
  exit 0
fi
echo "Some checks failed."
exit 1
