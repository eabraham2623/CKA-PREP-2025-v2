#!/bin/bash
# Validation script for Question 15 - Etcd Fix variants.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../scripts/lib/variant.sh
source "$REPO_ROOT/scripts/lib/variant.sh"
# shellcheck source=q15-lib.bash
source "$SCRIPT_DIR/q15-lib.bash"
# shellcheck source=variants.bash
source "$SCRIPT_DIR/variants.bash"

VARIANT="$(cka_variant_read "$SCRIPT_DIR" "$VARIANT_COUNT")" || exit 1
variant_config "$VARIANT" || exit 1

BASELINE_VARIANT="$(q15_baseline_variant)" || {
  echo "Error: no completed Q15 setup baseline was found for this run." >&2
  echo "Re-run setup before validating: scripts/run-question.sh 15 ${VARIANT}" >&2
  exit 1
}
if [[ "$BASELINE_VARIANT" != "$VARIANT" ]]; then
  echo "Error: recorded variant $VARIANT does not match the setup marker $BASELINE_VARIANT." >&2
  echo "The variant state was changed after setup; re-run setup before validating." >&2
  exit 1
fi

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

api_server_ready() {
  q15_api_ready
}

etcd_endpoint_correct() {
  local value
  value="$(sudo grep -oP '(?<=--etcd-servers=)\S+' "$Q15_APISERVER_MANIFEST" 2>/dev/null | head -n1)"
  [[ "$value" == "$ETCD_LOCAL_ENDPOINT" ]]
}

etcd_endpoint_not_peer() {
  ! grep -Fq -- '2380' "$Q15_APISERVER_MANIFEST" 2>/dev/null
}

control_plane_pods_running() {
  q15_control_plane_running
}

etcd_pod_running() {
  q15_container_running etcd
}

scheduler_running() {
  q15_container_running kube-scheduler
}

scheduler_resources_sane() {
  local cpu millicores
  cpu="$(q15_pod_cpu_request "$Q15_SCHEDULER_MANIFEST")" || return 1
  millicores="$(q15_cpu_millicores "$cpu")" || return 1
  (( millicores <= 200 ))
}

controller_running() {
  q15_container_running kube-controller-manager
}

controller_cpu_sane() {
  local cpu millicores
  cpu="$(q15_pod_cpu_request "$Q15_CONTROLLER_MANIFEST")" || return 1
  millicores="$(q15_cpu_millicores "$cpu")" || return 1
  (( millicores <= 500 ))
}

controller_memory_sane() {
  local memory mib
  memory="$(q15_pod_memory_limit "$Q15_CONTROLLER_MANIFEST")" || true
  if [[ -n "$memory" ]]; then
    mib="$(q15_memory_mib "$memory")" || return 1
    (( mib >= 128 )) || return 1
  fi
  return 0
}

coredns_running() {
  q15_coredns_ready
}

coredns_corefile_valid() {
  local tmp
  tmp="$(mktemp)"
  if ! kubectl -n kube-system get configmap coredns \
      -o jsonpath='{.data.Corefile}' > "$tmp" 2>/dev/null; then
    rm -f "$tmp"
    return 1
  fi
  q15_corefile_is_valid "$tmp"
  local rc=$?
  rm -f "$tmp"
  return "$rc"
}

nodes_ready() {
  q15_nodes_ready
}

dns_resolves() {
  q15_dns_resolves
}

echo "============================================================"
echo " Validating Question 15: Etcd Fix"
echo " Variant: $VARIANT/$VARIANT_COUNT"
echo " Expected: $VARIANT_SUMMARY"
echo "============================================================"

check "kube-apiserver is reachable (ReadyZ)" api_server_ready
check "kube-apiserver --etcd-servers is $ETCD_LOCAL_ENDPOINT" etcd_endpoint_correct
check "kube-apiserver --etcd-servers does not use peer port 2380" etcd_endpoint_not_peer
check "etcd Pod is Running" etcd_pod_running
check "all control-plane Pods are Running" control_plane_pods_running

check "kube-scheduler Pod is Running" scheduler_running
check "kube-scheduler CPU request is at most 200m" scheduler_resources_sane

check "kube-controller-manager Pod is Running" controller_running
check "kube-controller-manager CPU request is at most 500m" controller_cpu_sane
check "kube-controller-manager memory limit is absent or at least 128Mi" controller_memory_sane

check "CoreDNS Deployment is fully available" coredns_running
check "CoreDNS Corefile is valid" coredns_corefile_valid
check "cluster DNS resolves kubernetes.default.svc.cluster.local" dns_resolves
check "all nodes are Ready" nodes_ready

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
if (( FAIL == 0 )); then
  echo "All checks passed!"
  exit 0
fi
echo "Some checks failed."
exit 1
