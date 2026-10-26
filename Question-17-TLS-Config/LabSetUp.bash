#!/bin/bash
# LabSetUp.bash for Question 17 - NGINX TLS Config
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
echo " Question 17: NGINX TLS Config"
echo " Variant $VARIANT/$VARIANT_COUNT selected for this run"
echo " $VARIANT_SUMMARY"
echo "============================================================"
echo

# Remove any /etc/hosts entry left by a previous attempt. The learner must add
# the current service ClusterIP as part of the task.
remove_hosts_entry() {
  local sed_cmd=(sed -E -i "/[[:space:]]${TLS_HOSTNAME}([[:space:]]|$)/d" /etc/hosts)
  if [[ -w /etc/hosts ]]; then
    "${sed_cmd[@]}"
  else
    sudo "${sed_cmd[@]}"
  fi
}

echo "Preparing namespace: $NS"
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

for _ in $(seq 1 30); do
  [[ "$(kubectl get namespace "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" == "Active" ]] && break
  sleep 1
done
if [[ "$(kubectl get namespace "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" != "Active" ]]; then
  echo "Error: namespace '$NS' did not become Active" >&2
  exit 1
fi

# Record the selected variant in the namespace. Validation compares this marker
# with the state file so a tampered state file cannot silently validate against
# the other TLS direction, whose initial and required states overlap.
kubectl annotate namespace "$NS" "cka.question/variant=$VARIANT" --overwrite >/dev/null

echo "Removing resources from earlier attempts or variants..."
kubectl delete deployment "$DEPLOYMENT" -n "$NS" --ignore-not-found --cascade=foreground --wait=true >/dev/null 2>&1 || true
kubectl delete service "$SERVICE" -n "$NS" --ignore-not-found --wait=true >/dev/null 2>&1 || true
kubectl delete configmap "$CONFIGMAP" -n "$NS" --ignore-not-found >/dev/null 2>&1 || true
kubectl delete secret "$SECRET" -n "$NS" --ignore-not-found >/dev/null 2>&1 || true

if ! remove_hosts_entry; then
  echo "Warning: could not remove the old /etc/hosts entry for $TLS_HOSTNAME" >&2
fi

# Generate the self-signed certificate in a private temporary directory so no
# tls.key/tls.crt artifacts are left in the caller's working directory.
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "$TMP_DIR/tls.key" -out "$TMP_DIR/tls.crt" \
  -subj "/CN=$TLS_HOSTNAME" >/dev/null 2>&1

echo "Creating TLS secret: $SECRET"
kubectl create secret tls "$SECRET" -n "$NS" \
  --cert="$TMP_DIR/tls.crt" --key="$TMP_DIR/tls.key" >/dev/null

echo "Creating ConfigMap: $CONFIGMAP (initial protocols: $INITIAL_PROTOCOLS, immutable: $INITIAL_IMMUTABLE)"
cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: v1
kind: ConfigMap
metadata:
  name: $CONFIGMAP
  namespace: $NS
immutable: $INITIAL_IMMUTABLE
data:
  nginx.conf: |
    events {}
    http {
      server {
        listen 443 ssl;
        ssl_certificate $TLS_MOUNT/tls.crt;
        ssl_certificate_key $TLS_MOUNT/tls.key;
        ssl_protocols $INITIAL_PROTOCOLS;
        location / {
          return 200 "Hello TLS\n";
        }
      }
    }
EOF

echo "Creating deployment: $DEPLOYMENT"
cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $DEPLOYMENT
  namespace: $NS
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
      - name: nginx
        image: $IMAGE
        volumeMounts:
        - name: config
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf
        - name: tls
          mountPath: $TLS_MOUNT
      volumes:
      - name: config
        configMap:
          name: $CONFIGMAP
      - name: tls
        secret:
          secretName: $SECRET
EOF

echo "Creating service: $SERVICE"
kubectl expose deployment "$DEPLOYMENT" -n "$NS" \
  --port=443 --target-port=443 --name="$SERVICE" >/dev/null

echo "Waiting for the deployment to become ready..."
kubectl rollout status deployment/"$DEPLOYMENT" -n "$NS" --timeout=240s
kubectl wait --for=condition=Ready pod -l app="$APP_LABEL" -n "$NS" --timeout=60s >/dev/null

echo
echo "[OK] Question 17 setup complete."
echo "   - Namespace: $NS"
echo "   - Deployment: $DEPLOYMENT"
echo "   - ConfigMap: $CONFIGMAP"
echo "   - Service: $SERVICE"
echo "   - Hostname: $TLS_HOSTNAME"
echo "   - Initial protocols: $INITIAL_PROTOCOLS"
echo "   - Required protocols: $REQUIRED_PROTOCOLS"
echo "   - ConfigMap immutable: $REQUIRED_IMMUTABLE"
echo

variant_question "$VARIANT"
