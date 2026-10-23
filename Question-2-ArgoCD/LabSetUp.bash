#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../scripts/lib/variant.sh
source "$REPO_ROOT/scripts/lib/variant.sh"
# shellcheck source=variants.bash
source "$SCRIPT_DIR/variants.bash"

REQUESTED_VARIANT="${1:-}"
if [[ -n "$REQUESTED_VARIANT" ]]; then
  VARIANT="$(cka_variant_select "$SCRIPT_DIR" "$VARIANT_COUNT" "$REQUESTED_VARIANT")"
else
  VARIANT="$(cka_variant_select "$SCRIPT_DIR" "$VARIANT_COUNT")"
fi
variant_config "$VARIANT"

echo "============================================================"
echo " Question 2: ArgoCD Helm Template"
echo " Variant $VARIANT/$VARIANT_COUNT selected for this run"
echo " $VARIANT_SUMMARY"
echo "============================================================"
echo

if ! command -v helm >/dev/null 2>&1; then
  echo "Error: helm is required for this lab but was not found." >&2
  exit 1
fi

echo "Resetting any previous resources for variant $VARIANT..."

# Uninstall any release in the target namespace first so cluster-scoped
# resources from an earlier attempt are removed as well.
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

echo "[OK] Lab setup complete!"
echo "   - Namespace '$NS', Helm repo '$REPO_NAME', and '$OUTPUT' were reset."
echo "   - No task resources are pre-created."
echo

variant_question "$VARIANT"
