#!/bin/bash
# Validation script for Question 4 - Resource Allocation
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../scripts/lib/variant.sh
source "$REPO_ROOT/scripts/lib/variant.sh"
# shellcheck source=variants.bash
source "$SCRIPT_DIR/variants.bash"

VARIANT="$(cka_variant_read "$SCRIPT_DIR" "$VARIANT_COUNT")" || exit 1
variant_config "$VARIANT" || exit 1
variant_resource_targets || exit 1

PASS=0
FAIL=0
TOTAL=0

check() {
  local description="$1"
  shift
  TOTAL=$((TOTAL + 1))
  if "$@" >/dev/null 2>&1; then
    echo "  PASS: $description"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $description"
    FAIL=$((FAIL + 1))
  fi
}

container_field() {
  local kind="$1"
  local name="$2"
  local field="$3"
  kubectl get deployment "$DEPLOY" -n "$NS" \
    -o jsonpath="{.spec.template.spec.${kind}[?(@.name==\"$name\")].${field}}" 2>/dev/null
}

deployment_replicas_match() {
  [[ "$(kubectl get deployment "$DEPLOY" -n "$NS" -o jsonpath='{.spec.replicas}' 2>/dev/null)" == "$REPLICAS" ]]
}

deployment_status_replicas_match() {
  [[ "$(kubectl get deployment "$DEPLOY" -n "$NS" -o jsonpath='{.status.replicas}' 2>/dev/null)" == "$REPLICAS" ]]
}

deployment_updated_replicas_match() {
  [[ "$(kubectl get deployment "$DEPLOY" -n "$NS" -o jsonpath='{.status.updatedReplicas}' 2>/dev/null)" == "$REPLICAS" ]]
}

deployment_available_replicas_match() {
  [[ "$(kubectl get deployment "$DEPLOY" -n "$NS" -o jsonpath='{.status.availableReplicas}' 2>/dev/null)" == "$REPLICAS" ]]
}

pod_count_matches() {
  local count
  count="$(kubectl get pods -n "$NS" -l "app=$APP_LABEL" --no-headers 2>/dev/null | wc -l)"
  [[ "$count" -eq "$REPLICAS" ]]
}

all_pods_running() {
  local count
  count="$(kubectl get pods -n "$NS" -l "app=$APP_LABEL" \
    --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)"
  [[ "$count" -eq "$REPLICAS" ]]
}

no_pending_pods() {
  local count
  count="$(kubectl get pods -n "$NS" -l "app=$APP_LABEL" \
    --field-selector=status.phase=Pending --no-headers 2>/dev/null | wc -l)"
  [[ "$count" -eq 0 ]]
}

main_container_names_match() {
  local names
  names="$(kubectl get deployment "$DEPLOY" -n "$NS" \
    -o jsonpath='{range .spec.template.spec.containers[*]}{.name}{"\n"}{end}' 2>/dev/null)"
  [[ "$names" == "$MAIN_CONTAINER" ]]
}

init_container_names_match() {
  local names
  names="$(kubectl get deployment "$DEPLOY" -n "$NS" \
    -o jsonpath='{range .spec.template.spec.initContainers[*]}{.name}{"\n"}{end}' 2>/dev/null)"
  [[ "$names" == "$INIT_CONTAINER" ]]
}

container_resources_match() {
  local kind="$1"
  local name="$2"
  local cpu_req mem_req cpu_lim mem_lim

  cpu_req="$(container_field "$kind" "$name" 'resources.requests.cpu')"
  mem_req="$(container_field "$kind" "$name" 'resources.requests.memory')"
  cpu_lim="$(container_field "$kind" "$name" 'resources.limits.cpu')"
  mem_lim="$(container_field "$kind" "$name" 'resources.limits.memory')"

  [[ -n "$cpu_req" && -n "$mem_req" && -n "$cpu_lim" && -n "$mem_lim" ]] || return 1
  [[ "$(cpu_to_millicores "$cpu_req")" -eq "$TARGET_CPU_M" ]] || return 1
  [[ "$(memory_to_mi "$mem_req")" -eq "$TARGET_MEM_MI" ]] || return 1
  [[ "$(cpu_to_millicores "$cpu_lim")" -eq "$TARGET_CPU_M" ]] || return 1
  [[ "$(memory_to_mi "$mem_lim")" -eq "$TARGET_MEM_MI" ]] || return 1
}

resources_are_identical() {
  local main_cpu_req init_cpu_req main_mem_req init_mem_req
  local main_cpu_lim init_cpu_lim main_mem_lim init_mem_lim

  main_cpu_req="$(container_field containers "$MAIN_CONTAINER" 'resources.requests.cpu')"
  init_cpu_req="$(container_field initContainers "$INIT_CONTAINER" 'resources.requests.cpu')"
  main_mem_req="$(container_field containers "$MAIN_CONTAINER" 'resources.requests.memory')"
  init_mem_req="$(container_field initContainers "$INIT_CONTAINER" 'resources.requests.memory')"
  main_cpu_lim="$(container_field containers "$MAIN_CONTAINER" 'resources.limits.cpu')"
  init_cpu_lim="$(container_field initContainers "$INIT_CONTAINER" 'resources.limits.cpu')"
  main_mem_lim="$(container_field containers "$MAIN_CONTAINER" 'resources.limits.memory')"
  init_mem_lim="$(container_field initContainers "$INIT_CONTAINER" 'resources.limits.memory')"

  [[ -n "$main_cpu_req" && -n "$init_cpu_req" ]] || return 1
  [[ "$(cpu_to_millicores "$main_cpu_req")" -eq "$(cpu_to_millicores "$init_cpu_req")" ]] || return 1
  [[ "$(memory_to_mi "$main_mem_req")" -eq "$(memory_to_mi "$init_mem_req")" ]] || return 1
  [[ "$(cpu_to_millicores "$main_cpu_lim")" -eq "$(cpu_to_millicores "$init_cpu_lim")" ]] || return 1
  [[ "$(memory_to_mi "$main_mem_lim")" -eq "$(memory_to_mi "$init_mem_lim")" ]]
}

echo "=================================================="
echo " Validating Question 4: Resource Allocation"
echo " Variant: $VARIANT/$VARIANT_COUNT"
echo " Expected: namespace=$NS, deployment=$DEPLOY, replicas=$REPLICAS"
echo "           requests=limits=${TARGET_CPU_M}m CPU / ${TARGET_MEM_MI}Mi memory"
echo " Node: $TARGET_NODE (allocatable ${NODE_CPU_M}m CPU / ${NODE_MEM_MI}Mi memory,"
echo "       ${OVERHEAD_PCT}% reserved for system overhead)"
echo "=================================================="

check "Namespace '$NS' exists" \
  kubectl get namespace "$NS"
check "Deployment '$DEPLOY' exists in namespace '$NS'" \
  kubectl get deployment "$DEPLOY" -n "$NS"
check "Deployment has exactly $REPLICAS replicas" \
  deployment_replicas_match
check "Deployment status reports $REPLICAS replicas" \
  deployment_status_replicas_match
check "Deployment has $REPLICAS updated replicas" \
  deployment_updated_replicas_match
check "Deployment has $REPLICAS available replicas" \
  deployment_available_replicas_match
check "Exactly $REPLICAS pods exist for app=$APP_LABEL" \
  pod_count_matches
check "All $REPLICAS pods are Running" \
  all_pods_running
check "No pods are Pending" \
  no_pending_pods
check "Exactly one main container named '$MAIN_CONTAINER'" \
  main_container_names_match
check "Exactly one init container named '$INIT_CONTAINER'" \
  init_container_names_match
check "Main container requests/limits are ${TARGET_CPU_M}m CPU / ${TARGET_MEM_MI}Mi memory" \
  container_resources_match containers "$MAIN_CONTAINER"
check "Init container requests/limits are ${TARGET_CPU_M}m CPU / ${TARGET_MEM_MI}Mi memory" \
  container_resources_match initContainers "$INIT_CONTAINER"
check "Init and main containers use identical resources" \
  resources_are_identical

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
if (( FAIL == 0 )); then
  echo "All checks passed!"
  exit 0
else
  echo "Some checks failed."
  exit 1
fi
