#!/bin/bash
# Variant presets for Question 6 - CRDs (cert-manager).
#
# variant_config is the single source of truth for the value that changes
# between presets: the Certificate spec field whose documentation the learner
# must extract. The cert-manager release, namespace, deployment, output paths,
# and required commands stay fixed so every preset has the same difficulty.

VARIANT_COUNT=3

# Fixed values shared by every preset.
NS="cert-manager"
DEPLOYMENT="cert-manager"
CM_VERSION="v1.14.0"
CRD_URL="https://github.com/cert-manager/cert-manager/releases/download/${CM_VERSION}/cert-manager.crds.yaml"
RESOURCES_FILE="/root/resources.yaml"
SUBJECT_FILE="/root/subject.yaml"
TARGET_RESOURCE="Certificate"

# CRDs installed by the pinned cert-manager release.
CERT_MANAGER_CRDS=(
  certificaterequests.cert-manager.io
  certificates.cert-manager.io
  challenges.acme.cert-manager.io
  clusterissuers.cert-manager.io
  issuers.cert-manager.io
  orders.acme.cert-manager.io
)

variant_config() {
  local variant="${1:-}"

  case "$variant" in
    1)
      TARGET_FIELD="spec.subject"
      TARGET_MARKERS=("subject" "organizations" "postalCodes" "provinces")
      ;;
    2)
      TARGET_FIELD="spec.issuerRef"
      TARGET_MARKERS=("issuerRef" "group" "kind" "name")
      ;;
    3)
      TARGET_FIELD="spec.privateKey"
      TARGET_MARKERS=("privateKey" "rotationPolicy" "algorithm" "encoding" "size")
      ;;
    *)
      echo "Error: unknown variant '$variant' (expected 1..$VARIANT_COUNT)" >&2
      return 1
      ;;
  esac

  EXPLAIN_TARGET="certificate.${TARGET_FIELD}"
  VARIANT_SUMMARY="cert-manager=$CM_VERSION, explain=$EXPLAIN_TARGET, outputs=$RESOURCES_FILE and $SUBJECT_FILE"
}

# Print the full question for the currently configured variant.
variant_question() {
  local variant="${1:-?}"

  cat <<EOF
============================================================
 Question 6: CRDs - cert-manager (Variant $variant/$VARIANT_COUNT)
============================================================

Tasks:
1. Create a list of all cert-manager CRDs and save it to $RESOURCES_FILE
2. Using kubectl extract the documentation for the $TARGET_FIELD field of the
   $TARGET_RESOURCE custom resource and save it to $SUBJECT_FILE
You may use any output format that kubectl supports.

Run details:
- cert-manager version: $CM_VERSION
- CRD list output: $RESOURCES_FILE
- Field documentation output: $SUBJECT_FILE
- Field to document: $EXPLAIN_TARGET

Video Link - https://youtu.be/SA1DzLQaDJs

Documentation Reference
Tip: Navigate the documentation manually to build familiarity with its structure
Concepts -> Extending Kubernetes -> Custom Resources
https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/
============================================================
EOF
}
