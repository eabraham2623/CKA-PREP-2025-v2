#!/bin/bash
# Variant presets for Question 8 - CNI & Network Policy.
#
# variant_config is the single source of truth for the CNI profile, version,
# manifests, namespaces, CNI config file, and policy requirement. The cluster
# pod subnet is derived from the live kubeadm configuration by setup and
# validation, not hard-coded in the presets.
#
# Variant 2 is intentionally described only by its VXLAN/no-BGP profile and
# release version. Setup output must not name the CNI so the learner has to
# identify it from the clues.

VARIANT_COUNT=2

variant_config() {
  local variant="${1:-}"

  case "$variant" in
    1)
      CNI_PROFILE="calico"
      CNI_DISPLAY="Calico"
      CNI_VERSION="v3.28.2"
      CNI_MANIFEST_URL="https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/tigera-operator.yaml"
      CNI_EXTRA_MANIFEST_URL="https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/custom-resources.yaml"
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
      CNI_VERSION="v0.26.1"
      CNI_MANIFEST_URL="https://github.com/flannel-io/flannel/releases/download/v0.26.1/kube-flannel.yml"
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

  case "$variant" in
    1)
      cat <<EOF
============================================================
 Question 8: CNI & Network Policy (Variant $variant/$VARIANT_COUNT)
============================================================

The cluster has no working CNI and pods cannot communicate.

Install Calico $CNI_VERSION with the Tigera operator:

1. Apply the $CNI_VERSION tigera-operator.yaml manifest.
2. Download the $CNI_VERSION custom-resources.yaml, then set:
   - calicoNetwork.bgp: Disabled (this cluster's underlay does not
     exchange BGP)
   - the IP pool CIDR to the cluster's pod subnet, $POD_SUBNET
   Apply the edited manifest.
3. Verify the Calico pods are running, all nodes are Ready, and the
   CoreDNS pods are Running.
4. Confirm the CNI supports NetworkPolicy enforcement.

Do not install any other CNI alongside Calico.

Video Link - https://youtu.be/Uc04Ui4x3EM
============================================================
EOF
      ;;
    2)
      cat <<EOF
============================================================
 Question 8: CNI & Network Policy (Variant $variant/$VARIANT_COUNT)
============================================================

The cluster has no working CNI and pods cannot communicate.

Install the CNI that matches this profile:

1. Pod-to-pod traffic uses a VXLAN overlay (backend type "vxlan")
   and does not require BGP.
2. The CNI is installed from the upstream manifest published with
   release $CNI_VERSION.
3. The manifest's default pod network is 10.244.0.0/16. Change the
   network configuration to the cluster's pod subnet, $POD_SUBNET,
   before applying the manifest.
4. All nodes must become Ready and the CoreDNS pods must be Running.

This profile does not require NetworkPolicy enforcement. The Calico
profile is the policy-enforcing preset; Question 13 covers policy
separately.

Do not install any other CNI alongside it.

Video Link - https://youtu.be/Uc04Ui4x3EM
============================================================
EOF
      ;;
    *)
      echo "Error: unknown variant '$variant' (expected 1..$VARIANT_COUNT)" >&2
      return 1
      ;;
  esac
}
