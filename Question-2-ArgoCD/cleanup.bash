#!/bin/bash
# Cleanup script for Question 2 - ArgoCD
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../scripts/lib/variant.sh
source "$REPO_ROOT/scripts/lib/variant.sh"
# shellcheck source=variants.bash
source "$SCRIPT_DIR/variants.bash"

echo "Cleaning up Question 2: ArgoCD..."

# Clean every preset, not only the recorded one. This makes switching variants
# and re-running cleanup safe even if a previous run left stale resources.
for ((v = 1; v <= VARIANT_COUNT; v++)); do
  variant_config "$v"
  echo "  Removing variant $v resources (namespace '$NS')..."

  # Uninstall releases first so cluster-scoped resources are removed too.
  releases="$(helm list -n "$NS" -q 2>/dev/null || true)"
  if [[ -n "$releases" ]]; then
    while IFS= read -r release; do
      [[ -z "$release" ]] && continue
      helm uninstall "$release" -n "$NS" >/dev/null 2>&1 || true
    done <<< "$releases"
  fi

  if kubectl get namespace "$NS" >/dev/null 2>&1; then
    kubectl delete namespace "$NS" --ignore-not-found
    kubectl wait --for=delete "namespace/$NS" --timeout=60s 2>/dev/null || true
  fi

  helm repo remove "$REPO_NAME" >/dev/null 2>&1 || true
  rm -f "$OUTPUT"
done

# Remove the pre-variant location as well.
rm -f /root/argo-helm.yaml "$HOME/argo-helm.yaml"

cka_variant_clear "$SCRIPT_DIR"

echo "[OK] Question 2 cleanup complete"
