# Solution Notes for Question 14 - Storage Class
#
# LabSetUp.bash prints the StorageClass name and provisioner for this run.
# Substitute them for <SC_FROM_SETUP> and <PROVISIONER_FROM_SETUP> below.

# Create the StorageClass without making it default.
cat > "$HOME/sc.yaml" <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: <SC_FROM_SETUP>
  annotations:
    storageclass.kubernetes.io/is-default-class: "false"
provisioner: <PROVISIONER_FROM_SETUP>
volumeBindingMode: WaitForFirstConsumer
EOF
kubectl apply -f "$HOME/sc.yaml"
kubectl get sc

# Make the new class default and demote the existing default (local-path).
kubectl patch storageclass <SC_FROM_SETUP> -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
kubectl patch storageclass local-path -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
kubectl get sc

# The "(default)" marker must appear only next to <SC_FROM_SETUP>.
