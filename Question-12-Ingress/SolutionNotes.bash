# Solution Notes for Question 12 - Ingress
#
# LabSetUp.bash prints the exact Deployment, Service, Ingress, hostname, and
# path selected for this run. Substitute those values below.

# Expose the Deployment as a NodePort Service, mapping the requested service
# port to the container port 8080.
kubectl expose deployment <DEPLOYMENT> -n echo-sound \
  --name <SERVICE> --type NodePort \
  --port <SERVICE_PORT> --target-port 8080
kubectl get service -n echo-sound <SERVICE>

# Create the Ingress
cat <<'EOF' > ~/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: <INGRESS>
  namespace: echo-sound
spec:
  rules:
  - host: <HOST>
    http:
      paths:
      - path: <PATH>
        pathType: Prefix
        backend:
          service:
            name: <SERVICE>
            port:
              number: <SERVICE_PORT>
EOF
kubectl apply -f ~/ingress.yaml
kubectl get ingress -n echo-sound

# Optional test (NodePort): curl http://<nodeIP>:<nodePort><PATH>
# For ingress-controller testing, map <HOST> to a node IP in /etc/hosts.
