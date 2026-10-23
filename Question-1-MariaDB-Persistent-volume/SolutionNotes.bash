# Solution Notes for Question 1 - MariaDB Persistent Volume
#
# LabSetUp.bash prints the namespace, PV, PVC, deployment, and storage size
# selected for this run. Substitute those values in the commands below.

# Step 1: create the PVC. There are 2 ways to do this. (PV is pre-reset by LabSetUp.bash)
cat <<'EOF' > pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: <PVC_NAME>
  namespace: <NAMESPACE>
spec:
  accessModes:
  - ReadWriteOnce
  volumeName: <PV_NAME>  # bind to the specific PV. Optional, but ensures we know which PV is used.
  resources:
    requests:
      storage: <STORAGE_SIZE>
  storageClassName: # Set this to the default storage class name. Check with "kubectl get storageclass".
                    # If you used volumeName above, storageClassName can be left blank and it will bind to the PV by name.
EOF
kubectl apply -f pvc.yaml
kubectl get pvc <PVC_NAME> -n <NAMESPACE>
kubectl get pv <PV_NAME>     # should show Bound to the PVC

# Step 2: ensure deployment uses the PVC
# Edit ~/mariadb-deploy.yaml and set the persistentVolumeClaim claimName to <PVC_NAME>.
# (LabSetUp.bash leaves claimName blank for practice)
kubectl apply -f ~/mariadb-deploy.yaml
kubectl get pods -n <NAMESPACE>
