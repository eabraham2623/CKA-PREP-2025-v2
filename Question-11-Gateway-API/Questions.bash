# Question
# You have an existing web application deployed in the default namespace and exposed by an Ingress
# resource. You must migrate the existing Ingress configuration to the new Kubernetes Gateway API,
# maintaining the existing HTTPS access and routing configuration.

# Tasks
# The lab setup prints the exact Ingress, hostname, Gateway, HTTPRoute, and GatewayClass for this run.
# 1. Create the Gateway resource named by lab setup with the printed hostname. It must maintain the
#    existing TLS and listener configuration from the existing Ingress resource.
# 2. Create the HTTPRoute resource named by lab setup with the printed hostname. It must maintain the
#    existing routing rules from the current Ingress resource.
# Note: The GatewayClass printed by lab setup is already installed in the cluster

#Video link - https://youtu.be/G9zispvOCHE

#Documentation Reference
# Tip: Navigate the documentation manually to build familiarity with its structure
# Concepts -> Services, Load Balancing, and Networking -> Gateway API
# https://kubernetes.io/docs/concepts/services-networking/gateway/
