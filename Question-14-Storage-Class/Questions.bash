# Question Storage Class

# The lab setup prints the exact StorageClass name, provisioner, and volume
# binding mode for this run. Use those values for the following steps.

# Tasks
# 1. Create a new StorageClass with the name and provisioner printed by setup.
#    Set the VolumeBindingMode to WaitForFirstConsumer.
#    Do not make the StorageClass default.
# 2. Patch the StorageClass to make it the default StorageClass.
# 3. Ensure the StorageClass created in step 1 is the only default class.
# Do not modify any existing Deployments or PersistentVolumeClaims.

# Video link - https://youtu.be/di7X7OHn2fc

# Documentation Reference
# Tip: Navigate the documentation manually to build familiarity with its structure
# Concepts -> Storage -> Storage Classes
# https://kubernetes.io/docs/concepts/storage/storage-classes/
# Tasks -> Manage Kubernetes Objects -> Update API Objects in place using Kubectl patch
# https://kubernetes.io/docs/tasks/manage-kubernetes-objects/update-api-object-kubectl-patch/
