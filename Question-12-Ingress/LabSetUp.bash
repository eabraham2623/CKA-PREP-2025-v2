#!/bin/bash
# LabSetUp.bash for Question 12 - Ingress
set -euo pipefail

if (( $# > 1 )); then
  echo "Usage: $0 [variant]" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../scripts/lib/variant.sh
source "$REPO_ROOT/scripts/lib/variant.sh"
# shellcheck source=variants.bash
source "$SCRIPT_DIR/variants.bash"

VARIANT="$(cka_variant_select "$SCRIPT_DIR" "$VARIANT_COUNT" "${1:-}")"
variant_config "$VARIANT"

echo "============================================================"
echo " Question 12: Ingress"
echo " Variant $VARIANT/$VARIANT_COUNT selected for this run"
echo " $VARIANT_SUMMARY"
echo "============================================================"
echo

echo "Creating namespace: $NS"
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

# Start from a clean slate: remove every preset's resources so switching
# variants cannot leave a stale Deployment, Service, or Ingress behind.
echo "Removing resources from earlier attempts or variants..."
for ((v = 1; v <= VARIANT_COUNT; v++)); do
  variant_config "$v"
  kubectl delete ingress "$INGRESS" -n "$NS" --ignore-not-found --wait=true --timeout=30s >/dev/null 2>&1 || true
  kubectl delete service "$SERVICE" -n "$NS" --ignore-not-found --wait=true --timeout=30s >/dev/null 2>&1 || true
  kubectl delete deployment "$DEPLOYMENT" -n "$NS" --ignore-not-found --wait=true --timeout=60s >/dev/null 2>&1 || true
done
variant_config "$VARIANT"

rm -f "$HOME/ingress.yaml"

echo "Deploying $DEPLOYMENT in namespace: $NS"
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $DEPLOYMENT
  namespace: $NS
spec:
  replicas: $REPLICAS
  selector:
    matchLabels:
      app: $APP_LABEL
  template:
    metadata:
      labels:
        app: $APP_LABEL
    spec:
      containers:
      - name: $APP_LABEL
        image: $IMAGE
        ports:
        - containerPort: $CONTAINER_PORT
EOF

echo
echo "[OK] Question 12 setup complete."
echo "   - Namespace: $NS"
echo "   - Deployment: $DEPLOYMENT (image $IMAGE, container port $CONTAINER_PORT)"
echo

variant_question "$VARIANT"
