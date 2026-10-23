#!/bin/bash
# Variant presets for Question 2 - ArgoCD Helm template.
#
# variant_config is the single source of truth for every value that changes
# between presets. LabSetUp.bash and validate.bash both call it after reading
# the recorded variant.

VARIANT_COUNT=3

REPO_URL="https://argoproj.github.io/argo-helm"
CHART_NAME="argo-cd"

variant_config() {
  local variant="${1:-}"

  case "$variant" in
    1)
      REPO_NAME="argocd"
      NS="argocd"
      CHART_VERSION="7.7.3"
      OUTPUT="/root/argo-helm.yaml"
      VALUE_KIND="service-type"
      VALUE="NodePort"
      VALUE_LABEL="server-service-type"
      VALUE_REQUIREMENT="the Argo CD server Service is rendered with type $VALUE"
      ;;
    2)
      REPO_NAME="argo"
      NS="argo-cd"
      CHART_VERSION="7.8.0"
      OUTPUT="/root/argo-cd-helm.yaml"
      VALUE_KIND="replicas"
      VALUE="2"
      VALUE_LABEL="server-replicas"
      VALUE_REQUIREMENT="the Argo CD server Deployment is rendered with exactly $VALUE replicas"
      ;;
    3)
      REPO_NAME="argoproj"
      NS="argocd-system"
      CHART_VERSION="7.9.0"
      OUTPUT="/root/argocd-helm.yaml"
      VALUE_KIND="service-type"
      VALUE="LoadBalancer"
      VALUE_LABEL="server-service-type"
      VALUE_REQUIREMENT="the Argo CD server Service is rendered with type $VALUE"
      ;;
    *)
      echo "Error: unknown variant '$variant' (expected 1..$VARIANT_COUNT)" >&2
      return 1
      ;;
  esac

  VARIANT_SUMMARY="repo=$REPO_NAME, namespace=$NS, chart=$CHART_NAME-$CHART_VERSION, output=$OUTPUT, $VALUE_LABEL=$VALUE"
}

# Print the full question for the currently configured variant. LabSetUp.bash
# calls this after variant_config so the learner sees the exact values for the
# run instead of a generic question with hard-coded names.
variant_question() {
  local variant="${1:-?}"

  cat <<EOF
============================================================
 Question 2: ArgoCD Helm Template (Variant $variant/$VARIANT_COUNT)
============================================================

Install Argo CD in the Kubernetes cluster using Helm while ensuring the
Argo CD CRDs are not included (they are considered pre-installed).

Task:
1. Add the official Argo CD Helm repository with the name $REPO_NAME
   ($REPO_URL).
2. Create a namespace named $NS.
3. Generate a Helm template from the Argo CD chart ($CHART_NAME) version
   $CHART_VERSION for namespace $NS.
4. Configure the chart so that:
   - the CRDs are not included, and
   - $VALUE_REQUIREMENT.
5. Save the generated YAML manifest to $OUTPUT.

Note: The --skip-crds Helm flag does NOT reliably prevent CRD installation
for all charts. Some charts (like argo-cd) bundle CRDs as regular templates
controlled by a chart value. Search the chart values for the crds setting
and set it to false.

Video link - https://youtu.be/e0YGRSjb8CU
============================================================
EOF
}
