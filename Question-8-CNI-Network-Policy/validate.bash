#!/bin/bash
# Validation script for Question 8 - CNI & Network Policy
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../scripts/lib/variant.sh
source "$REPO_ROOT/scripts/lib/variant.sh"
# shellcheck source=../scripts/lib/q8-cni.sh
source "$REPO_ROOT/scripts/lib/q8-cni.sh"
# shellcheck source=variants.bash
source "$SCRIPT_DIR/variants.bash"

VARIANT="$(cka_variant_read "$SCRIPT_DIR" "$VARIANT_COUNT")" || exit 1
POD_SUBNET="$(cka_q8_pod_subnet)" || exit 1
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

ds_ready() {
  local namespace="$1" name="$2" desired ready
  desired="$(kubectl get daemonset "$name" -n "$namespace" -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null)"
  ready="$(kubectl get daemonset "$name" -n "$namespace" -o jsonpath='{.status.numberReady}' 2>/dev/null)"
  [[ "$desired" =~ ^[0-9]+$ && "$desired" -gt 0 && "$ready" == "$desired" ]]
}

deployment_available() {
  local namespace="$1" name="$2" available
  available="$(kubectl get deployment "$name" -n "$namespace" -o jsonpath='{.status.availableReplicas}' 2>/dev/null)"
  [[ "$available" =~ ^[0-9]+$ && "$available" -ge 1 ]]
}

ds_image_contains() {
  local namespace="$1" name="$2" needle="$3"
  kubectl get daemonset "$name" -n "$namespace" -o jsonpath='{.spec.template.spec.containers[*].image}' 2>/dev/null \
    | grep -q -- "$needle"
}

calico_pool_matches() {
  kubectl get ippools.crd.projectcalico.org -o jsonpath='{range .items[*]}{.spec.cidr}{"\n"}{end}' 2>/dev/null \
    | grep -qx "$POD_SUBNET"
}

calico_bgp_disabled() {
  [[ "$(kubectl get installation default -o jsonpath='{.spec.calicoNetwork.bgp}' 2>/dev/null)" == "Disabled" ]]
}

flannel_netconf_valid() {
  local netconf
  netconf="$(kubectl get configmap kube-flannel-cfg -n kube-flannel \
    -o go-template='{{index .data "net-conf.json"}}' 2>/dev/null)" || return 1
  [[ -n "$netconf" ]] || return 1

  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$netconf" | jq -e --arg net "$POD_SUBNET" \
      '.Network == $net and .Backend.Type == "vxlan"' >/dev/null
  else
    grep -Eq "\"Network\"[[:space:]]*:[[:space:]]*\"$POD_SUBNET\"" <<< "$netconf" \
      && grep -Eq '"Type"[[:space:]]*:[[:space:]]*"vxlan"' <<< "$netconf"
  fi
}

local_file_absent() {
  sudo test ! -e "$1"
}

remote_file_absent() {
  ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    node01 "sudo test ! -e '$1'" >/dev/null 2>&1
}

local_cni_config() {
  local file="$1" type="$2"
  sudo test -f "$file" && sudo grep -Eq "\"type\"[[:space:]]*:[[:space:]]*\"$type\"" "$file"
}

remote_cni_config() {
  local file="$1" type="$2"
  ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null node01 \
    "sudo test -f '$file' && sudo grep -Eq '\"type\"[[:space:]]*:[[:space:]]*\"$type\"' '$file'" >/dev/null 2>&1
}

local_flannel_subnet() {
  sudo test -f /run/flannel/subnet.env \
    && sudo grep -qx "FLANNEL_NETWORK=$POD_SUBNET" /run/flannel/subnet.env
}

remote_flannel_subnet() {
  ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null node01 \
    "sudo test -f /run/flannel/subnet.env && sudo grep -qx 'FLANNEL_NETWORK=$POD_SUBNET' /run/flannel/subnet.env" \
    >/dev/null 2>&1
}

local_link_exists() {
  ip link show "$1" >/dev/null 2>&1
}

remote_link_exists() {
  ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null node01 \
    "ip link show '$1' >/dev/null 2>&1" >/dev/null 2>&1
}

coredns_running() {
  local out
  out="$(kubectl get pods -n kube-system -l k8s-app=kube-dns \
    -o jsonpath='{range .items[*]}{.status.phase}{"/"}{.status.containerStatuses[0].ready}{"\n"}{end}' 2>/dev/null)"
  [[ -n "$out" ]] && ! grep -qv '^Running/true$' <<< "$out"
}

nodes_ready() {
  local count not_ready
  count="$(kubectl get nodes --no-headers 2>/dev/null | wc -l)"
  not_ready="$(kubectl get nodes --no-headers 2>/dev/null | grep -v ' Ready ' | wc -l)"
  [[ "$count" -ge 1 && "$not_ready" -eq 0 ]]
}

echo "============================================"
echo " Validating Question 8: CNI & Network Policy"
echo " Variant: $VARIANT/$VARIANT_COUNT"
echo " Profile: $CNI_DISPLAY $CNI_VERSION"
echo " Pod subnet: $POD_SUBNET"
if (( REQUIRE_NETWORK_POLICY == 1 )); then
  echo " NetworkPolicy enforcement: required"
else
  echo " NetworkPolicy enforcement: not required for this profile"
fi
echo "============================================"
echo

# Checks shared by both profiles.
check "All nodes are Ready" nodes_ready
check "CoreDNS pods are Running" coredns_running
check "Cilium CNI workloads are not active" bash -c '
  ! kubectl get daemonset cilium -n kube-system >/dev/null 2>&1 &&
  ! kubectl get daemonset cilium-envoy -n kube-system >/dev/null 2>&1 &&
  ! kubectl get deployment cilium-operator -n kube-system >/dev/null 2>&1
'
check "Cilium CNI config is absent on controlplane" local_file_absent /etc/cni/net.d/05-cilium.conflist
check "Cilium CNI config is absent on node01" remote_file_absent /etc/cni/net.d/05-cilium.conflist
check "Canal is not installed" bash -c '
  ! kubectl get daemonset canal -n kube-system >/dev/null 2>&1 &&
  ! kubectl get configmap canal-config -n kube-system >/dev/null 2>&1
'

if [[ "$CNI_PROFILE" == "calico" ]]; then
  check "Tigera operator namespace exists" kubectl get namespace tigera-operator
  check "Calico system namespace exists" kubectl get namespace calico-system
  check "Calico DaemonSet is ready on all nodes" ds_ready calico-system calico-node
  check "Calico kube-controllers Deployment is available" \
    deployment_available calico-system calico-kube-controllers
  check "Calico Installation 'default' exists" \
    kubectl get installation.operator.tigera.io default
  check "Calico node image is $CNI_VERSION" \
    ds_image_contains calico-system calico-node ":$CNI_VERSION"
  check "Calico IP pool uses $POD_SUBNET" calico_pool_matches
  check "Calico BGP is Disabled" calico_bgp_disabled
  check "Calico NetworkPolicy CRD exists" \
    kubectl get crd networkpolicies.crd.projectcalico.org
  check "Calico CNI config is active on controlplane" \
    local_cni_config "/etc/cni/net.d/$CNI_CONFIG_FILE" calico
  check "Calico CNI config is active on node01" \
    remote_cni_config "/etc/cni/net.d/$CNI_CONFIG_FILE" calico
  check "Flannel is not installed" bash -c '
    ! kubectl get namespace kube-flannel >/dev/null 2>&1 &&
    ! kubectl get daemonset kube-flannel-ds -n kube-flannel >/dev/null 2>&1
  '
  check "Flannel CNI config is absent on controlplane" \
    local_file_absent /etc/cni/net.d/10-flannel.conflist
  check "Flannel CNI config is absent on node01" \
    remote_file_absent /etc/cni/net.d/10-flannel.conflist
  check "Canal CNI config is absent on controlplane" \
    local_file_absent /etc/cni/net.d/10-canal.conflist
  check "Canal CNI config is absent on node01" \
    remote_file_absent /etc/cni/net.d/10-canal.conflist
else
  check "VXLAN overlay namespace exists" kubectl get namespace kube-flannel
  check "VXLAN overlay DaemonSet is ready on all nodes" ds_ready kube-flannel kube-flannel-ds
  check "VXLAN overlay image is $CNI_VERSION" \
    ds_image_contains kube-flannel kube-flannel-ds ":$CNI_VERSION"
  check "VXLAN overlay ConfigMap exists" \
    kubectl get configmap kube-flannel-cfg -n kube-flannel
  check "VXLAN overlay network uses $POD_SUBNET and backend vxlan" flannel_netconf_valid
  check "VXLAN overlay CNI config is active on controlplane" \
    local_cni_config "/etc/cni/net.d/$CNI_CONFIG_FILE" flannel
  check "VXLAN overlay CNI config is active on node01" \
    remote_cni_config "/etc/cni/net.d/$CNI_CONFIG_FILE" flannel
  check "VXLAN overlay subnet.env matches $POD_SUBNET on controlplane" local_flannel_subnet
  check "VXLAN overlay subnet.env matches $POD_SUBNET on node01" remote_flannel_subnet
  check "VXLAN device flannel.1 exists on controlplane" local_link_exists flannel.1
  check "VXLAN device flannel.1 exists on node01" remote_link_exists flannel.1
  check "Calico is not installed" bash -c '
    ! kubectl get namespace calico-system >/dev/null 2>&1 &&
    ! kubectl get namespace tigera-operator >/dev/null 2>&1 &&
    ! kubectl get daemonset calico-node -n kube-system >/dev/null 2>&1
  '
  check "Calico CNI config is absent on controlplane" \
    local_file_absent /etc/cni/net.d/10-calico.conflist
  check "Calico CNI config is absent on node01" \
    remote_file_absent /etc/cni/net.d/10-calico.conflist
  check "Canal CNI config is absent on controlplane" \
    local_file_absent /etc/cni/net.d/10-canal.conflist
  check "Canal CNI config is absent on node01" \
    remote_file_absent /etc/cni/net.d/10-canal.conflist
fi

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
if (( FAIL == 0 )); then
  echo "All checks passed!"
  exit 0
else
  echo "Some checks failed."
  exit 1
fi
