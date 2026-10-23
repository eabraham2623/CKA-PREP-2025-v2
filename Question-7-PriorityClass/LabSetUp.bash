#!/bin/bash
# LabSetUp.bash for Question 7 - PriorityClass
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
echo " Question 7: PriorityClass"
echo " Variant $VARIANT/$VARIANT_COUNT selected for this run"
echo " $VARIANT_SUMMARY"
echo "============================================================"
echo

# Delete the Deployment so a priorityClassName set by an earlier attempt cannot
# survive kubectl apply. Delete every preset's PriorityClasses so a class left
# by another variant cannot become the highest user-defined class.
echo "Removing resources from earlier attempts or variants..."
kubectl delete deployment "$DEPLOYMENT" -n "$NS" --ignore-not-found --wait=true >/dev/null 2>&1 || true
for ((v = 1; v <= VARIANT_COUNT; v++)); do
  variant_config "$v"
  kubectl delete priorityclass "$EXISTING_PC" "$TARGET_PC" --ignore-not-found >/dev/null 2>&1 || true
done
variant_config "$VARIANT"

echo "Creating namespace: $NS"
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

echo "Creating user-defined PriorityClass: $EXISTING_PC"
cat <<EOF | kubectl apply -f -
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: $EXISTING_PC
value: $EXISTING_VALUE
globalDefault: false
description: "Highest user-defined priority class"
EOF

echo "Creating deployment: $DEPLOYMENT in '$NS' namespace"
cat <<EOF | kubectl apply -f -
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
      - name: busybox
        image: $IMAGE
        command: ["sh", "-c", "while true; do echo 'logging...'; sleep 5; done"]
EOF

echo
echo "[OK] Question 7 setup complete."
echo "   - Namespace: $NS"
echo "   - Deployment: $DEPLOYMENT"
echo "   - Existing user-defined PriorityClass: $EXISTING_PC"
echo "   - PriorityClass to create: $TARGET_PC"
echo

variant_question "$VARIANT"
