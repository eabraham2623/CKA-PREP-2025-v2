#!/bin/bash
# Validation script for Question 6 - CRDs (cert-manager)
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

file_contains() {
  local file="$1"
  local text="$2"
  grep -qF -- "$text" "$file"
}

echo "=================================================="
echo " Validating Question 6: CRDs"
echo " Variant: $VARIANT/$VARIANT_COUNT"
echo " Expected: cert-manager $CM_VERSION"
echo "           $EXPLAIN_TARGET documentation in $SUBJECT_FILE"
echo "=================================================="

# 1. Both answer files must exist and contain output.
check "File $RESOURCES_FILE exists" \
  test -f "$RESOURCES_FILE"
check "File $RESOURCES_FILE is not empty" \
  test -s "$RESOURCES_FILE"
check "File $SUBJECT_FILE exists" \
  test -f "$SUBJECT_FILE"
check "File $SUBJECT_FILE is not empty" \
  test -s "$SUBJECT_FILE"

# 2. The CRD list must contain every cert-manager CRD from the pinned release.
for crd in "${CERT_MANAGER_CRDS[@]}"; do
  check "$RESOURCES_FILE lists $crd" \
    file_contains "$RESOURCES_FILE" "$crd"
done

# 3. The documentation must match the exact field selected by the variant.
for marker in "${TARGET_MARKERS[@]}"; do
  check "$SUBJECT_FILE documents '$marker'" \
    file_contains "$SUBJECT_FILE" "$marker"
done

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
if (( FAIL == 0 )); then
  echo "All checks passed!"
  exit 0
else
  echo "Some checks failed."
  exit 1
fi
