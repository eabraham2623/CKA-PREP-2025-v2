#!/bin/bash
# Variant presets for Question 7 - PriorityClass.
#
# variant_config is the single source of truth for every value that changes
# between presets: the existing user-defined PriorityClass, its value, and the
# PriorityClass the learner must create. The namespace, Deployment, image, and
# required commands stay fixed so every preset has the same difficulty.

VARIANT_COUNT=3

# Fixed values shared by every preset.
NS="priority"
DEPLOYMENT="busybox-logger"
APP_LABEL="busybox-logger"
IMAGE="busybox"

variant_config() {
  local variant="${1:-}"

  case "$variant" in
    1)
      EXISTING_PC="user-critical"
      EXISTING_VALUE=1000
      TARGET_PC="high-priority"
      ;;
    2)
      EXISTING_PC="user-important"
      EXISTING_VALUE=5000
      TARGET_PC="elevated-priority"
      ;;
    3)
      EXISTING_PC="user-urgent"
      EXISTING_VALUE=250000
      TARGET_PC="urgent-priority"
      ;;
    *)
      echo "Error: unknown variant '$variant' (expected 1..$VARIANT_COUNT)" >&2
      return 1
      ;;
  esac

  EXPECTED_VALUE=$((EXISTING_VALUE - 1))
  VARIANT_SUMMARY="namespace=$NS, deployment=$DEPLOYMENT, existing priority class=$EXISTING_PC, create=$TARGET_PC with value one less than the highest user-defined class"
}

# Print the full question for the currently configured variant. LabSetUp.bash
# calls this after variant_config so the learner sees the exact values for the
# run instead of a generic question with hard-coded names.
variant_question() {
  local variant="${1:-?}"

  cat <<EOF
============================================================
 Question 7: PriorityClass (Variant $variant/$VARIANT_COUNT)
============================================================

You're working in a Kubernetes cluster with an existing deployment named
$DEPLOYMENT running in the $NS namespace.
The cluster already has a user-defined PriorityClass named $EXISTING_PC.

Tasks:
1. Create a new PriorityClass named $TARGET_PC for user workloads. The value
   of this class should be exactly one less than the highest existing
   user-defined priority class.
2. Patch the existing deployment $DEPLOYMENT in the $NS namespace to use the
   newly created $TARGET_PC class.

Run details:
- Namespace: $NS
- Deployment: $DEPLOYMENT
- Existing user-defined PriorityClass: $EXISTING_PC
- PriorityClass to create: $TARGET_PC

Video Link - https://youtu.be/CZzxGyF6OHc

Documentation Reference
Tip: Navigate the documentation manually to build familiarity with its structure
(yaml) Reference -> Command line tool (kubectl) -> kubectl reference -> kubectle create -> kubectl create priorityClass
https://kubernetes.io/docs/reference/kubectl/generated/kubectl_create/kubectl_create_priorityclass/
(patch by A-Elfiiky) Tasks -> Manage Kubernetes Objects -> Update API Objects in place using Kubectl patch
https://kubernetes.io/docs/tasks/manage-kubernetes-objects/update-api-object-kubectl-patch/
============================================================
EOF
}
