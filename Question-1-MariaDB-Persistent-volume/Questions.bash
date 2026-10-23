# Question:
# A user accidentally deleted the MariaDB Deployment in a Kubernetes namespace. The deployment
# was configured with persistent storage. Your responsibility is to re-establish the deployment
# while ensuring data is preserved by reusing the available PersistentVolume.

#Task
# The lab setup prints the exact namespace, PV, PVC, deployment, and storage size for this run.
# Use those values for the following steps.
# A PersistentVolume already exists and is retained for reuse. Use the PV name printed by lab setup.
# Create a Persistent Volume Claim (PVC) in the lab namespace with the spec
# Access Mode = ReadWriteOnce
# Storage = the size printed by lab setup
# Edit the MariaDb Deployment file located at ~/mariadb-deploy.yaml to use the PVC created in the previous step
# Apply the updated Deployment file to the cluster
# Ensure the MariaDB Deployment is running and Stable

#Video Link - https://youtu.be/aXvvc1EB1zg

#Documentation Reference
# Tip: Navigate the documentation manually to build familiarity with its structure
# Concepts -> Storage -> Persistent Volumes
# https://kubernetes.io/docs/concepts/storage/persistent-volumes/
