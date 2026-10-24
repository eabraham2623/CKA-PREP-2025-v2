#!/bin/bash
# LabSetUp.bash for Question 8 - CNI & Network Policy
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../scripts/lib/variant.sh
source "$REPO_ROOT/scripts/lib/variant.sh"
# shellcheck source=../scripts/lib/q8-cni.sh
source "$REPO_ROOT/scripts/lib/q8-cni.sh"
# shellcheck source=variants.bash
source "$SCRIPT_DIR/variants.bash"

REQUESTED_VARIANT="${1:-}"
if [[ -n "$REQUESTED_VARIANT" ]]; then
  VARIANT="$(cka_variant_select "$SCRIPT_DIR" "$VARIANT_COUNT" "$REQUESTED_VARIANT")" || exit 1
else
  VARIANT="$(cka_variant_select "$SCRIPT_DIR" "$VARIANT_COUNT")" || exit 1
fi

POD_SUBNET="$(cka_q8_pod_subnet)" || exit 1
variant_config "$VARIANT" || exit 1

echo "============================================================"
echo " Question 8: CNI & Network Policy"
echo " Variant $VARIANT/$VARIANT_COUNT selected for this run"
echo " $VARIANT_SUMMARY"
echo "============================================================"
echo

# Save the pre-Q8 Cilium state before removing anything. Cleanup uses this
# snapshot to restore the cluster's original CNI and kube-proxy replacement.
echo "Saving the pre-Q8 CNI restore state..."
if cka_q8_cilium_present; then
  if ! cka_q8_snapshot_cilium; then
    echo "Error: could not snapshot the preinstalled Cilium CNI." >&2
    echo "Aborting before changing the cluster so cleanup can still restore it." >&2
    exit 1
  fi
  echo "  Cilium restore snapshot saved under .cka-state/q8-cilium/"
elif cka_q8_snapshot_exists; then
  echo "  Existing Cilium restore snapshot kept."
else
  echo "  Warning: no preinstalled Cilium detected."
  echo "  Cleanup will remove the installed CNI but cannot restore a previous CNI."
fi
echo

echo "Removing any CNI left by an earlier attempt..."
cka_q8_cleanup_other_cnis || echo "  Warning: some Calico/Flannel/Canal resources could not be removed."
cka_q8_stop_cilium
cka_q8_remove_other_cni_host || echo "  Warning: host CNI cleanup was incomplete on one or more nodes."
cka_q8_remove_cilium_host || echo "  Warning: Cilium host cleanup was incomplete on one or more nodes."

echo "Restarting CoreDNS so it is recreated after the new CNI is installed..."
kubectl rollout restart deployment coredns -n kube-system >/dev/null 2>&1 || true

echo
echo "[OK] Question 8 setup complete."
echo "   - The cluster has no active CNI until you install the selected profile."
echo "   - Pod network: $POD_SUBNET"
echo "   - Cleanup will restore the pre-Q8 Cilium CNI."
echo

variant_question "$VARIANT"
