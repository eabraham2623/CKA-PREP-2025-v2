#!/bin/bash
# LabSetUp.bash for Question 16 - NodePort Service
set -euo pipefail

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
echo " Question 16: NodePort Service"
echo " Variant $VARIANT/$VARIANT_COUNT selected for this run"
echo " $VARIANT_SUMMARY"
echo "============================================================"
echo

# Reset every preset, not only the recorded one, so switching variants or
# re-running setup cannot leave an old Deployment or Service behind.
echo "Removing resources from earlier attempts or variants..."
for ((v = 1; v <= VARIANT_COUNT; v++)); do
  variant_config "$v"
  if kubectl get namespace "$NS" >/dev/null 2>&1; then
    kubectl delete service "$SVC" -n "$NS" --ignore-not-found >/dev/null 2>&1 || true
    kubectl delete deployment "$DEPLOY" -n "$NS" --ignore-not-found \
      --cascade=foreground --wait=true --timeout=90s >/dev/null 2>&1 || true
  fi
done
variant_config "$VARIANT"

echo "Creating namespace '$NS'..."
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

echo "Creating deployment '$DEPLOY' with $REPLICAS replicas..."
kubectl apply -n "$NS" -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $DEPLOY
  namespace: $NS
  labels:
    app: $APP_LABEL
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
      - name: nginx
        image: $IMAGE
EOF

echo "Waiting for the deployment to become available..."
kubectl rollout status "deployment/$DEPLOY" -n "$NS" --timeout=120s || true

echo
echo "[OK] Lab setup complete!"
echo "   - Namespace: $NS"
echo "   - Deployment: $DEPLOY"
echo "   - Service to create: $SVC"
echo "   - NodePort: $NODEPORT"
echo

variant_question "$VARIANT"
