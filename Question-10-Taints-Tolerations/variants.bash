#!/bin/bash
# Variant presets for Question 10 - Taints & Tolerations.
#
# variant_config is the single source of truth for every value that changes
# between presets: the taint key/value/effect and the toleration the pod needs.
# The node, pod name, and namespace stay fixed so every preset has the same
# task, commands, and difficulty.
#
# All presets keep the hard scheduling guarantee ("no normal pods can be
# scheduled on the node"):
#   - NoSchedule with a value
#   - NoExecute with a value
#   - NoSchedule without a value (the toleration must use operator Exists)

VARIANT_COUNT=3

# Fixed values shared by every preset.
NODE="node01"
POD_NAME="nginx"
POD_NAMESPACE="default"

variant_config() {
  local variant="${1:-}"

  case "$variant" in
    1)
      TAINT_KEY="PERMISSION"
      TAINT_VALUE="granted"
      TAINT_EFFECT="NoSchedule"
      ;;
    2)
      TAINT_KEY="ENVIRONMENT"
      TAINT_VALUE="production"
      TAINT_EFFECT="NoExecute"
      ;;
    3)
      TAINT_KEY="dedicated"
      TAINT_VALUE=""
      TAINT_EFFECT="NoSchedule"
      ;;
    *)
      echo "Error: unknown variant '$variant' (expected 1..$VARIANT_COUNT)" >&2
      return 1
      ;;
  esac

  if [[ -n "$TAINT_VALUE" ]]; then
    TAINT_SPEC="$TAINT_KEY=$TAINT_VALUE:$TAINT_EFFECT"
    TOLERATION_OPERATOR="Equal"
  else
    TAINT_SPEC="$TAINT_KEY:$TAINT_EFFECT"
    TOLERATION_OPERATOR="Exists"
  fi

  VARIANT_SUMMARY="node=$NODE, taint=$TAINT_SPEC, pod=$POD_NAME in namespace $POD_NAMESPACE"
}

# Print the full question for the currently configured variant. LabSetUp.bash
# calls this after variant_config so the learner sees the exact values for the
# run instead of a generic question with hard-coded names.
variant_question() {
  local variant="${1:-?}"
  local taint_requirement toleration_requirement

  if [[ -n "$TAINT_VALUE" ]]; then
    taint_requirement="key=$TAINT_KEY, value=$TAINT_VALUE, Type=$TAINT_EFFECT"
    toleration_requirement="Match key $TAINT_KEY, value $TAINT_VALUE, and effect $TAINT_EFFECT."
  else
    taint_requirement="key=$TAINT_KEY, no value, Type=$TAINT_EFFECT"
    toleration_requirement="The taint has no value, so use operator Exists with key $TAINT_KEY and effect $TAINT_EFFECT."
  fi

  cat <<EOF
============================================================
 Question 10: Taints & Tolerations (Variant $variant/$VARIANT_COUNT)
============================================================

Tasks:
1. Add a taint to $NODE so that no normal pods can be scheduled on
   this node: $taint_requirement.
2. Schedule a Pod named $POD_NAME in the $POD_NAMESPACE namespace on
   $NODE. Add the correct toleration to the pod spec so it can be
   deployed. $toleration_requirement

Video Link - https://youtu.be/oy6Mdqt1-jk

Documentation Reference
Tip: Navigate the documentation manually to build familiarity with its structure
Concepts -> Scheduling, Preemption and Eviction -> Taints and Tolerations
https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/
============================================================
EOF
}
