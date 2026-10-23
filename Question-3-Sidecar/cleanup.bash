#!/bin/bash
# Cleanup script for Question 3 - Sidecar
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../scripts/lib/variant.sh
source "$REPO_ROOT/scripts/lib/variant.sh"
# shellcheck source=variants.bash
source "$SCRIPT_DIR/variants.bash"

echo "Cleaning up Question 3: Sidecar..."

# Clean every preset, not only the recorded one, so switching variants and
# re-running cleanup is safe even if an earlier run left stale resources.
for ((v = 1; v <= VARIANT_COUNT; v++)); do
  variant_config "$v"
  echo "  Removing variant $v resources (namespace '$NS')..."

  if [[ "$NS" == "default" ]]; then
    # Never delete the default namespace.
    kubectl delete deployment "$DEPLOY" -n "$NS" --ignore-not-found
    kubectl delete service "$SERVICE" -n "$NS" --ignore-not-found 2>/dev/null || true
  else
    if kubectl get namespace "$NS" >/dev/null 2>&1; then
      kubectl delete namespace "$NS" --ignore-not-found
      kubectl wait --for=delete "namespace/$NS" --timeout=60s 2>/dev/null || true
    fi
  fi
done

cka_variant_clear "$SCRIPT_DIR"

echo "[OK] Question 3 cleanup complete"
