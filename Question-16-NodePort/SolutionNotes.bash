# Solution Notes for Question 16 - NodePort Service
#
# LabSetUp.bash prints the namespace, deployment, service, port name,
# container port, service port, target port, and NodePort for this run.
# Substitute the <..._FROM_SETUP> placeholders below.

# 1. Add the named container port to the existing deployment.
kubectl patch deployment <DEPLOYMENT_FROM_SETUP> -n <NAMESPACE_FROM_SETUP> -p '{
  "spec":{"template":{"spec":{"containers":[{
    "name":"nginx",
    "ports":[{"name":"<PORT_NAME_FROM_SETUP>","containerPort":<CONTAINER_PORT_FROM_SETUP>,"protocol":"TCP"}]
  }]}}}}'
kubectl get deploy <DEPLOYMENT_FROM_SETUP> -n <NAMESPACE_FROM_SETUP> -o wide

# 2. Create the NodePort Service. Setup labels the pods with
#    app=<deployment name>, so this selector matches them.
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: <SERVICE_FROM_SETUP>
  namespace: <NAMESPACE_FROM_SETUP>
spec:
  type: NodePort
  selector:
    app: <DEPLOYMENT_FROM_SETUP>
  ports:
  - port: <SERVICE_PORT_FROM_SETUP>
    targetPort: <TARGET_PORT_FROM_SETUP>
    protocol: TCP
    nodePort: <NODEPORT_FROM_SETUP>
EOF
kubectl get svc <SERVICE_FROM_SETUP> -n <NAMESPACE_FROM_SETUP> -o wide

# 3. Verify the Service has endpoints and responds on the NodePort.
kubectl get endpoints <SERVICE_FROM_SETUP> -n <NAMESPACE_FROM_SETUP>
# curl http://<NODE_IP>:<NODEPORT_FROM_SETUP>
