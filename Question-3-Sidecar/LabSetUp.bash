#!/bin/bash
set -e

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
echo " Question 3: Sidecar Container"
echo " Variant $VARIANT/$VARIANT_COUNT selected for this run"
echo " $VARIANT_SUMMARY"
echo "============================================================"
echo

echo "Resetting any previous resources for variant $VARIANT..."
if [[ "$NS" == "default" ]]; then
  kubectl delete deployment "$DEPLOY" -n "$NS" --ignore-not-found
  kubectl delete service "$SERVICE" -n "$NS" --ignore-not-found 2>/dev/null || true
else
  if kubectl get namespace "$NS" >/dev/null 2>&1; then
    kubectl delete namespace "$NS" --ignore-not-found
    kubectl wait --for=delete "namespace/$NS" --timeout=60s 2>/dev/null || true
  fi
  kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
fi

# Create the deployment without a log volume. The learner must add the shared
# volume, mount it in the existing main container, and add the sidecar.
cat <<EOF | kubectl apply -n "$NS" -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $DEPLOY
  namespace: $NS
  labels:
    app: $APP_LABEL
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $APP_LABEL
  template:
    metadata:
      labels:
        app: $APP_LABEL
    spec:
      containers:
      - name: $APP_CONTAINER
        image: $MAIN_IMAGE
        command: ["/bin/sh", "-c", "while true; do echo '$LOG_MESSAGE' >> $LOG_FILE; sleep 5; done"]
        ports:
        - containerPort: $TARGET_PORT
EOF

# Create the service that exposes the deployment.
cat <<EOF | kubectl apply -n "$NS" -f -
apiVersion: v1
kind: Service
metadata:
  name: $SERVICE
  namespace: $NS
spec:
  selector:
    app: $APP_LABEL
  ports:
  - port: $SERVICE_PORT
    targetPort: $TARGET_PORT
EOF

echo
echo "[OK] Lab setup complete!"
echo
echo "Deployment '$DEPLOY' and Service '$SERVICE' created in namespace '$NS'."
echo "The existing '$APP_CONTAINER' container writes to '$LOG_FILE'."
echo "You can now edit the deployment to add the sidecar container and shared volume."
echo

variant_question "$VARIANT"
