#!/bin/bash
# Validation script for Question 2 - ArgoCD Helm template
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../scripts/lib/variant.sh
source "$REPO_ROOT/scripts/lib/variant.sh"
# shellcheck source=variants.bash
source "$SCRIPT_DIR/variants.bash"

VARIANT="$(cka_variant_read "$SCRIPT_DIR" "$VARIANT_COUNT")" || exit 1
variant_config "$VARIANT" || exit 1

PASS=0
FAIL=0
TOTAL=0

check() {
  local description="$1"
  shift
  TOTAL=$((TOTAL + 1))
  if "$@" >/dev/null 2>&1; then
    echo "  PASS: $description"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $description"
    FAIL=$((FAIL + 1))
  fi
}

namespace_is_active() {
  [[ "$(kubectl get namespace "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" == "Active" ]]
}

repo_alias_exists() {
  helm repo list 2>/dev/null | awk -v name="$REPO_NAME" '$1 == name { found = 1 } END { if (!found) exit 1 }'
}

repo_url_matches() {
  [[ "$(helm repo list 2>/dev/null | awk -v name="$REPO_NAME" '$1 == name { print $2; exit }')" == "$REPO_URL" ]]
}

output_exists() {
  [[ -f "$OUTPUT" ]]
}

output_not_empty() {
  [[ -s "$OUTPUT" ]]
}

manifest_namespace_matches() {
  [[ -s "$OUTPUT" ]] || return 1
  awk -v ns="$NS" '$1 == "namespace:" && $2 == ns { found = 1 } END { if (!found) exit 1 }' "$OUTPUT"
}

manifest_chart_version_matches() {
  [[ -s "$OUTPUT" ]] || return 1
  grep -q "helm.sh/chart: $CHART_NAME-$CHART_VERSION" "$OUTPUT"
}

manifest_has_deployment() {
  [[ -s "$OUTPUT" ]] || return 1
  grep -q '^kind: Deployment$' "$OUTPUT"
}

manifest_has_no_crds() {
  [[ -s "$OUTPUT" ]] || return 1
  ! grep -q '^kind: CustomResourceDefinition' "$OUTPUT"
}

manifest_variant_value_matches() {
  [[ -s "$OUTPUT" ]] || return 1

  case "$VALUE_KIND" in
    replicas)
      awk 'BEGIN { RS="---" } /templates\/argocd-server\/deployment\.yaml/ { print }' "$OUTPUT" \
        | grep -Eq "^  replicas: ${VALUE}[[:space:]]*$"
      ;;
    service-type)
      awk 'BEGIN { RS="---" } /templates\/argocd-server\/service\.yaml/ { print }' "$OUTPUT" \
        | grep -Eq "^  type: ${VALUE}[[:space:]]*$"
      ;;
    *)
      return 1
      ;;
  esac
}

echo "======================================"
echo " Validating Question 2: ArgoCD Helm"
echo " Variant: $VARIANT/$VARIANT_COUNT"
echo " Expected: repo=$REPO_NAME ($REPO_URL)"
echo "           namespace=$NS"
echo "           chart=$CHART_NAME-$CHART_VERSION"
echo "           output=$OUTPUT"
echo "           $VALUE_LABEL=$VALUE"
echo "======================================"

# 1. Namespace exists and is active
check "Namespace '$NS' exists and is Active" \
  namespace_is_active

# 2. Helm repo alias exists
check "Helm repo '$REPO_NAME' is added" \
  repo_alias_exists

# 3. Helm repo points to the official Argo CD chart repository
check "Helm repo '$REPO_NAME' points to $REPO_URL" \
  repo_url_matches

# 4. Output file exists
check "Manifest file '$OUTPUT' exists" \
  output_exists

# 5. Output file is not empty
check "Manifest file '$OUTPUT' is not empty" \
  output_not_empty

# 6. Manifest uses the variant's namespace
check "Manifest references namespace '$NS'" \
  manifest_namespace_matches

# 7. Manifest was generated from the expected chart version
check "Manifest uses chart '$CHART_NAME-$CHART_VERSION'" \
  manifest_chart_version_matches

# 8. Manifest contains a Deployment
check "Manifest contains at least one Deployment" \
  manifest_has_deployment

# 9. Variant-specific chart value is rendered
case "$VALUE_KIND" in
  replicas)
    check "Server Deployment has exactly $VALUE replicas" \
      manifest_variant_value_matches
    ;;
  service-type)
    check "Server Service has type $VALUE" \
      manifest_variant_value_matches
    ;;
esac

# 10. No CRDs in the generated manifest
check "No CustomResourceDefinition resources in the manifest" \
  manifest_has_no_crds

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
if [[ $FAIL -eq 0 ]]; then
  echo "All checks passed!"
  exit 0
else
  echo "Some checks failed."
  exit 1
fi
