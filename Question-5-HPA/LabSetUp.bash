#!/bin/bash
# LabSetUp.bash for Question 5 - HPA
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
echo " Question 5: HPA - HorizontalPodAutoscaler"
echo " Variant $VARIANT/$VARIANT_COUNT selected for this run"
echo " $VARIANT_SUMMARY"
echo "============================================================"
echo

echo "Creating namespace '$NS'..."
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

# Remove every preset's workload so switching variants cannot leave an old
# Deployment, Service, or HPA behind.
echo "Resetting any previous Question 5 workloads..."
for ((v = 1; v <= VARIANT_COUNT; v++)); do
  variant_config "$v"
  kubectl delete hpa "$HPA" -n "$NS" --ignore-not-found >/dev/null
  kubectl delete deployment "$DEPLOY" -n "$NS" --ignore-not-found \
    --cascade=foreground --wait=true --timeout=90s >/dev/null
  kubectl delete service "$DEPLOY" -n "$NS" --ignore-not-found >/dev/null
done
variant_config "$VARIANT"

echo "Deploying metrics-server (required for HPA)..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

echo "Patching metrics-server to allow insecure TLS (Killercoda environment)..."
METRICS_ARGS="$(kubectl get deployment metrics-server -n kube-system \
  -o jsonpath='{range .spec.template.spec.containers[0].args[*]}{@}{"\n"}{end}' 2>/dev/null || true)"
if ! grep -qx -- '--kubelet-insecure-tls' <<< "$METRICS_ARGS"; then
  kubectl patch deployment metrics-server -n kube-system \
    --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'
fi

echo "Waiting for metrics-server rollout..."
kubectl rollout status deployment metrics-server -n kube-system --timeout=180s

echo "Creating deployment '$DEPLOY'..."
kubectl apply -n "$NS" -f - <<EOF
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
      - name: $CONTAINER
        image: $IMAGE
        ports:
        - containerPort: $CONTAINER_PORT
        resources:
          requests:
            cpu: $CPU_REQUEST
          limits:
            cpu: $CPU_LIMIT
EOF

echo "Exposing deployment '$DEPLOY' internally..."
kubectl expose deployment "$DEPLOY" -n "$NS" --port=80 --target-port="$CONTAINER_PORT"

echo
echo "[OK] Lab setup complete!"
echo "   - Namespace: $NS"
echo "   - Deployment: $DEPLOY"
echo "   - Service: $DEPLOY"
echo

variant_question "$VARIANT"
