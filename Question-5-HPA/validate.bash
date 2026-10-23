#!/bin/bash
# Validation script for Question 5 - HPA (HorizontalPodAutoscaler)
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

hpa_field() {
  kubectl get hpa "$HPA" -n "$NS" -o jsonpath="$1" 2>/dev/null
}

target_name_matches() {
  [[ "$(hpa_field '{.spec.scaleTargetRef.name}')" == "$DEPLOY" ]]
}

target_kind_matches() {
  [[ "$(hpa_field '{.spec.scaleTargetRef.kind}')" == "Deployment" ]]
}

cpu_target_matches() {
  local metric_type metric_name utilization
  metric_type="$(hpa_field '{.spec.metrics[0].type}')"
  metric_name="$(hpa_field '{.spec.metrics[0].resource.name}')"
  utilization="$(hpa_field '{.spec.metrics[0].resource.target.averageUtilization}')"
  [[ "$metric_type" == "Resource" && "$metric_name" == "cpu" && "$utilization" == "$CPU_TARGET" ]]
}

min_replicas_match() {
  [[ "$(hpa_field '{.spec.minReplicas}')" == "$MIN_REPLICAS" ]]
}

max_replicas_match() {
  [[ "$(hpa_field '{.spec.maxReplicas}')" == "$MAX_REPLICAS" ]]
}

stabilization_matches() {
  [[ "$(hpa_field '{.spec.behavior.scaleDown.stabilizationWindowSeconds}')" == "$STABILIZATION" ]]
}

echo "=================================================="
echo " Validating Question 5: HPA"
echo " Variant: $VARIANT/$VARIANT_COUNT"
echo " Expected: namespace=$NS, deployment=$DEPLOY, HPA=$HPA"
echo "           CPU target=${CPU_TARGET}%, replicas=$MIN_REPLICAS-$MAX_REPLICAS,"
echo "           downscale stabilization=${STABILIZATION}s"
echo "=================================================="

check "HPA '$HPA' exists in namespace '$NS'" \
  kubectl get hpa "$HPA" -n "$NS"

check "HPA targets deployment '$DEPLOY'" \
  target_name_matches

check "HPA scaleTargetRef kind is Deployment" \
  target_kind_matches

check "HPA CPU target is ${CPU_TARGET}% utilization" \
  cpu_target_matches

check "HPA minReplicas is $MIN_REPLICAS" \
  min_replicas_match

check "HPA maxReplicas is $MAX_REPLICAS" \
  max_replicas_match

check "Downscale stabilizationWindowSeconds is $STABILIZATION" \
  stabilization_matches

check "Deployment '$DEPLOY' exists in namespace '$NS'" \
  kubectl get deployment "$DEPLOY" -n "$NS"

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
if (( FAIL == 0 )); then
  echo "All checks passed!"
  exit 0
else
  echo "Some checks failed."
  exit 1
fi
