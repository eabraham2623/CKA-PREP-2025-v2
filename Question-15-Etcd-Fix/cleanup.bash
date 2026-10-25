#!/bin/bash
# Cleanup script for Question 15 - Etcd Fix variants.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../scripts/lib/variant.sh
source "$REPO_ROOT/scripts/lib/variant.sh"
# shellcheck source=q15-lib.bash
source "$SCRIPT_DIR/q15-lib.bash"

echo "Cleaning up Question 15: Etcd Fix..."

if [[ ! -s "$Q15_BASELINE_READY" ]]; then
  echo "No pristine Q15 baseline is recorded; nothing can be restored automatically."
  if [[ -f "$(cka_variant_state_file "$SCRIPT_DIR")" ]]; then
    echo "WARNING: a variant is recorded but the baseline is missing. The cluster may be broken." >&2
    echo "Repair the control plane manually or start a fresh disposable cluster." >&2
    cka_variant_clear "$SCRIPT_DIR"
    exit 1
  fi
  echo "[OK] Nothing to clean up."
  exit 0
fi

if ! q15_restore_baseline; then
  echo "ERROR: failed to restore the pristine control-plane baseline." >&2
  echo "The baseline was kept in $Q15_BASELINE_DIR for a retry." >&2
  exit 1
fi

rm -rf "$Q15_BASELINE_DIR"
cka_variant_clear "$SCRIPT_DIR"

echo "[OK] Question 15 cleanup complete; control plane restored to its pre-lab state."
