#!/bin/bash
# Variant presets for Question 4 - Resource Allocation.
#
# variant_config is the single source of truth for every value that changes
# between presets. LabSetUp.bash and validate.bash both call it after reading
# the recorded variant. The required per-pod resource values are not
# hard-coded: they are derived from the live allocatable resources of the
# smallest Ready, schedulable node.

VARIANT_COUNT=3

# Fixed values: keep the task, images, container count, and namespace stable
# across presets so every variant has the same difficulty.
NS="wordpress"
MAIN_CONTAINER="wordpress"
INIT_CONTAINER="init-setup"
MAIN_IMAGE="wordpress:6.2-apache"
INIT_IMAGE="busybox"
CONTAINER_PORT=80
INIT_SLEEP=5

variant_config() {
  local variant="${1:-}"

  case "$variant" in
    1)
      DEPLOY="wordpress"
      REPLICAS=3
      OVERHEAD_PCT=20
      ;;
    2)
      DEPLOY="wordpress-staging"
      REPLICAS=2
      OVERHEAD_PCT=25
      ;;
    3)
      DEPLOY="wordpress-dev"
      REPLICAS=4
      OVERHEAD_PCT=30
      ;;
    *)
      echo "Error: unknown variant '$variant' (expected 1..$VARIANT_COUNT)" >&2
      return 1
      ;;
  esac

  APP_LABEL="$DEPLOY"
  VARIANT_SUMMARY="namespace=$NS, deployment=$DEPLOY, replicas=$REPLICAS, reserved overhead=${OVERHEAD_PCT}%"
}

# Convert a Kubernetes CPU quantity to millicores.
cpu_to_millicores() {
  local value="$1"
  awk -v v="$value" 'BEGIN {
    if (v == "") { print 0; exit }
    if (v ~ /m$/) { sub(/m$/, "", v); printf "%d\n", v }
    else { printf "%d\n", v * 1000 }
  }'
}

# Convert a Kubernetes memory quantity to Mi.
memory_to_mi() {
  local value="$1"
  awk -v v="$value" 'BEGIN {
    if (v == "") { print 0; exit }
    if (v ~ /Ki$/) { sub(/Ki$/, "", v); printf "%d\n", v / 1024 }
    else if (v ~ /Mi$/) { sub(/Mi$/, "", v); printf "%d\n", v }
    else if (v ~ /Gi$/) { sub(/Gi$/, "", v); printf "%d\n", v * 1024 }
    else if (v ~ /Ti$/) { sub(/Ti$/, "", v); printf "%d\n", v * 1024 * 1024 }
    else if (v ~ /K$/) { sub(/K$/, "", v); printf "%d\n", v * 1000 / 1024 / 1024 }
    else if (v ~ /M$/) { sub(/M$/, "", v); printf "%d\n", v * 1000 * 1000 / 1024 / 1024 }
    else if (v ~ /G$/) { sub(/G$/, "", v); printf "%d\n", v * 1000 * 1000 * 1000 / 1024 / 1024 / 1024 }
    else { printf "%d\n", v / 1024 / 1024 }
  }'
}

# Select the Ready, schedulable node with the smallest allocatable CPU and
# memory. Sets TARGET_NODE, NODE_CPU_M, NODE_MEM_MI, TARGET_CPU_M, and
# TARGET_MEM_MI for the currently configured variant.
variant_resource_targets() {
  local node ready unschedulable taint cpu mem cpu_m mem_mi
  local best_node="" best_cpu="" best_mem=""

  for node in $(kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null); do
    ready="$(kubectl get node "$node" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)"
    [[ "$ready" == "True" ]] || continue

    unschedulable="$(kubectl get node "$node" -o jsonpath='{.spec.unschedulable}' 2>/dev/null)"
    [[ "$unschedulable" != "true" ]] || continue

    taint="$(kubectl get node "$node" -o jsonpath='{range .spec.taints[?(@.effect=="NoSchedule")]}{.key}{"\n"}{end}' 2>/dev/null)"
    [[ -z "$taint" ]] || continue
    taint="$(kubectl get node "$node" -o jsonpath='{range .spec.taints[?(@.effect=="NoExecute")]}{.key}{"\n"}{end}' 2>/dev/null)"
    [[ -z "$taint" ]] || continue

    cpu="$(kubectl get node "$node" -o jsonpath='{.status.allocatable.cpu}' 2>/dev/null)"
    mem="$(kubectl get node "$node" -o jsonpath='{.status.allocatable.memory}' 2>/dev/null)"
    cpu_m="$(cpu_to_millicores "$cpu")"
    mem_mi="$(memory_to_mi "$mem")"

    if [[ -z "$best_node" ]] || (( cpu_m < best_cpu )) || { (( cpu_m == best_cpu )) && (( mem_mi < best_mem )); }; then
      best_node="$node"
      best_cpu="$cpu_m"
      best_mem="$mem_mi"
    fi
  done

  if [[ -z "$best_node" ]]; then
    echo "Error: no Ready, schedulable node found" >&2
    return 1
  fi

  TARGET_NODE="$best_node"
  NODE_CPU_M="$best_cpu"
  NODE_MEM_MI="$best_mem"

  TARGET_CPU_M=$(( NODE_CPU_M * (100 - OVERHEAD_PCT) / 100 / REPLICAS ))
  TARGET_MEM_MI=$(( NODE_MEM_MI * (100 - OVERHEAD_PCT) / 100 / REPLICAS ))
  TARGET_CPU_M=$(( TARGET_CPU_M / 10 * 10 ))
  TARGET_MEM_MI=$(( TARGET_MEM_MI / 10 * 10 ))

  if (( TARGET_CPU_M < 10 || TARGET_MEM_MI < 10 )); then
    echo "Error: node $TARGET_NODE is too small for $REPLICAS replicas at ${OVERHEAD_PCT}% overhead" >&2
    return 1
  fi
}

# Print the full question for the currently configured variant. LabSetUp.bash
# calls this after variant_config and variant_resource_targets so the learner
# sees the exact values for the run instead of a generic question.
variant_question() {
  local variant="${1:-?}"

  if [[ -z "${TARGET_NODE:-}" ]]; then
    variant_resource_targets || return 1
  fi

  cat <<EOF
============================================================
 Question 4: Resource Allocation (Variant $variant/$VARIANT_COUNT)
============================================================

You are managing a WordPress application running in a Kubernetes cluster.
Your task is to adjust the Pod resource requests and limits to ensure stable
operation.

Tasks:
1. Scale down the $DEPLOY deployment to 0 replicas.
2. Edit the deployment and divide the node resource evenly across all $REPLICAS pods.
3. Assign fair and equal CPU and memory to each Pod.
4. Add sufficient overhead to avoid node instability.
Ensure both the init containers and the main containers use exactly the same
resource requests and limits.
After making the changes scale the deployment back to $REPLICAS replicas.

Run details:
- Namespace: $NS
- Deployment: $DEPLOY
- Replicas: $REPLICAS
- Node: $TARGET_NODE (allocatable CPU: ${NODE_CPU_M}m, memory: ${NODE_MEM_MI}Mi)
- Reserve ${OVERHEAD_PCT}% of the node's allocatable CPU and memory for
  system overhead.
- Round each per-pod share down to the nearest 10m CPU and 10Mi memory.
- Use the rounded values as both requests and limits.

Video link - https://youtu.be/ZqGDdETii8c

Documentation Reference
Tip: Navigate the documentation manually to build familiarity with its structure
Concepts -> Configuration -> Resource Management for Pods and Containers
https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/
============================================================
EOF
}
