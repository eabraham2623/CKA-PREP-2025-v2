# Solution Notes for Question 10 - Taints & Tolerations
#
# LabSetUp.bash prints the exact taint key, value (if any), effect, node, and
# pod details selected for this run. Substitute those values below.
#
# The presets use:
#   - NoSchedule with a value  -> toleration operator Equal and the same value
#   - NoExecute with a value   -> toleration operator Equal and the same value
#   - NoSchedule without value -> toleration operator Exists and no value

# Step 1: taint node01. <TAINT_SPEC> is printed by setup, for example
# "PERMISSION=granted:NoSchedule" or "dedicated:NoSchedule".
kubectl taint nodes node01 <TAINT_SPEC>

# Step 2: pod that tolerates the taint
cat <<'EOF' > pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  containers:
  - name: nginx
    image: nginx
  tolerations:
  - key: <TAINT_KEY>
    operator: <EQUAL_OR_EXISTS>
    value: <TAINT_VALUE>   # remove this line when operator is Exists
    effect: <TAINT_EFFECT>
EOF
kubectl apply -f pod.yaml
kubectl get pods -o wide

# Negative test (optional) - a pod without the toleration cannot run on node01.
cat <<'EOF' > podfailure.yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-fail
spec:
  containers:
  - name: nginx
    image: nginx
EOF
kubectl apply -f podfailure.yaml
kubectl describe pod nginx-fail

# With a NoSchedule taint, nginx-fail stays Pending.
# With a NoExecute taint, a non-tolerating pod that was already on node01 is
# evicted after the taint is applied.
