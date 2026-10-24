#!/bin/bash
# LabSetUp.bash for Question 11 - Gateway API
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
echo " Question 11: Gateway API"
echo " Variant $VARIANT/$VARIANT_COUNT selected for this run"
echo " $VARIANT_SUMMARY"
echo "============================================================"
echo

echo "Installing Gateway API CRDs (v1.1.0)..."
kubectl apply -k "github.com/kubernetes-sigs/gateway-api/config/crd?ref=v1.1.0" >/dev/null
kubectl wait --for=condition=Established --timeout=60s \
  crd/gatewayclasses.gateway.networking.k8s.io \
  crd/gateways.gateway.networking.k8s.io \
  crd/httproutes.gateway.networking.k8s.io >/dev/null

# Start from a clean slate: remove every preset's resources so switching
# variants cannot leave a stale Ingress, Gateway, or GatewayClass behind.
echo "Removing resources from earlier attempts or variants..."
for ((v = 1; v <= VARIANT_COUNT; v++)); do
  variant_config "$v"
  kubectl delete httproute "$HTTPROUTE" -n "$NS" --ignore-not-found --wait=true --timeout=30s >/dev/null 2>&1 || true
  kubectl delete gateway "$GATEWAY" -n "$NS" --ignore-not-found --wait=true --timeout=30s >/dev/null 2>&1 || true
  kubectl delete ingress "$INGRESS" -n "$NS" --ignore-not-found --wait=true --timeout=30s >/dev/null 2>&1 || true
  kubectl delete secret "$TLS_SECRET" -n "$NS" --ignore-not-found --wait=true --timeout=30s >/dev/null 2>&1 || true
  kubectl delete service "$SERVICE" -n "$NS" --ignore-not-found --wait=true --timeout=30s >/dev/null 2>&1 || true
  kubectl delete deployment "$DEPLOYMENT" -n "$NS" --ignore-not-found --wait=true --timeout=60s >/dev/null 2>&1 || true
  kubectl delete gatewayclass "$GATEWAY_CLASS" --ignore-not-found --wait=true --timeout=30s >/dev/null 2>&1 || true
done
variant_config "$VARIANT"

rm -f "$HOME/gw.yaml" "$HOME/http.yaml"

echo "Creating deployment: $DEPLOYMENT in namespace '$NS'"
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

echo "Creating service: $SERVICE on port $SERVICE_PORT"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: $SERVICE
  namespace: $NS
spec:
  selector:
    app: $APP_LABEL
  ports:
  - name: http
    port: $SERVICE_PORT
    targetPort: $TARGET_PORT
EOF

echo "Creating TLS certificate secret: $TLS_SECRET"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "$TMP_DIR/tls.key" -out "$TMP_DIR/tls.crt" \
  -subj "/CN=$HOST/O=$APP_LABEL" >/dev/null 2>&1
kubectl create secret tls "$TLS_SECRET" -n "$NS" \
  --cert="$TMP_DIR/tls.crt" --key="$TMP_DIR/tls.key" \
  --dry-run=client -o yaml | kubectl apply -n "$NS" -f - >/dev/null

echo "Creating ingress: $INGRESS for host $HOST"
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: $INGRESS
  namespace: $NS
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  tls:
  - hosts:
    - $HOST
    secretName: $TLS_SECRET
  rules:
  - host: $HOST
    http:
      paths:
      - path: $PATH_VALUE
        pathType: Prefix
        backend:
          service:
            name: $SERVICE
            port:
              number: $SERVICE_PORT
EOF

echo "Creating GatewayClass: $GATEWAY_CLASS"
cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: $GATEWAY_CLASS
spec:
  controllerName: $CLASS_CONTROLLER
EOF

echo
echo "[OK] Question 11 setup complete."
echo "   - Namespace: $NS"
echo "   - Deployment: $DEPLOYMENT"
echo "   - Service: $SERVICE (port $SERVICE_PORT)"
echo "   - Ingress: $INGRESS (host $HOST, TLS secret $TLS_SECRET)"
echo "   - GatewayClass: $GATEWAY_CLASS"
echo

variant_question "$VARIANT"
