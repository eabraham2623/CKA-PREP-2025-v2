# Question PriorityClass

#Task
# You're working in a Kubernetes cluster with an existing deployment running in
# a namespace, plus at least one user-defined PriorityClass.
#
# 1. Create a new PriorityClass named by setup for user workloads. The value of
#    this class should be exactly one less than the highest existing
#    user-defined priority class.
# 2. Patch the existing deployment named by setup to use the newly created
#    PriorityClass.

# Run details are printed by setup: the namespace, deployment, existing
# user-defined PriorityClass, and the PriorityClass to create.

# Video Link - https://youtu.be/CZzxGyF6OHc

#Documentation Reference
# Tip: Navigate the documentation manually to build familiarity with its structure
# (yaml) Reference -> Command line tool (kubectl) -> kubectl reference -> kubectle create -> kubectl create priorityClass
# https://kubernetes.io/docs/reference/kubectl/generated/kubectl_create/kubectl_create_priorityclass/
# (patch by A-Elfiiky) Tasks -> Manage Kubernetes Objects -> Update API Objects in place using Kubectl patch
# https://kubernetes.io/docs/tasks/manage-kubernetes-objects/update-api-object-kubectl-patch/
