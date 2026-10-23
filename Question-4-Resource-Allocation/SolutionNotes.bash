# Solution Notes for Question 4 - Resource Allocation
#
# Reviewer note: this lab was adapted from the original Question 4 into three
# randomized variants and the question wording was rewritten to match the
# original. It may be worthwhile to compare the current wording against the
# original question and confirm the intent, scope, and difficulty still match.
#
# LabSetUp.bash prints the namespace, deployment, replica count, reserved
# overhead percentage, and schedulable node for this run. Substitute those
# values in the commands below.

# Step 1: inspect the node's allocatable resources
kubectl describe node "<NODE>"
# Allocatable:
#   cpu:    <CPU>
#   memory: <MEMORY>

# Step 2: calculate the per-pod share
# cpu_share_m  = floor(allocatable_cpu_m  * (100 - <OVERHEAD_PCT>) / 100 / <REPLICAS>)
# mem_share_mi = floor(allocatable_mem_mi * (100 - <OVERHEAD_PCT>) / 100 / <REPLICAS>)
# Round each result down to the nearest 10m CPU and 10Mi memory.
#
# Init containers do not run at the same time as the main container. The pod's
# effective request is max(init request, sum of main requests), so giving every
# container the full per-pod share uses exactly that share. Do not divide the
# per-pod share by the number of containers again.

# Step 3: pause the workload and edit the deployment
kubectl scale deployment "<DEPLOY>" -n "<NAMESPACE>" --replicas=0
kubectl edit deployment "<DEPLOY>" -n "<NAMESPACE>"
# Add the same resources block to the init container and the main container:
#   resources:
#     requests:
#       cpu: "<CPU_SHARE>m"
#       memory: "<MEM_SHARE>Mi"
#     limits:
#       cpu: "<CPU_SHARE>m"
#       memory: "<MEM_SHARE>Mi"

# Step 4: resume the deployment and verify
kubectl scale deployment "<DEPLOY>" -n "<NAMESPACE>" --replicas="<REPLICAS>"
kubectl rollout status "deployment/<DEPLOY>" -n "<NAMESPACE>" --timeout=180s
kubectl get pods -n "<NAMESPACE>" -l "app=<DEPLOY>"
kubectl describe node "<NODE>" | grep -A10 'Allocated resources'
