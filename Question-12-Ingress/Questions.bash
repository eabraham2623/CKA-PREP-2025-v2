# Question Ingress
# You have an existing Deployment in the echo-sound namespace. Lab setup prints the exact
# Deployment, Service, Ingress, hostname, and path for this run.

# Task
# 1. Expose the Deployment printed by lab setup with a Service of type NodePort using the
# printed Service name and Service port. The container listens on port 8080, so the
# Service must target container port 8080.
# 2. Create a new Ingress resource with the printed name in the echo-sound namespace for
# http://<printed host><printed path>.
# 3. The availability of the Service can be checked using the following command
# curl NODEIP:NODEPORT<printed path>

# In the exam it may give you a command like
# curl -o /dev/null -s -w "%{http_code}\n" http://<printed host><printed path>
# This requires an ingress controller, to get this to work ensure your /etc/hosts file has
# an entry for your NodeIP pointing to the printed hostname.

# Video Link - https://youtu.be/sy9zABvDedQ
