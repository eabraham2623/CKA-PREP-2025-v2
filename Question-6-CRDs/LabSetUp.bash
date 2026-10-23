#!/bin/bash
# LabSetUp.bash for Question 6 - CRDs (cert-manager)
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
echo " Question 6: CRDs - cert-manager"
echo " Variant $VARIANT/$VARIANT_COUNT selected for this run"
echo " $VARIANT_SUMMARY"
echo "============================================================"
echo

# Remove answers from every preset so switching variants cannot leave stale
# output behind.
echo "Removing previous answer files..."
for ((v = 1; v <= VARIANT_COUNT; v++)); do
  variant_config "$v"
  rm -f "$FIELD_FILE"
done
rm -f "$RESOURCES_FILE"
variant_config "$VARIANT"

echo "Creating namespace: $NS"
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

echo "Applying cert-manager $CM_VERSION CRDs..."
kubectl apply -f "$CRD_URL"

echo "Waiting for cert-manager CRDs to be established..."
for crd in "${CERT_MANAGER_CRDS[@]}"; do
  kubectl wait --for=condition=Established "crd/$crd" --timeout=120s >/dev/null
done

echo "Creating minimal cert-manager Deployment..."
kubectl apply -n "$NS" -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $DEPLOYMENT
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $DEPLOYMENT
  template:
    metadata:
      labels:
        app: $DEPLOYMENT
    spec:
      containers:
      - name: $DEPLOYMENT
        image: quay.io/jetstack/cert-manager-controller:$CM_VERSION
        args: ["--v=2"]
EOF

echo
echo "[OK] Question 6 setup complete."
echo "   - Namespace: $NS"
echo "   - cert-manager version: $CM_VERSION"
echo "   - Field to document: $EXPLAIN_TARGET"
echo

variant_question "$VARIANT"
