# Solution Notes for Question 13 - Network Policy
#
# LabSetUp.bash prints the exact deployments, pod labels, and backend service
# selected for this run. Substitute those values below.

# Step 1: Inspect the provided candidates and the running workloads
WORKDIR="${WORKDIR:-$PWD/network-policies}"
for f in "$WORKDIR"/network-policy-*.yaml; do
  echo "=== $f ==="
  cat "$f"
done
kubectl get deployment -n frontend --show-labels
kubectl get deployment -n backend --show-labels
kubectl get service -n backend

# Step 2: Choose the least permissive policy that still allows the frontend
# to reach the backend. It must:
# - select the backend pods
# - include a frontend namespaceSelector and a frontend podSelector
# - allow only TCP port 80
# - not allow any ipBlock/CIDR source
# Apply only that candidate file:
kubectl apply -f "$WORKDIR/<CORRECT_FILE>"

# Step 3: Verify the applied policy and connectivity
kubectl get networkpolicy -n backend -o yaml
kubectl exec -n frontend deployment/<FRONTEND_DEPLOYMENT> -- \
  curl -v --connect-timeout 5 <BACKEND_SERVICE>.backend.svc.cluster.local:80
