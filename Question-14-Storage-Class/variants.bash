#!/bin/bash
# Variant presets for Question 14 - Storage Class.
#
# variant_config is the single source of truth for every value that changes
# between presets: the StorageClass the learner must create and its
# provisioner. The existing default StorageClass, volume binding mode, task
# steps, and object count stay fixed so every preset has the same difficulty.

VARIANT_COUNT=3

# Fixed values shared by every preset.
EXISTING_SC="local-path"
VOLUME_BINDING_MODE="WaitForFirstConsumer"
ANSWER_FILE="$HOME/sc.yaml"

variant_config() {
  local variant="${1:-}"

  case "$variant" in
    1)
      SC_NAME="local-storage"
      PROVISIONER="rancher.io/local-path"
      ;;
    2)
      SC_NAME="fast-storage"
      PROVISIONER="kubernetes.io/no-provisioner"
      ;;
    3)
      SC_NAME="nfs-storage"
      PROVISIONER="nfs.csi.k8s.io"
      ;;
    *)
      echo "Error: unknown variant '$variant' (expected 1..$VARIANT_COUNT)" >&2
      return 1
      ;;
  esac

  VARIANT_SUMMARY="storageclass=$SC_NAME, provisioner=$PROVISIONER, volumeBindingMode=$VOLUME_BINDING_MODE, existing default=$EXISTING_SC"
}

# Print the full question for the currently configured variant. LabSetUp.bash
# calls this after variant_config so the learner sees the exact values for the
# run instead of a generic question with hard-coded names.
variant_question() {
  local variant="${1:-?}"

  cat <<EOF
============================================================
 Question 14: Storage Class (Variant $variant/$VARIANT_COUNT)
============================================================

Tasks:
1. Create a new StorageClass named $SC_NAME with the provisioner
   $PROVISIONER. Set the VolumeBindingMode to $VOLUME_BINDING_MODE.
   Do not make the StorageClass default.
2. Patch the StorageClass to make it the default StorageClass.
3. Ensure $SC_NAME is the only default StorageClass.
Do not modify any existing Deployments or PersistentVolumeClaims.

Run details:
- StorageClass to create: $SC_NAME
- Provisioner: $PROVISIONER
- VolumeBindingMode: $VOLUME_BINDING_MODE
- Existing default StorageClass: $EXISTING_SC

Video Link - https://youtu.be/di7X7OHn2fc

Documentation Reference
Tip: Navigate the documentation manually to build familiarity with its structure
Concepts -> Storage -> Storage Classes
https://kubernetes.io/docs/concepts/storage/storage-classes/
Tasks -> Manage Kubernetes Objects -> Update API Objects in place using Kubectl patch
https://kubernetes.io/docs/tasks/manage-kubernetes-objects/update-api-object-kubectl-patch/
============================================================
EOF
}
