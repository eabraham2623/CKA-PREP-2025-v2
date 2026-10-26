# Question:
# There is an existing deployment in the nginx-static namespace. The deployment contains a ConfigMap that
# controls the TLS protocol versions NGINX accepts, as well as a Secret for TLS.

# There is a service called nginx-static in the nginx-static namespace that is currently exposing the deployment.

# Task:
# 1. Configure the ConfigMap to use the required ssl_protocols value printed by setup. If the ConfigMap is
#    immutable, recreate it with immutable: true.
# 2. Add the IP address of the service in /etc/hosts and name it ckaquestion.k8s.local
# 3. Restart the deployment and verify everything is working using the following commands
    curl -vk --tls-max 1.2 https://ckaquestion.k8s.local # result is printed by setup
    curl -vk --tlsv1.3 https://ckaquestion.k8s.local # should work

# Video Link
