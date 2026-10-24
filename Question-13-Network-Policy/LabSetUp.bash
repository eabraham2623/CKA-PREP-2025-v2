#!/bin/bash
# LabSetUp.bash for Question 13 - Network Policy
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
echo " Question 13: Network Policy"
echo " Variant $VARIANT/$VARIANT_COUNT selected for this run"
echo " $VARIANT_SUMMARY"
echo "============================================================"
echo

write_allow_all() {
  local file="$1" name="$2"
  cat > "$file" <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: $name
  namespace: $NS_BACKEND
spec:
  podSelector: {}
  ingress:
  - {}
  policyTypes:
  - Ingress
EOF
}

write_too_open() {
  local file="$1" name="$2"
  cat > "$file" <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: $name
  namespace: $NS_BACKEND
spec:
  podSelector:
    matchLabels:
      $BACKEND_LABEL_KEY: $BACKEND_LABEL_VALUE
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: $NS_FRONTEND
    - ipBlock:
        cidr: $DECOY_CIDR
    ports:
    - protocol: TCP
      port: $POLICY_PORT
  policyTypes:
  - Ingress
EOF
}

write_correct() {
  local file="$1" name="$2"
  cat > "$file" <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: $name
  namespace: $NS_BACKEND
spec:
  podSelector:
    matchLabels:
      $BACKEND_LABEL_KEY: $BACKEND_LABEL_VALUE
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: $NS_FRONTEND
    - podSelector:
        matchLabels:
          $FRONTEND_LABEL_KEY: $FRONTEND_LABEL_VALUE
    ports:
    - protocol: TCP
      port: $POLICY_PORT
  policyTypes:
  - Ingress
EOF
}

write_candidate() {
  local file="$1" kind="$2" name="$3"
  case "$kind" in
    allow-all) write_allow_all "$file" "$name" ;;
    too-open) write_too_open "$file" "$name" ;;
    correct) write_correct "$file" "$name" ;;
    *)
      echo "Error: unknown candidate kind '$kind'" >&2
      return 1
      ;;
  esac
}

echo "Creating namespaces..."
kubectl create namespace "$NS_FRONTEND" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl create namespace "$NS_BACKEND" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

# Start from a clean slate: remove every preset's workloads and any applied
# policy so switching variants or retrying always starts unsolved.
echo "Removing resources from earlier attempts or variants..."
for ((v = 1; v <= VARIANT_COUNT; v++)); do
  variant_config "$v"
  kubectl delete deployment "$FRONTEND_DEPLOYMENT" -n "$NS_FRONTEND" --ignore-not-found --wait=true --timeout=60s >/dev/null 2>&1 || true
  kubectl delete deployment "$BACKEND_DEPLOYMENT" -n "$NS_BACKEND" --ignore-not-found --wait=true --timeout=60s >/dev/null 2>&1 || true
  kubectl delete service "$BACKEND_SERVICE" -n "$NS_BACKEND" --ignore-not-found --wait=true --timeout=30s >/dev/null 2>&1 || true
done
variant_config "$VARIANT"
kubectl delete networkpolicy --all -n "$NS_BACKEND" --ignore-not-found >/dev/null 2>&1 || true

echo "Deploying backend app: $BACKEND_DEPLOYMENT"
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $BACKEND_DEPLOYMENT
  namespace: $NS_BACKEND
spec:
  replicas: 1
  selector:
    matchLabels:
      $BACKEND_LABEL_KEY: $BACKEND_LABEL_VALUE
  template:
    metadata:
      labels:
        $BACKEND_LABEL_KEY: $BACKEND_LABEL_VALUE
    spec:
      containers:
      - name: backend
        image: $IMAGE_BACKEND
        ports:
        - containerPort: $BACKEND_PORT
EOF

echo "Exposing backend as ClusterIP service: $BACKEND_SERVICE"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: $BACKEND_SERVICE
  namespace: $NS_BACKEND
spec:
  selector:
    $BACKEND_LABEL_KEY: $BACKEND_LABEL_VALUE
  ports:
  - name: http
    port: $BACKEND_PORT
    targetPort: $BACKEND_PORT
EOF

echo "Deploying frontend app: $FRONTEND_DEPLOYMENT"
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $FRONTEND_DEPLOYMENT
  namespace: $NS_FRONTEND
spec:
  replicas: 1
  selector:
    matchLabels:
      $FRONTEND_LABEL_KEY: $FRONTEND_LABEL_VALUE
  template:
    metadata:
      labels:
        $FRONTEND_LABEL_KEY: $FRONTEND_LABEL_VALUE
    spec:
      containers:
      - name: frontend
        image: $IMAGE_FRONTEND
        command: ["sleep", "3600"]
EOF

echo "Creating NetworkPolicy files..."
WORKDIR="${WORKDIR:-$PWD/network-policies}"
mkdir -p "$WORKDIR"
rm -f "$WORKDIR/network-policy-1.yaml" "$WORKDIR/network-policy-2.yaml" "$WORKDIR/network-policy-3.yaml"
write_candidate "$WORKDIR/network-policy-1.yaml" "$FILE1_KIND" "$FILE1_NAME"
write_candidate "$WORKDIR/network-policy-2.yaml" "$FILE2_KIND" "$FILE2_NAME"
write_candidate "$WORKDIR/network-policy-3.yaml" "$FILE3_KIND" "$FILE3_NAME"

echo
echo "[OK] Question 13 setup complete."
echo "   - Namespaces: $NS_FRONTEND, $NS_BACKEND"
echo "   - Frontend Deployment: $FRONTEND_DEPLOYMENT ($FRONTEND_LABEL_KEY=$FRONTEND_LABEL_VALUE)"
echo "   - Backend Deployment: $BACKEND_DEPLOYMENT ($BACKEND_LABEL_KEY=$BACKEND_LABEL_VALUE)"
echo "   - Backend Service: $BACKEND_SERVICE (port $BACKEND_PORT)"
echo "   - Candidate policies: $WORKDIR/network-policy-{1,2,3}.yaml"
echo

variant_question "$VARIANT"
