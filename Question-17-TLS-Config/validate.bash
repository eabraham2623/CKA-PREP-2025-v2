#!/bin/bash
# Validation script for Question 17 - NGINX TLS Config
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

namespace_active() {
  [[ "$(kubectl get namespace "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" == "Active" ]]
}

namespace_variant_matches() {
  local recorded
  recorded="$(kubectl get namespace "$NS" -o jsonpath='{.metadata.annotations.cka\.question/variant}' 2>/dev/null)"
  [[ "$recorded" == "$VARIANT" ]]
}

configmap_exists() {
  kubectl get configmap "$CONFIGMAP" -n "$NS" >/dev/null 2>&1
}

nginx_conf() {
  kubectl get configmap "$CONFIGMAP" -n "$NS" -o jsonpath='{.data.nginx\.conf}' 2>/dev/null
}

configmap_has_nginx_conf() {
  [[ -n "$(nginx_conf)" ]]
}

# Check every ssl_protocols directive in the effective nginx.conf. Comments are
# ignored and protocol order does not matter, but the token set must match the
# variant exactly.
config_protocols_match() {
  local expected="$1"
  local expected_norm line tokens found=0

  expected_norm="$(printf '%s\n' $expected | sort -u | tr '\n' ' ')"

  while IFS= read -r line; do
    found=1
    tokens="$(printf '%s\n' "$line" | tr -s '[:space:]' '\n' | sed '/^$/d' | sort -u | tr '\n' ' ')"
    [[ "$tokens" == "$expected_norm" ]] || return 1
  done < <(nginx_conf | awk '
    { sub(/#.*/, "") }
    /^[[:space:]]*ssl_protocols[[:space:]]/ {
      sub(/^[[:space:]]*ssl_protocols[[:space:]]+/, "")
      sub(/;.*/, "")
      print
    }')

  (( found == 1 ))
}

configmap_immutable_is() {
  local expected="$1"
  local actual
  actual="$(kubectl get configmap "$CONFIGMAP" -n "$NS" -o jsonpath='{.immutable}' 2>/dev/null)"
  [[ "${actual:-false}" == "$expected" ]]
}

deployment_ready() {
  local desired ready
  desired="$(kubectl get deployment "$DEPLOYMENT" -n "$NS" -o jsonpath='{.spec.replicas}' 2>/dev/null)"
  ready="$(kubectl get deployment "$DEPLOYMENT" -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)"
  [[ "${desired:-0}" =~ ^[0-9]+$ ]] || return 1
  [[ "${ready:-0}" =~ ^[0-9]+$ ]] || return 1
  (( desired >= 1 && ready >= desired ))
}

service_port_ok() {
  local port target
  port="$(kubectl get service "$SERVICE" -n "$NS" -o jsonpath='{.spec.ports[0].port}' 2>/dev/null)"
  target="$(kubectl get service "$SERVICE" -n "$NS" -o jsonpath='{.spec.ports[0].targetPort}' 2>/dev/null)"
  [[ "$port" == "443" && "$target" == "443" ]]
}

service_ip() {
  kubectl get service "$SERVICE" -n "$NS" -o jsonpath='{.spec.clusterIP}' 2>/dev/null
}

hosts_maps_service_ip() {
  local ip
  ip="$(service_ip)"
  [[ -n "$ip" && "$ip" != "None" ]] || return 1
  awk -v ip="$ip" -v host="$TLS_HOSTNAME" '
    $1 == ip {
      for (i = 2; i <= NF; i++) {
        if ($i == host) { found = 1 }
      }
    }
    END { exit(found ? 0 : 1) }
  ' /etc/hosts
}

tls12_handshake() {
  local ip
  ip="$(service_ip)"
  [[ -n "$ip" && "$ip" != "None" ]] || return 1
  curl -sk --max-time 5 --tlsv1.2 --tls-max 1.2 "https://$ip" >/dev/null 2>&1
}

tls12_rejected() {
  ! tls12_handshake
}

tls13_handshake() {
  local ip
  ip="$(service_ip)"
  [[ -n "$ip" && "$ip" != "None" ]] || return 1
  curl -sfk --max-time 5 --tlsv1.3 "https://$ip" >/dev/null 2>&1
}

echo "============================================"
echo " Validating Question 17: NGINX TLS Config"
echo " Variant: $VARIANT/$VARIANT_COUNT"
echo " Required protocols: $REQUIRED_PROTOCOLS"
echo " ConfigMap immutable: $REQUIRED_IMMUTABLE"
echo " TLS 1.2 expected: $TLS12_EXPECTED"
echo "============================================"

check "Namespace '$NS' is Active" \
  namespace_active

check "Namespace records variant $VARIANT" \
  namespace_variant_matches

check "ConfigMap '$CONFIGMAP' exists" \
  configmap_exists

check "ConfigMap contains non-empty nginx.conf data" \
  configmap_has_nginx_conf

check "ConfigMap ssl_protocols is exactly '$REQUIRED_PROTOCOLS'" \
  config_protocols_match "$REQUIRED_PROTOCOLS"

check "ConfigMap immutable is $REQUIRED_IMMUTABLE" \
  configmap_immutable_is "$REQUIRED_IMMUTABLE"

check "Deployment '$DEPLOYMENT' is ready" \
  deployment_ready

check "Service '$SERVICE' exposes port 443" \
  service_port_ok

check "/etc/hosts maps '$TLS_HOSTNAME' to the service ClusterIP" \
  hosts_maps_service_ip

if [[ "$TLS12_EXPECTED" == "work" ]]; then
  check "TLS 1.2 connection succeeds" \
    tls12_handshake
else
  check "TLS 1.2 connection is rejected" \
    tls12_rejected
fi

check "TLS 1.3 connection succeeds" \
  tls13_handshake

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
if (( FAIL > 0 )) && [[ "$REQUIRED_IMMUTABLE" == "true" ]]; then
  echo "Hint: if the ConfigMap is correct but TLS 1.2 still works, the running pod may still be using the old immutable ConfigMap from the kubelet cache."
  echo "      Remove all old pods before starting the new one: scale the deployment to 0, wait for the pod to terminate, then scale it back to 1."
fi
if (( FAIL == 0 )); then
  echo "All checks passed!"
  exit 0
else
  echo "Some checks failed."
  exit 1
fi
