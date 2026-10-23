# Question SideCar

# The lab setup prints the exact namespace, deployment, main container, log file,
# mount path, and sidecar values for this run. Use those values for this task.

# Task
# Update the deployment printed by setup by adding a co-located sidecar container
# named sidecar using the busybox:stable image to the existing pod.
# The new sidecar container has to run the following command (as given by the exam task):
#   /bin/sh -c tail -f <LOG_FILE>
# Add a shared emptyDir volume mounted at the mount path printed by setup in both
# the main container and the sidecar so the sidecar can read the main container's log.
# Note: In your solution use `tail -F` (capital F) - it follows log files across
# rotation and re-creation, whereas `-f` (lowercase) can miss logs after rotation.

#Video link - https://youtu.be/3xraEGGQJDY

#Documentation Reference
# Tip: Navigate the documentation manually to build familiarity with its structure
# Concepts -> Workloads -> pod -> Sidecar Containers
# https://kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/
