#!/bin/bash
# Cleanup script for Question 17 - NGINX TLS Config
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../scripts/lib/variant.sh
source "$REPO_ROOT/scripts/lib/variant.sh"
# shellcheck source=variants.bash
source "$SCRIPT_DIR/variants.bash"

echo "Cleaning up Question 17: NGINX TLS Config..."

kubectl delete deployment "$DEPLOYMENT" -n "$NS" --ignore-not-found --wait=true >/dev/null 2>&1 || true
kubectl delete service "$SERVICE" -n "$NS" --ignore-not-found --wait=true >/dev/null 2>&1 || true
kubectl delete configmap "$CONFIGMAP" -n "$NS" --ignore-not-found >/dev/null 2>&1 || true
kubectl delete secret "$SECRET" -n "$NS" --ignore-not-found >/dev/null 2>&1 || true
kubectl delete namespace "$NS" --ignore-not-found --wait=true --timeout=120s >/dev/null 2>&1 || true

remove_hosts_entry() {
  local sed_cmd=(sed -E -i "/[[:space:]]${TLS_HOSTNAME}([[:space:]]|$)/d" /etc/hosts)
  if [[ -w /etc/hosts ]]; then
    "${sed_cmd[@]}"
  else
    sudo "${sed_cmd[@]}"
  fi
}

if ! remove_hosts_entry; then
  echo "Warning: could not remove the /etc/hosts entry for $TLS_HOSTNAME" >&2
fi

# Remove certificate artifacts left by older versions of this lab. Only remove
# files that are actually the lab certificate, not unrelated user files.
if [[ -f tls.crt ]] && openssl x509 -in tls.crt -noout -subject 2>/dev/null | grep -q "CN *= *$TLS_HOSTNAME"; then
  rm -f tls.key tls.crt
fi

cka_variant_clear "$SCRIPT_DIR"

echo "[OK] Question 17 cleanup complete"
