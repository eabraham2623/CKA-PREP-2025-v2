#!/bin/bash
# Validation script for Question 9 - cri-dockerd
set -uo pipefail

QUESTION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$QUESTION_DIR/.." && pwd)"
source "$REPO_ROOT/scripts/lib/variant.sh"
source "$QUESTION_DIR/variants.bash"

SELECTED_VARIANT="$(cka_variant_read "$QUESTION_DIR" "$VARIANT_COUNT")" || exit 1
variant_config "$SELECTED_VARIANT" || exit 1

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

check_sysctl() {
  local key="$1"
  local expected="$2"
  [[ "$(sysctl -n "$key" 2>/dev/null)" == "$expected" ]]
}

persisted_settings_match() {
  local i actual
  [[ -f "$SYSCTL_FILE" ]] || return 1
  for i in "${!SYSCTL_KEYS[@]}"; do
    actual="$(awk -F= -v key="${SYSCTL_KEYS[$i]}" '
      {
        name = $1
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
        if (name == key) {
          value = substr($0, index($0, "=") + 1)
          sub(/[[:space:]]*#.*/, "", value)
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
        }
      }
      END { if (value != "") print value }
    ' "$SYSCTL_FILE")"
    [[ "$actual" == "${SYSCTL_VALUES[$i]}" ]] || return 1
  done
}

echo "======================================"
echo " Validating Question 9: cri-dockerd"
echo " Variant $SELECTED_VARIANT/$VARIANT_COUNT"
echo "======================================"

check "cri-dockerd package is installed" \
  bash -c 'dpkg -l cri-dockerd 2>/dev/null | grep -q "^ii"'
check "$CRI_DOCKER_SERVICE is enabled" \
  bash -c 'systemctl is-enabled "$1" 2>/dev/null | grep -qx enabled' _ "$CRI_DOCKER_SERVICE"
check "$CRI_DOCKER_SERVICE is active (running)" \
  bash -c 'systemctl is-active "$1" 2>/dev/null | grep -qx active' _ "$CRI_DOCKER_SERVICE"

for i in "${!SYSCTL_KEYS[@]}"; do
  check "sysctl ${SYSCTL_KEYS[$i]} = ${SYSCTL_VALUES[$i]}" \
    check_sysctl "${SYSCTL_KEYS[$i]}" "${SYSCTL_VALUES[$i]}"
done
check "all selected sysctl values are persisted in $SYSCTL_FILE" persisted_settings_match

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
if [[ $FAIL -eq 0 ]]; then
  echo "All checks passed!"
  exit 0
fi
echo "Some checks failed."
exit 1
