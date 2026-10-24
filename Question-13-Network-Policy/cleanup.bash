#!/bin/bash
# Cleanup script for Question 13 - Network Policy
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../scripts/lib/variant.sh
source "$REPO_ROOT/scripts/lib/variant.sh"
# shellcheck source=variants.bash
source "$SCRIPT_DIR/variants.bash"

echo "Cleaning up Question 13: Network Policy..."

kubectl delete networkpolicy --all -n "$NS_BACKEND" --ignore-not-found >/dev/null 2>&1 || true
kubectl delete namespace "$NS_FRONTEND" --ignore-not-found --wait=true --timeout=120s
kubectl delete namespace "$NS_BACKEND" --ignore-not-found --wait=true --timeout=120s

WORKDIR="${WORKDIR:-$PWD/network-policies}"
rm -rf "$WORKDIR"
cka_variant_clear "$SCRIPT_DIR"

echo "[OK] Question 13 cleanup complete"
