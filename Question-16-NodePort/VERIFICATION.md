# Question 16 — Manual Verification: NodePort Service

> **Run setup first.** `scripts/run-question.sh 16 [variant]` prints the exact
> namespace, Deployment, Service, port name, service port, target port, and
> NodePort for this run. Replace the `<...>` placeholders below.
>
> `scripts/validate-question.sh 16` checks the recorded variant's fields. This
> file is the human check: it proves the Service selects the pods and the
> NodePort actually serves nginx from both nodes.

## What success looks like

The Deployment declares container port 80 with the printed name and TCP
protocol. The Service is `NodePort`, exposes the printed service port, targets
container port 80, uses the printed NodePort, and selects the Deployment's
pods. The NodePort returns HTTP 200 from both node IPs.

## 60-second review

- [ ] The Deployment has container port 80 with the printed name and TCP.
- [ ] The Service is `NodePort` with the printed service port, targetPort, and
      NodePort.
- [ ] The Service selector matches the pod labels.
- [ ] The Service has endpoints.
- [ ] Curl to both node IPs on the NodePort returns `200`.

## Detailed checks

### 1. Inspect the Deployment port

```bash
kubectl get deploy <DEPLOY> -n <NS> \
  -o jsonpath='{.spec.template.spec.containers[0].ports[0]}{"\n"}'
kubectl get pods -n <NS> -l app=<DEPLOY> -o wide
```

Expected: `containerPort: 80`, `name: <PORT_NAME>`, `protocol: TCP`, and the
pods are Running. The port name is required because the Service may refer to it
by name or number; the task prints the exact name.

### 2. Inspect the Service

```bash
kubectl get svc <SVC> -n <NS> -o yaml
kubectl describe svc <SVC> -n <NS>
```

Expected:

- `spec.type: NodePort`
- `spec.selector.app: <DEPLOY>` (or the selector printed by setup)
- `spec.ports[0].port: <SERVICE_PORT>`
- `spec.ports[0].targetPort: 80`
- `spec.ports[0].protocol: TCP`
- `spec.ports[0].nodePort: <NODEPORT>`

Do not confuse the service port with the NodePort. The NodePort is what you
curl from outside the cluster; the service port is the stable in-cluster port.

### 3. Confirm the Service has endpoints

```bash
kubectl get endpoints <SVC> -n <NS>
kubectl get endpointslices -n <NS> -l kubernetes.io/service-name=<SVC>
```

Expected: the pod IPs and container port 80. If the endpoint list is empty, the
selector does not match the pods, and the NodePort will time out.

### 4. Curl both nodes

```bash
for ip in $(kubectl get nodes \
  -o jsonpath='{range .items[*]}{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}'); do
  curl -sS -o /dev/null -w "$ip:<NODEPORT> -> %{http_code}\n" \
    "http://$ip:<NODEPORT>"
done
```

Expected: `200` from every node. The response body should be the nginx welcome
page:

```bash
curl -sS "http://<NODE_IP>:<NODEPORT>" | head -5
```

If one node returns 200 and another fails, check kube-proxy and the node's
NodePort listener. If both fail but endpoints exist, check the targetPort and
the pod's container port.

### 5. Confirm there is only one intended Service

```bash
kubectl get svc -n <NS>
```

Expected: `<SVC>` only. A stale Service from another variant can hold the same
NodePort or select the wrong pods; setup is designed to remove those, but
verify if you switched variants manually.

## Common false positives

| Symptom | Likely cause |
|---|---|
| Service exists but has no endpoints | Selector does not match the pod labels |
| Curl gets connection refused | No NodePort listener; check type and `nodePort` |
| Curl gets 404/502 | `targetPort` is wrong or points at a port nginx is not listening on |
| `nodePort` is different from the task | The cluster allocated a random port instead of the requested one |
| Port name is missing | The Deployment was not patched, only the Service was created |
| Service port and NodePort are confused | `port` is the in-cluster port; `nodePort` is the external one |

## Cleanup

```bash
scripts/cleanup-question.sh 16
```

Cleanup removes every preset's Service, Deployment, and namespace.
