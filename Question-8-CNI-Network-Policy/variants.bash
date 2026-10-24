#!/bin/bash
# Variant presets for Question 8 - CNI & Network Policy.
#
# variant_config is the single source of truth for the CNI profile, version,
# manifests, namespaces, CNI config file, and policy requirement. The cluster
# pod subnet is derived from the live kubeadm configuration by setup and
# validation, not hard-coded in the presets.
#
# Both presets print the same upstream Flannel and Calico options. The
# requirement list, release qualifier, and run details are selected from the
# active variant so the printed task points at the CNI that setup expects.

VARIANT_COUNT=2

# Fixed upstream options shown in the printed question.
FLANNEL_VERSION="v0.26.1"
FLANNEL_MANIFEST_NAME="kube-flannel.yml"
FLANNEL_MANIFEST_URL="https://github.com/flannel-io/flannel/releases/download/v0.26.1/kube-flannel.yml"
CALICO_VERSION="v3.28.2"
CALICO_MANIFEST_NAME="tigera-operator.yaml"
CALICO_MANIFEST_URL="https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/tigera-operator.yaml"
CALICO_EXTRA_MANIFEST_URL="https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/custom-resources.yaml"

variant_config() {
  local variant="${1:-}"

  case "$variant" in
    1)
      CNI_PROFILE="calico"
      CNI_DISPLAY="Calico"
      CNI_VERSION="$CALICO_VERSION"
      CNI_MANIFEST_URL="$CALICO_MANIFEST_URL"
      CNI_EXTRA_MANIFEST_URL="$CALICO_EXTRA_MANIFEST_URL"
      CNI_NAMESPACE="calico-system"
      CNI_DAEMONSET="calico-node"
      CNI_DEPLOYMENT="calico-kube-controllers"
      CNI_CONFIG_FILE="10-calico.conflist"
      REQUIRE_NETWORK_POLICY=1
      VARIANT_SUMMARY="profile=calico-${CNI_VERSION}, podSubnet=${POD_SUBNET:-<cluster-pod-subnet>}, policy=enforced"
      ;;
    2)
      CNI_PROFILE="vxlan-overlay"
      CNI_DISPLAY="VXLAN overlay"
      CNI_VERSION="$FLANNEL_VERSION"
      CNI_MANIFEST_URL="$FLANNEL_MANIFEST_URL"
      CNI_EXTRA_MANIFEST_URL=""
      CNI_NAMESPACE="kube-flannel"
      CNI_DAEMONSET="kube-flannel-ds"
      CNI_DEPLOYMENT=""
      CNI_CONFIG_FILE="10-flannel.conflist"
      REQUIRE_NETWORK_POLICY=0
      VARIANT_SUMMARY="profile=vxlan-overlay-${CNI_VERSION}, podSubnet=${POD_SUBNET:-<cluster-pod-subnet>}, policy=not required"
      ;;
    *)
      echo "Error: unknown variant '$variant' (expected 1..$VARIANT_COUNT)" >&2
      return 1
      ;;
  esac
}

variant_question() {
  local variant="${1:-?}"
  local subnet="${POD_SUBNET:-<cluster-pod-subnet>}"
  local variant_requirement manifest_requirement run_details

  case "$variant" in
    1)
      variant_requirement="2. Support network policy enforcement"
      manifest_requirement="3. Install from manifest (release $CALICO_VERSION)"
      run_details="- In custom-resources.yaml, set the IP pool CIDR to $subnet and
  set spec.calicoNetwork.bgp to Disabled; this cluster's underlay does
  not exchange BGP."
      ;;
    2)
      variant_requirement='2. Use a VXLAN overlay (backend type "vxlan") with no BGP requirement'
      manifest_requirement="3. Install from manifest (release $FLANNEL_VERSION)"
      run_details="- In $FLANNEL_MANIFEST_NAME, change net-conf.json Network from 10.244.0.0/16
  to $subnet and keep the backend type \"vxlan\"."
      ;;
    *)
      echo "Error: unknown variant '$variant' (expected 1..$VARIANT_COUNT)" >&2
      return 1
      ;;
  esac

  cat <<EOF
============================================================
 Question 8: CNI & Network Policy (Variant $variant/$VARIANT_COUNT)
============================================================

Install and configure a CNI of your choice that meets the specified requirements,
Choose one of the following:

Flannel ($FLANNEL_VERSION) using the manifest $FLANNEL_MANIFEST_NAME
($FLANNEL_MANIFEST_URL)

or

Calico ($CALICO_VERSION) using the manifest $CALICO_MANIFEST_NAME
($CALICO_MANIFEST_URL)

The CNI you choose must
1. Let pods communicate with each other
$variant_requirement
$manifest_requirement

Run details:
- Cluster pod subnet: $subnet
$run_details

Verify all nodes are Ready and the CoreDNS pods are Running.

Video Link - https://youtu.be/Uc04Ui4x3EM
============================================================
EOF
}
