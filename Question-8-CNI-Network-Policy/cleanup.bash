#!/bin/bash
# Cleanup script for Question 8 - CNI & Network Policy
#
# Removes whichever CNI the learner installed (Calico, Flannel, or Canal),
# including host-level CNI artifacts, then restores the pre-Q8 Cilium CNI
# from the snapshot that LabSetUp.bash saved. Restoring Cilium also restores
# kube-proxy replacement, Services, DNS, and policy enforcement.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../scripts/lib/variant.sh
source "$REPO_ROOT/scripts/lib/variant.sh"
# shellcheck source=../scripts/lib/q8-cni.sh
source "$REPO_ROOT/scripts/lib/q8-cni.sh"

echo "Cleaning up Question 8: CNI & Network Policy..."
RC=0
NEEDS_REFRESH=0

if cka_q8_snapshot_exists; then
  NEEDS_REFRESH=1
fi
if cka_q8_other_cni_present; then
  NEEDS_REFRESH=1
fi

echo "Removing Calico, Flannel, and Canal resources..."
cka_q8_cleanup_other_cnis || RC=1
cka_q8_remove_other_cni_host || RC=1

if cka_q8_cilium_healthy; then
  echo "Cilium is already active; no reinstall needed."
  if (( NEEDS_REFRESH == 1 )); then
    cka_q8_wait_for_ready || RC=1
  fi
  cka_q8_clear_snapshot
elif cka_q8_snapshot_exists; then
  echo "Restoring the pre-Q8 Cilium CNI from the saved snapshot..."
  cka_q8_remove_cilium_host || RC=1
  if cka_q8_restore_cilium; then
    cka_q8_clear_snapshot
    echo "[OK] Cilium CNI and kube-proxy replacement restored."
    echo "     Nodes are Ready and CoreDNS has been recreated."
  else
    echo "Error: Cilium restore failed." >&2
    echo "The snapshot is kept at $(cka_q8_state_dir) for a retry." >&2
    RC=1
  fi
else
  echo "Warning: no Cilium restore snapshot was found." >&2
  echo "Calico/Flannel were removed, but no previous CNI could be restored." >&2
  echo "Run Question 8 setup again on a cluster with Cilium if you need a CNI." >&2
fi

cka_variant_clear "$SCRIPT_DIR"

if (( RC == 0 )); then
  echo "[OK] Question 8 cleanup complete"
else
  echo "Question 8 cleanup finished with errors." >&2
fi

exit "$RC"
