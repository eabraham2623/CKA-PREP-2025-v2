#!/bin/bash
# LabSetUp.bash for Question 15 - Etcd Fix variants.
set -uo pipefail

if (( $# > 1 )); then
  echo "Usage: $0 [variant]" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../scripts/lib/variant.sh
source "$REPO_ROOT/scripts/lib/variant.sh"
# shellcheck source=q15-lib.bash
source "$SCRIPT_DIR/q15-lib.bash"
# shellcheck source=variants.bash
source "$SCRIPT_DIR/variants.bash"

VARIANT="$(cka_variant_select "$SCRIPT_DIR" "$VARIANT_COUNT" "${1:-}")" || exit 1
variant_config "$VARIANT" || exit 1

echo "============================================================"
echo " Question 15: Etcd Fix"
echo " Variant $VARIANT/$VARIANT_COUNT selected for this run"
echo " $VARIANT_SUMMARY"
echo "============================================================"
echo

fail_setup() {
  echo
  echo "Setup failed: $*" >&2
  if [[ -s "$Q15_BASELINE_READY" ]]; then
    echo "Restoring the pristine control-plane baseline..." >&2
    if q15_restore_baseline; then
      echo "Baseline restored successfully." >&2
    else
      echo "WARNING: baseline restoration failed. Re-run $0 or repair the control plane manually." >&2
    fi
  else
    echo "No pristine baseline is available; no automatic repair was attempted." >&2
  fi
  exit 1
}

echo "Preparing a clean control-plane baseline..."
q15_ensure_baseline || fail_setup "could not prepare the baseline"

echo "Applying the selected fault(s)..."
if [[ -n "$COREDNS_FAULT" ]]; then
  q15_apply_coredns_fault || fail_setup "could not apply the CoreDNS fault"
fi

if [[ -n "$SCHEDULER_CPU_FAULT" ]]; then
  q15_set_container_resources "$Q15_SCHEDULER_MANIFEST" "$SCHEDULER_CPU_FAULT" "" ||
    fail_setup "could not apply the scheduler resource fault"
fi

if [[ -n "$CONTROLLER_CPU_FAULT" || -n "$CONTROLLER_MEMORY_FAULT" ]]; then
  q15_set_container_resources "$Q15_CONTROLLER_MANIFEST" \
    "$CONTROLLER_CPU_FAULT" "$CONTROLLER_MEMORY_FAULT" ||
    fail_setup "could not apply the controller-manager resource fault"
fi

echo "Waiting for the selected failure symptom(s)..."
if [[ -n "$COREDNS_FAULT" ]]; then
  echo "  - cluster DNS resolution failing"
  q15_wait_dns_broken ||
    fail_setup "cluster DNS did not stop resolving"
fi

if [[ -n "$SCHEDULER_CPU_FAULT" ]]; then
  echo "  - kube-scheduler container not running"
  q15_wait_component_not_running kube-scheduler ||
    fail_setup "kube-scheduler did not become unschedulable"
  q15_wait_component_status_not_running kube-scheduler 60 || true
fi

if [[ -n "$CONTROLLER_CPU_FAULT" || -n "$CONTROLLER_MEMORY_FAULT" ]]; then
  echo "  - kube-controller-manager container not running"
  q15_wait_component_not_running kube-controller-manager ||
    fail_setup "kube-controller-manager did not become unstable"
  q15_wait_component_status_not_running kube-controller-manager 60 || true
fi

# The API-server fault is applied last: once kubelet reloads the manifest,
# kubectl is unavailable and only node-level diagnostics remain.
if [[ -n "$ETCD_FAULT" ]]; then
  echo "  - kube-apiserver cannot reach etcd (API becomes unavailable)"
  q15_set_etcd_servers "$ETCD_FAULT_VALUE" ||
    fail_setup "could not apply the etcd endpoint fault"
  q15_wait_api_down || fail_setup "the API server did not go down as expected"
fi

echo
q15_print_status
echo
variant_question "$VARIANT"
