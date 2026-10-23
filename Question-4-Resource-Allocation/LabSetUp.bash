#!/bin/bash
# LabSetUp.bash for Question 4 - Resource Allocation
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
variant_resource_targets || exit 1

echo "============================================================"
echo " Question 4: Resource Allocation"
echo " Variant $VARIANT/$VARIANT_COUNT selected for this run"
echo " $VARIANT_SUMMARY"
echo " Node budget: $TARGET_NODE (allocatable cpu=${NODE_CPU_M}m, memory=${NODE_MEM_MI}Mi)"
echo "============================================================"
echo

echo "Preparing namespace '$NS'..."
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

# Remove every preset's deployment so switching variants cannot exhaust the
# node with leftover resource requests from an earlier run.
echo "Resetting any previous Question 4 deployments..."
for ((v = 1; v <= VARIANT_COUNT; v++)); do
  variant_config "$v"
  kubectl delete deployment "$DEPLOY" -n "$NS" --ignore-not-found \
    --cascade=foreground --wait=true --timeout=90s >/dev/null
done
variant_config "$VARIANT"

echo "Creating deployment '$DEPLOY' with $REPLICAS replicas and no resources..."
kubectl apply -f - <<EOF
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
      initContainers:
      - name: $INIT_CONTAINER
        image: $INIT_IMAGE
        command: ["sh", "-c", "echo 'Preparing environment...' && sleep $INIT_SLEEP"]
      containers:
      - name: $MAIN_CONTAINER
        image: $MAIN_IMAGE
        ports:
        - containerPort: $CONTAINER_PORT
EOF

echo
echo "[OK] Lab setup complete!"
echo "   - Namespace: $NS"
echo "   - Deployment: $DEPLOY ($REPLICAS replicas)"
echo "   - The deployment has no resource requests or limits yet."
echo

variant_question "$VARIANT"
