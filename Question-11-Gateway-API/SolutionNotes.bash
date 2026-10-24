# Solution Notes for Question 11 - Gateway API
#
# LabSetUp.bash prints the exact Ingress, hostname, Gateway, HTTPRoute, and
# GatewayClass selected for this run. Substitute those values below.

# Step 1: Inspect existing assets (host, secret, backend service/port)
kubectl describe ingress <INGRESS> -n default
kubectl describe secret <TLS_SECRET> -n default

# Step 2: Create Gateway (mirrors Ingress host + TLS)
cat <<'EOF' > ~/gw.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: <GATEWAY>
  namespace: default
spec:
  gatewayClassName: <GATEWAY_CLASS>
  listeners:
  - name: https
    protocol: HTTPS
    port: 443
    hostname: <HOST>
    tls:
      mode: Terminate
      certificateRefs:
      - kind: Secret
        name: <TLS_SECRET>
EOF
kubectl apply -f ~/gw.yaml
kubectl get gateway -n default

# Step 3: Create HTTPRoute (mirrors Ingress rules)
cat <<'EOF' > ~/http.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: <HTTPROUTE>
  namespace: default
spec:
  parentRefs:
  - name: <GATEWAY>
  hostnames:
  - "<HOST>"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: <SERVICE>
      port: <SERVICE_PORT>
EOF
kubectl apply -f ~/http.yaml

# Step 4: Verify
kubectl describe gateway <GATEWAY> -n default
kubectl describe httproute <HTTPROUTE> -n default
