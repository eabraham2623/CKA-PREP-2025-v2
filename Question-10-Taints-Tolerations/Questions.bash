# Question: Taints & Tolerations

# Tasks:
# The lab setup prints the exact taint key, value (if any), effect, node, and
# pod details for this run. Use those values for the following steps.
# 1. Add the printed taint to node01 so that no normal pods can be scheduled
#    on this node.
# 2. Schedule a Pod named nginx in the default namespace on node01, adding the
#    correct toleration to the pod spec so it can be deployed. Match the
#    taint's key, effect, and value (or use the Exists operator when the taint
#    has no value).

# Video Link - https://youtu.be/oy6Mdqt1-jk

#Documentation Reference
# Tip: Navigate the documentation manually to build familiarity with its structure
# Concepts -> Scheduling, Preemption and Eviction -> Taints and Tolerations
# https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/
