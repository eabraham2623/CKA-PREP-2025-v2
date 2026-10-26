# Read the setup output first. It prints the required ssl_protocols value and
# whether nginx-config must be mutable or immutable. The commands below use
# placeholders for those values.

# Step 1
# Inspect the existing ConfigMap.
kubectl get cm -n nginx-static nginx-config -o yaml

# If the ConfigMap is mutable, edit it and change only the ssl_protocols line:
kubectl edit cm -n nginx-static nginx-config
#   ssl_protocols TLSv1.2 TLSv1.3;   # TLS 1.2 + TLS 1.3
#   ssl_protocols TLSv1.3;           # TLS 1.3 only
# Use the exact required value printed by setup.

# If the ConfigMap is immutable, kubectl edit will fail with "field is immutable".
# Immutability cannot be reverted and the data cannot be changed, so delete and
# recreate the ConfigMap with the same name, the updated nginx.conf, and
# immutable: true. For example:
kubectl delete cm -n nginx-static nginx-config
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
  namespace: nginx-static
immutable: true
data:
  nginx.conf: |
    events {}
    http {
      server {
        listen 443 ssl;
        ssl_certificate /etc/nginx/tls/tls.crt;
        ssl_certificate_key /etc/nginx/tls/tls.key;
        ssl_protocols <required-protocols>;
        location / {
          return 200 "Hello TLS\n";
        }
      }
    }
EOF

# If the ConfigMap is mutable but the task requires it to stay mutable, do not
# add immutable: true. If a task ever asks you to make a mutable ConfigMap
# immutable, apply the data change first and set immutable: true afterwards;
# once true it cannot be changed back.

# Step 2
# Get the ClusterIP of the service.
kubectl get svc -n nginx-static nginx-static

# Add it to /etc/hosts. Use tee because a shell redirection after sudo would
# still run as your normal user, not root.
echo '<service-cluster-ip> ckaquestion.k8s.local' | sudo tee -a /etc/hosts
grep ckaquestion.k8s.local /etc/hosts

# Step 3
# The Deployment mounts nginx.conf with subPath, so ConfigMap changes do not
# reach an existing pod. Restart the Deployment to load the new configuration.
kubectl rollout restart deployment -n nginx-static nginx-static
kubectl rollout status deployment -n nginx-static nginx-static

# If the ConfigMap is immutable, a plain rolling restart can leave the new pod
# using the old copy cached by the kubelet. Remove every old pod before the new
# one starts by scaling to zero and back:
kubectl scale deployment -n nginx-static nginx-static --replicas=0
kubectl wait --for=delete pod -l app=nginx-static -n nginx-static --timeout=120s
kubectl scale deployment -n nginx-static nginx-static --replicas=1
kubectl rollout status deployment -n nginx-static nginx-static
# Deleting and recreating the Deployment also works.

# Verify. When the required set includes TLS 1.2, the first command should work.
# When NGINX is restricted to TLS 1.3 only, the first command should fail and
# the second should still work.
curl -vk --tls-max 1.2 https://ckaquestion.k8s.local
curl -vk --tlsv1.3 https://ckaquestion.k8s.local
