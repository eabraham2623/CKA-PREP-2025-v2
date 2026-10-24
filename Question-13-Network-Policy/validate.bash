#!/bin/bash
# Validation script for Question 13 - Network Policy
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

policy_count_is_one() {
  local count
  count="$(kubectl get networkpolicy -n "$NS_BACKEND" --no-headers 2>/dev/null | wc -l)"
  [[ "$count" -eq 1 ]]
}

correct_policy_applied() {
  kubectl get networkpolicy "$CORRECT_POLICY" -n "$NS_BACKEND" >/dev/null 2>&1
}

policy_selects_backend() {
  local label policy_type
  label="$(kubectl get networkpolicy "$CORRECT_POLICY" -n "$NS_BACKEND" -o jsonpath="{.spec.podSelector.matchLabels.$BACKEND_LABEL_KEY}" 2>/dev/null)"
  policy_type="$(kubectl get networkpolicy "$CORRECT_POLICY" -n "$NS_BACKEND" -o jsonpath='{.spec.policyTypes[0]}' 2>/dev/null)"
  [[ "$label" == "$BACKEND_LABEL_VALUE" && "$policy_type" == "Ingress" ]]
}

policy_from_matches() {
  kubectl get networkpolicy "$CORRECT_POLICY" -n "$NS_BACKEND" -o json 2>/dev/null | \
    python3 -c '
import json, sys

ns_frontend, label_key, label_value = sys.argv[1:4]
policy = json.load(sys.stdin)
ingress = policy.get("spec", {}).get("ingress", [])
if len(ingress) != 1:
    sys.exit(1)

sources = ingress[0].get("from", [])
if len(sources) != 2:
    sys.exit(1)

seen_namespace = False
seen_pod = False
for source in sources:
    if "ipBlock" in source:
        sys.exit(1)
    if "namespaceSelector" in source:
        if set(source) != {"namespaceSelector"}:
            sys.exit(1)
        labels = source["namespaceSelector"].get("matchLabels", {})
        if labels != {"kubernetes.io/metadata.name": ns_frontend}:
            sys.exit(1)
        seen_namespace = True
    elif "podSelector" in source:
        if set(source) != {"podSelector"}:
            sys.exit(1)
        labels = source["podSelector"].get("matchLabels", {})
        if labels != {label_key: label_value}:
            sys.exit(1)
        seen_pod = True
    else:
        sys.exit(1)

if not (seen_namespace and seen_pod):
    sys.exit(1)
' "$NS_FRONTEND" "$FRONTEND_LABEL_KEY" "$FRONTEND_LABEL_VALUE"
}

policy_port_matches() {
  kubectl get networkpolicy "$CORRECT_POLICY" -n "$NS_BACKEND" -o json 2>/dev/null | \
    python3 -c '
import json, sys

port = int(sys.argv[1])
policy = json.load(sys.stdin)
ingress = policy.get("spec", {}).get("ingress", [])
if len(ingress) != 1:
    sys.exit(1)

ports = ingress[0].get("ports", [])
if len(ports) != 1:
    sys.exit(1)

entry = ports[0]
if entry.get("protocol") != "TCP" or entry.get("port") != port:
    sys.exit(1)
' "$POLICY_PORT"
}

frontend_deployment_matches() {
  local label
  label="$(kubectl get deployment "$FRONTEND_DEPLOYMENT" -n "$NS_FRONTEND" -o jsonpath="{.spec.template.metadata.labels.$FRONTEND_LABEL_KEY}" 2>/dev/null)"
  [[ "$label" == "$FRONTEND_LABEL_VALUE" ]]
}

backend_deployment_matches() {
  local label
  label="$(kubectl get deployment "$BACKEND_DEPLOYMENT" -n "$NS_BACKEND" -o jsonpath="{.spec.template.metadata.labels.$BACKEND_LABEL_KEY}" 2>/dev/null)"
  [[ "$label" == "$BACKEND_LABEL_VALUE" ]]
}

backend_service_exists() {
  kubectl get service "$BACKEND_SERVICE" -n "$NS_BACKEND" >/dev/null 2>&1
}

backend_service_matches() {
  local selector port target
  selector="$(kubectl get service "$BACKEND_SERVICE" -n "$NS_BACKEND" -o jsonpath="{.spec.selector.$BACKEND_LABEL_KEY}" 2>/dev/null)"
  port="$(kubectl get service "$BACKEND_SERVICE" -n "$NS_BACKEND" -o jsonpath='{.spec.ports[0].port}' 2>/dev/null)"
  target="$(kubectl get service "$BACKEND_SERVICE" -n "$NS_BACKEND" -o jsonpath='{.spec.ports[0].targetPort}' 2>/dev/null)"
  [[ "$selector" == "$BACKEND_LABEL_VALUE" && "$port" == "$BACKEND_PORT" && "$target" == "$BACKEND_PORT" ]]
}

echo "============================================================"
echo " Validating Question 13: Network Policy"
echo " Variant: $VARIANT/$VARIANT_COUNT"
echo " Expected: exactly one policy in $NS_BACKEND, named $CORRECT_POLICY"
echo "           from $NS_FRONTEND namespace + $FRONTEND_LABEL_KEY=$FRONTEND_LABEL_VALUE pods,"
echo "           no ipBlock, TCP/$POLICY_PORT only"
echo "           frontend Deployment $FRONTEND_DEPLOYMENT, backend $BACKEND_DEPLOYMENT"
echo "           backend Service $BACKEND_SERVICE:$BACKEND_PORT"
echo "============================================================"

check "Exactly one NetworkPolicy exists in namespace '$NS_BACKEND'" policy_count_is_one
check "Applied NetworkPolicy is '$CORRECT_POLICY'" correct_policy_applied
check "NetworkPolicy selects the backend pods ($BACKEND_LABEL_KEY=$BACKEND_LABEL_VALUE) for Ingress" policy_selects_backend
check "Ingress allows the frontend namespace and frontend pods, with no ipBlock" policy_from_matches
check "Ingress allows only TCP port $POLICY_PORT" policy_port_matches
check "Frontend Deployment '$FRONTEND_DEPLOYMENT' exists with label $FRONTEND_LABEL_KEY=$FRONTEND_LABEL_VALUE" frontend_deployment_matches
check "Backend Deployment '$BACKEND_DEPLOYMENT' exists with label $BACKEND_LABEL_KEY=$BACKEND_LABEL_VALUE" backend_deployment_matches
check "Backend Service '$BACKEND_SERVICE' exists" backend_service_exists
check "Backend Service selects the backend pods and targets port $BACKEND_PORT" backend_service_matches

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
if (( FAIL == 0 )); then
  echo "All checks passed!"
else
  echo "Some checks failed."
fi

echo ""
echo "============================================================"
echo " Manual Validation Command"
echo "============================================================"
echo "To manually verify connectivity from frontend to backend, run:"
echo "  kubectl exec -n $NS_FRONTEND deployment/$FRONTEND_DEPLOYMENT -- curl -v --connect-timeout 5 $BACKEND_SERVICE.$NS_BACKEND.svc.cluster.local:$BACKEND_PORT"

if (( FAIL == 0 )); then
  exit 0
fi
exit 1
