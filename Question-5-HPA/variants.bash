#!/bin/bash
# Variant presets for Question 5 - HPA.
#
# variant_config is the single source of truth for every value that changes
# between presets. LabSetUp.bash and validate.bash both call it after reading
# the recorded variant.

VARIANT_COUNT=3

# Fixed values: keep the namespace, image, port, and resource requests/limits
# stable across presets so every variant has the same difficulty.
NS="autoscale"
IMAGE="httpd"
CONTAINER_PORT=80
CPU_REQUEST="100m"
CPU_LIMIT="200m"

variant_config() {
  local variant="${1:-}"

  case "$variant" in
    1)
      DEPLOY="apache-deployment"
      APP_LABEL="apache"
      CONTAINER="apache"
      HPA="apache-server"
      CPU_TARGET=50
      MIN_REPLICAS=1
      MAX_REPLICAS=4
      STABILIZATION=30
      ;;
    2)
      DEPLOY="nginx-deployment"
      APP_LABEL="nginx"
      CONTAINER="web"
      HPA="nginx-server"
      CPU_TARGET=60
      MIN_REPLICAS=2
      MAX_REPLICAS=5
      STABILIZATION=45
      ;;
    3)
      DEPLOY="web-deployment"
      APP_LABEL="web"
      CONTAINER="web"
      HPA="web-server"
      CPU_TARGET=70
      MIN_REPLICAS=1
      MAX_REPLICAS=6
      STABILIZATION=60
      ;;
    *)
      echo "Error: unknown variant '$variant' (expected 1..$VARIANT_COUNT)" >&2
      return 1
      ;;
  esac

  VARIANT_SUMMARY="namespace=$NS, deployment=$DEPLOY, HPA=$HPA, CPU target=${CPU_TARGET}%, replicas=${MIN_REPLICAS}-${MAX_REPLICAS}, downscale stabilization=${STABILIZATION}s"
}

# Print the full question for the currently configured variant. LabSetUp.bash
# calls this after variant_config so the learner sees the exact values for the
# run instead of a generic question with hard-coded names.
variant_question() {
  local variant="${1:-?}"

  cat <<EOF
============================================================
 Question 5: HPA - HorizontalPodAutoscaler (Variant $variant/$VARIANT_COUNT)
============================================================

Create a new HorizontalPodAutoscaler (HPA) named $HPA in the $NS namespace.

Task:
1. The HPA must target the existing deployment called $DEPLOY in the $NS namespace.
2. Set the HPA to target $CPU_TARGET% CPU usage per Pod.
3. Configure the HPA to have a minimum of $MIN_REPLICAS pod(s) and a maximum of $MAX_REPLICAS pods.
4. Set the downscale stabilization window to $STABILIZATION seconds.

Run details:
- Namespace: $NS
- Deployment: $DEPLOY
- HPA: $HPA
- CPU target: $CPU_TARGET%
- Replicas: $MIN_REPLICAS-$MAX_REPLICAS
- Downscale stabilization: $STABILIZATION seconds

Video Link - https://youtu.be/YGkARVFKtmM

Documentation Reference
Tip: Navigate the documentation manually to build familiarity with its structure
(hpa) Tasks -> Run Application -> HorizontalPodAutoscaling Walkthrough
https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/
(downscale) Concepts -> Workloads -> Horizontal Pod Autoscaling
https://kubernetes.io/docs/concepts/workloads/autoscaling/horizontal-pod-autoscale/
============================================================
EOF
}
