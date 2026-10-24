# Install and run cri-dockerd using the selected variant's recorded values.
QUESTION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$QUESTION_DIR/.." && pwd)"
source "$REPO_ROOT/scripts/lib/variant.sh"
source "$QUESTION_DIR/variants.bash"
SELECTED_VARIANT="$(cka_variant_read "$QUESTION_DIR" "$VARIANT_COUNT")"
variant_config "$SELECTED_VARIANT"

sudo dpkg -i "$CRI_DOCKER_DEB"
sudo systemctl enable --now "$CRI_DOCKER_SERVICE"
sudo systemctl status "$CRI_DOCKER_SERVICE"

# Persist and apply the exact four sysctl settings for this variant.
{
  for i in "${!SYSCTL_KEYS[@]}"; do
    printf '%s=%s\n' "${SYSCTL_KEYS[$i]}" "${SYSCTL_VALUES[$i]}"
  done
} | sudo tee "$SYSCTL_FILE" >/dev/null
# Apply only this lab's file, not every sysctl file on the node.
sudo sysctl -p "$SYSCTL_FILE"
