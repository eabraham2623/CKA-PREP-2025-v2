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
echo " Question 1: MariaDB Persistent Volume"
echo " Variant $VARIANT/$VARIANT_COUNT selected for this run"
echo " $VARIANT_SUMMARY"
echo "============================================================"
echo

echo "Creating namespace '$NS'..."
kubectl create ns "$NS" --dry-run=client -o yaml | kubectl apply -f -

# Query for default storage class to ensure PV uses correct class for binding
default_sc=$(kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')
if [ -z "$default_sc" ]; then
  default_sc="standard"
  echo "No default StorageClass detected, using 'standard' as fallback."
else
  echo "Default StorageClass detected: $default_sc"
fi

echo "Creating PersistentVolume '$PV'..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: $PV
  labels:
    app: $DEPLOY
spec:
  capacity:
    storage: $SIZE
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: $default_sc  # Use default or fallback storage class so PVC without storageClassName binds
  hostPath:
    path: $HOSTPATH
EOF

echo "Creating initial PVC '$PVC'..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: $PVC
  namespace: $NS
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: $SIZE
EOF

echo "Creating initial MariaDB Deployment '$DEPLOY'..."
cat <<EOF > "$HOME/mariadb-deploy.yaml"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $DEPLOY
  namespace: $NS
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $DEPLOY
  template:
    metadata:
      labels:
        app: $DEPLOY
    spec:
      containers:
      - name: mariadb
        image: $IMAGE
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: $ROOT_PASSWORD
        volumeMounts:
        - name: mariadb-storage
          mountPath: /var/lib/mysql
      volumes:
      - name: mariadb-storage
        persistentVolumeClaim:
          claimName: $PVC
EOF

kubectl apply -f "$HOME/mariadb-deploy.yaml"

echo "Waiting for MariaDB pod to start..."
kubectl wait --for=condition=Available "deployment/$DEPLOY" -n "$NS" --timeout=60s || true

echo "Simulating accidental deletion of Deployment and PVC..."
kubectl delete deployment "$DEPLOY" -n "$NS" --ignore-not-found
kubectl delete pvc "$PVC" -n "$NS" --ignore-not-found

echo "Resetting PV for reuse (clearing any stale claimRef)..."
claim_ref=$(kubectl get pv "$PV" -o jsonpath='{.spec.claimRef.name}' 2>/dev/null || true)
if [ -n "$claim_ref" ]; then
  kubectl patch pv "$PV" --type=json -p '[{"op":"remove","path":"/spec/claimRef"}]'
fi

# Refresh the deployment manifest for practice: claimName intentionally left blank
cat <<EOF > "$HOME/mariadb-deploy.yaml"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $DEPLOY
  namespace: $NS
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $DEPLOY
  template:
    metadata:
      labels:
        app: $DEPLOY
    spec:
      containers:
      - name: mariadb
        image: $IMAGE
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: $ROOT_PASSWORD
        volumeMounts:
        - name: mariadb-storage
          mountPath: /var/lib/mysql
      volumes:
      - name: mariadb-storage
        persistentVolumeClaim:
          claimName: ""
EOF

echo "[OK] Lab setup complete!"
echo "   - PV '$PV' retained and ready for reuse"
echo "   - Namespace: $NS"
echo "   - Manifest: $HOME/mariadb-deploy.yaml"
echo

variant_question "$VARIANT"
