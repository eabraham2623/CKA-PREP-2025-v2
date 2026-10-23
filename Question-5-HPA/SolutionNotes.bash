# Solution Notes for Question 5 - HPA
#
# LabSetUp.bash prints the namespace, deployment, HPA name, CPU target, replica
# bounds, and downscale stabilization window for this run. Substitute those
# values in the manifest below.

# Step 1: inspect the target deployment
kubectl get deployment "<DEPLOY>" -n "<NAMESPACE>"

# Step 2: create the HPA
cat <<'EOF' > ~/hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: <HPA>
  namespace: <NAMESPACE>
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: <DEPLOY>
  minReplicas: <MIN_REPLICAS>
  maxReplicas: <MAX_REPLICAS>
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: <CPU_TARGET>
  behavior:
    scaleDown:
      stabilizationWindowSeconds: <STABILIZATION>
EOF

# Step 3: apply and verify
kubectl apply -f ~/hpa.yaml
kubectl get hpa "<HPA>" -n "<NAMESPACE>"
