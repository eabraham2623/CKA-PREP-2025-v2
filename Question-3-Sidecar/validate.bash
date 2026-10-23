#!/bin/bash
# Validation script for Question 3 - Sidecar Container
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../scripts/lib/variant.sh
source "$REPO_ROOT/scripts/lib/variant.sh"
# shellcheck source=variants.bash
source "$SCRIPT_DIR/variants.bash"

VARIANT="$(cka_variant_read "$SCRIPT_DIR" "$VARIANT_COUNT")" || exit 1
variant_config "$VARIANT" || exit 1

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

deployment_available() {
  local available
  available="$(kubectl get deployment "$DEPLOY" -n "$NS" -o jsonpath='{.status.availableReplicas}' 2>/dev/null)"
  [[ -n "$available" && "$available" -ge 1 ]]
}

sidecar_image_matches() {
  local image
  image="$(kubectl get deployment "$DEPLOY" -n "$NS" \
    -o jsonpath="{.spec.template.spec.containers[?(@.name==\"$SIDECAR_NAME\")].image}" 2>/dev/null)"
  if [[ -z "$image" ]]; then
    image="$(kubectl get deployment "$DEPLOY" -n "$NS" \
      -o jsonpath="{.spec.template.spec.initContainers[?(@.name==\"$SIDECAR_NAME\")].image}" 2>/dev/null)"
  fi
  [[ "$image" == "$SIDECAR_IMAGE" ]]
}

sidecar_command_matches() {
  local command
  command="$(kubectl get deployment "$DEPLOY" -n "$NS" \
    -o jsonpath="{.spec.template.spec.containers[?(@.name==\"$SIDECAR_NAME\")].command[*]}" 2>/dev/null)"
  command+="$(kubectl get deployment "$DEPLOY" -n "$NS" \
    -o jsonpath="{.spec.template.spec.containers[?(@.name==\"$SIDECAR_NAME\")].args[*]}" 2>/dev/null)"
  if [[ -z "$command" ]]; then
    command="$(kubectl get deployment "$DEPLOY" -n "$NS" \
      -o jsonpath="{.spec.template.spec.initContainers[?(@.name==\"$SIDECAR_NAME\")].command[*]}" 2>/dev/null)"
    command+="$(kubectl get deployment "$DEPLOY" -n "$NS" \
      -o jsonpath="{.spec.template.spec.initContainers[?(@.name==\"$SIDECAR_NAME\")].args[*]}" 2>/dev/null)"
  fi
  [[ "$command" == *"tail"* ]] || return 1
  [[ "$command" == *"-f"* || "$command" == *"-F"* ]] || return 1
  [[ "$command" == *"$LOG_FILE"* ]]
}

emptydir_volume_exists() {
  local volumes
  volumes="$(kubectl get deployment "$DEPLOY" -n "$NS" \
    -o jsonpath='{range .spec.template.spec.volumes[?(@.emptyDir)]}{.name}{"\n"}{end}' 2>/dev/null)"
  [[ -n "$volumes" ]]
}

main_mount_name() {
  kubectl get deployment "$DEPLOY" -n "$NS" \
    -o jsonpath="{.spec.template.spec.containers[?(@.name==\"$APP_CONTAINER\")].volumeMounts[?(@.mountPath==\"$MOUNT_PATH\")].name}" 2>/dev/null
}

sidecar_mount_name() {
  local name
  name="$(kubectl get deployment "$DEPLOY" -n "$NS" \
    -o jsonpath="{.spec.template.spec.containers[?(@.name==\"$SIDECAR_NAME\")].volumeMounts[?(@.mountPath==\"$MOUNT_PATH\")].name}" 2>/dev/null)"
  if [[ -z "$name" ]]; then
    name="$(kubectl get deployment "$DEPLOY" -n "$NS" \
      -o jsonpath="{.spec.template.spec.initContainers[?(@.name==\"$SIDECAR_NAME\")].volumeMounts[?(@.mountPath==\"$MOUNT_PATH\")].name}" 2>/dev/null)"
  fi
  printf '%s' "$name"
}

main_mount_matches() {
  [[ -n "$(main_mount_name)" ]]
}

sidecar_mount_matches() {
  [[ -n "$(sidecar_mount_name)" ]]
}

shared_volume_matches() {
  local main_mount sidecar_mount emptydir_volumes
  main_mount="$(main_mount_name)"
  sidecar_mount="$(sidecar_mount_name)"
  [[ -n "$main_mount" && "$main_mount" == "$sidecar_mount" ]] || return 1
  emptydir_volumes="$(kubectl get deployment "$DEPLOY" -n "$NS" \
    -o jsonpath='{range .spec.template.spec.volumes[?(@.emptyDir)]}{.name}{"\n"}{end}' 2>/dev/null)"
  grep -qxF "$main_mount" <<< "$emptydir_volumes"
}

pod_name() {
  local pod
  for pod in $(kubectl get pods -n "$NS" -l "app=$APP_LABEL" \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null); do
    if kubectl get pod "$pod" -n "$NS" \
      -o jsonpath='{.spec.containers[*].name}{" "}{.spec.initContainers[*].name}' 2>/dev/null \
      | grep -qw "$SIDECAR_NAME"; then
      printf '%s' "$pod"
      return 0
    fi
  done
  return 1
}

log_line_visible() {
  local container="$1"
  local pod i
  pod="$(pod_name)" || return 1
  for i in {1..12}; do
    if kubectl exec "$pod" -n "$NS" -c "$container" -- \
      grep -Fq "$LOG_MESSAGE" "$LOG_FILE" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

pod_is_running() {
  local pod
  pod="$(pod_name)" || return 1
  [[ "$(kubectl get pod "$pod" -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)" == "Running" ]]
}

echo "======================================"
echo " Validating Question 3: Sidecar"
echo " Variant: $VARIANT/$VARIANT_COUNT"
echo " Expected: namespace=$NS, deployment=$DEPLOY"
echo "           main container=$APP_CONTAINER"
echo "           log=$LOG_FILE, mount=$MOUNT_PATH"
echo "======================================"

# 1. Deployment exists in the variant's namespace
check "Deployment '$DEPLOY' exists in namespace '$NS'" \
  kubectl get deployment "$DEPLOY" -n "$NS"

# 2. Deployment is available
check "Deployment '$DEPLOY' has available replicas" \
  deployment_available

# 3. Sidecar container exists with the expected image
check "Sidecar '$SIDECAR_NAME' uses image '$SIDECAR_IMAGE'" \
  sidecar_image_matches

# 4. Sidecar runs tail -f or tail -F on the variant's log file
check "Sidecar runs tail on '$LOG_FILE'" \
  sidecar_command_matches

# 5. A shared emptyDir volume exists
check "Shared emptyDir volume configured" \
  emptydir_volume_exists

# 6. Volume is mounted at the expected path on the main container
check "Volume mounted at '$MOUNT_PATH' on main container '$APP_CONTAINER'" \
  main_mount_matches

# 7. Volume is mounted at the expected path on the sidecar
check "Volume mounted at '$MOUNT_PATH' on sidecar '$SIDECAR_NAME'" \
  sidecar_mount_matches

# 8. Both containers use the same emptyDir volume
check "Main and sidecar containers share the same emptyDir volume" \
  shared_volume_matches

# 9. Main container writes the expected log line
check "Main container wrote '$LOG_MESSAGE' to '$LOG_FILE'" \
  log_line_visible "$APP_CONTAINER"

# 10. Sidecar can read the same log line from the shared volume
check "Sidecar can read the shared log line" \
  log_line_visible "$SIDECAR_NAME"

# 11. Pod is Running
check "Pod with the sidecar is Running" \
  pod_is_running

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
if [[ $FAIL -eq 0 ]]; then
  echo "All checks passed!"
  exit 0
else
  echo "Some checks failed."
  exit 1
fi
