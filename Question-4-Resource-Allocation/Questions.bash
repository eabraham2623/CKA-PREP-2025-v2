# Question
# You are managing a WordPress application running in a Kubernetes cluster.
# Your task is to adjust the Pod resource requests and limits to ensure stable operation.

# Tasks
# 1. Scale down the deployment printed by setup to 0 replicas.
# 2. Edit the deployment and divide the node resource evenly across all pods
#    printed by setup.
# 3. Assign fair and equal CPU and memory to each Pod.
# 4. Add sufficient overhead to avoid node instability.
# Ensure both the init containers and the main containers use exactly the same
# resource requests and limits.
# After making the changes scale the deployment back to the replica count printed
# by setup.

# Run details are printed by setup: namespace, deployment, replica count, node,
# reserved overhead percentage, and rounding rule.

#Video link - https://youtu.be/ZqGDdETii8c

#Documentation Reference
# Tip: Navigate the documentation manually to build familiarity with its structure
# Concepts -> Configuration -> Resource Management for Pods and Containers
# https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/
