#!/bin/bash
set -euo pipefail

if (( $# > 1 )); then
  echo "Usage: $0 [variant]" >&2
  exit 1
fi

QUESTION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$QUESTION_DIR/.." && pwd)"
source "$REPO_ROOT/scripts/lib/variant.sh"
source "$QUESTION_DIR/variants.bash"

SELECTED_VARIANT="$(cka_variant_select "$QUESTION_DIR" "$VARIANT_COUNT" "${1:-}")"
variant_config "$SELECTED_VARIANT"

# Record the pre-lab value of every key this variant may touch. Cleanup
# restores only these values, so it cannot revert unrelated cluster settings.
BACKUP_FILE="$REPO_ROOT/.cka-state/$(basename "$QUESTION_DIR").sysctl"
record_sysctl_baseline() {
  local i key current
  mkdir -p "$(dirname "$BACKUP_FILE")"
  touch "$BACKUP_FILE"
  for i in "${!SYSCTL_KEYS[@]}"; do
    key="${SYSCTL_KEYS[$i]}"
    if grep -Fq -- "$key=" "$BACKUP_FILE"; then
      continue
    fi
    current="$(sysctl -n "$key" 2>/dev/null || true)"
    if [[ -n "$current" ]]; then
      printf '%s=%s\n' "$key" "$current" >> "$BACKUP_FILE"
    fi
  done
}
record_sysctl_baseline

echo "Variant $SELECTED_VARIANT/$VARIANT_COUNT"
echo "$VARIANT_SUMMARY"
variant_question "$SELECTED_VARIANT"

# Download the pinned cri-dockerd package to /root, matching the lab topology.
wget "$CRI_DOCKER_URL" -O "$CRI_DOCKER_DEB"
echo "cri-dockerd package downloaded to $CRI_DOCKER_DEB"
