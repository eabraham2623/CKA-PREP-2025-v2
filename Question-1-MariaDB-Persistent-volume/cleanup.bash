#!/bin/bash
# Cleanup script for Question 1 - MariaDB Persistent Volume
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../scripts/lib/variant.sh
source "$REPO_ROOT/scripts/lib/variant.sh"
# shellcheck source=variants.bash
source "$SCRIPT_DIR/variants.bash"

echo "Cleaning up Question 1: MariaDB Persistent Volume..."

# Clean every preset, not only the recorded one. This makes switching variants
# and re-running cleanup safe even if a previous run left stale resources.
for ((v = 1; v <= VARIANT_COUNT; v++)); do
  variant_config "$v"
  echo "  Removing variant $v resources (namespace '$NS')..."

  kubectl delete deployment "$DEPLOY" -n "$NS" --ignore-not-found
  kubectl delete pvc "$PVC" -n "$NS" --ignore-not-found
  kubectl delete pv "$PV" --ignore-not-found

  if kubectl get namespace "$NS" >/dev/null 2>&1; then
    kubectl delete namespace "$NS" --ignore-not-found
    kubectl wait --for=delete "namespace/$NS" --timeout=60s 2>/dev/null || true
  fi
done

rm -f "$HOME/mariadb-deploy.yaml" "$HOME/pvc.yaml"
cka_variant_clear "$SCRIPT_DIR"

echo "[OK] Question 1 cleanup complete"
