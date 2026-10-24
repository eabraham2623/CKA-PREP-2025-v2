#!/bin/bash
# Cleanup script for Question 9 - Cri-Dockerd
set -uo pipefail
echo "Cleaning up Question 9: cri-dockerd..."

QUESTION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$QUESTION_DIR/.." && pwd)"
source "$REPO_ROOT/scripts/lib/variant.sh"

BACKUP_FILE="$REPO_ROOT/.cka-state/$(basename "$QUESTION_DIR").sysctl"
RESTORE_FAILED=0
restore_sysctl_baseline() {
  local key value rc=0
  if [[ ! -f "$BACKUP_FILE" ]]; then
    echo "Warning: no sysctl baseline recorded; leaving current kernel values unchanged." >&2
    return 0
  fi
  while IFS='=' read -r key value; do
    [[ -n "$key" && -n "$value" ]] || continue
    if ! sudo sysctl -w "$key=$value" >/dev/null 2>&1; then
      echo "Warning: could not restore $key=$value; keeping baseline file for a retry." >&2
      rc=1
    fi
  done < "$BACKUP_FILE"
  if (( rc != 0 )); then
    RESTORE_FAILED=1
    return 0
  fi
  rm -f "$BACKUP_FILE"
}

sudo systemctl disable --now cri-docker.service cri-docker.socket 2>/dev/null || true
sudo dpkg -r cri-dockerd 2>/dev/null || true
# The package can leave its socket node behind after removal.
sudo rm -f /run/cri-dockerd.sock
restore_sysctl_baseline
sudo rm -f /etc/sysctl.d/kube.conf
# Do not run "sysctl --system" here. It would re-apply every host sysctl file
# and could revert cluster networking settings that were not part of this lab.
cka_variant_clear "$QUESTION_DIR"

if (( RESTORE_FAILED != 0 )); then
  echo "[WARN] Question 9 cleanup incomplete: baseline kept for retry" >&2
  exit 1
fi
echo "[OK] Question 9 cleanup complete"
