# Question 12 — Manual Verification: Ingress

> **Run setup first.** `scripts/run-question.sh 12 [variant]` prints the exact
> namespace, Deployment, Service, Ingress, hostname, and path for this run.
> Replace the `<...>` placeholders below.
>
> `scripts/validate-question.sh 12` checks the Service and Ingress fields. This
> file is the human check: it proves the NodePort actually serves the app and
> explains the Ingress-controller limitation in this lab.

## What success looks like

The Deployment is exposed by a NodePort Service with the printed port and
`targetPort 8080`, the Service has endpoints, and `curl` through the NodePort
returns the echoserver response. The Ingress has the printed host, path,
path type, and backend Service/port.

## 60-second review

- [ ] The Service is `NodePort` and has the printed port.
- [ ] The Service targets container port 8080.
- [ ] The Service has endpoints.
- [ ] The NodePort returns the application response.
- [ ] The Ingress host, path, path type, and backend match the task.

## Detailed checks

### 1. Inspect the Service

```bash
kubectl get svc <SERVICE> -n echo-sound -o yaml
kubectl get endpoints <SERVICE> -n echo-sound
```

Expected:

- `spec.type: NodePort`
- `spec.ports[0].port: <SERVICE_PORT>`
- `spec.ports[0].targetPort: 8080`
- a non-empty endpoint list

Remember: the Service port and the NodePort are different numbers. The
NodePort is allocated by the cluster and is what you curl from outside the
cluster.

### 2. Curl the NodePort

```bash
NODEPORT=$(kubectl get svc <SERVICE> -n echo-sound -o jsonpath='{.spec.ports[0].nodePort}')
for ip in $(kubectl get nodes -o jsonpath='{range .items[*]}{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}'); do
  curl -sS -o /dev/null -w "$ip:$NODEPORT -> %{http_code}\n" \
    "http://$ip:$NODEPORT<PATH>"
done
```

Expected: `200` from the node(s), and the echoserver response if you omit
`-o /dev/null`. The path comes from setup; echoserver responds to it.

If the NodePort returns connection refused, check the Service endpoints and
the pod's container port. If it returns 404, check the path and the Service
`targetPort`.

### 3. Inspect the Ingress

```bash
kubectl get ingress <INGRESS> -n echo-sound -o yaml
kubectl describe ingress <INGRESS> -n echo-sound
```

Expected:

- `spec.rules[0].host: <HOST>`
- `spec.rules[0].http.paths[0].path: <PATH>`
- `pathType: Prefix`
- backend Service `<SERVICE>` and port `<SERVICE_PORT>`

The backend port must be the **Service port**, not the NodePort.

### 4. Understand the controller limitation

This lab does not install an ingress controller. As a result:

- the Ingress may have no address in `kubectl get ingress`;
- `curl http://<HOST><PATH>` will not work through the Ingress;
- that is expected and is not a reason to install a controller just for this
  lab.

If your cluster does have a controller, add the hostname to `/etc/hosts`
pointing at a node IP and test:

```bash
curl -sS -o /dev/null -w '%{http_code}\n' "http://<HOST><PATH>"
```

Expected: `200`. Without a controller, verify the Ingress spec instead.

## Common false positives

| Symptom | Likely cause |
|---|---|
| NodePort curl gets 404 | Wrong path, or Service targets the wrong port |
| Service has no endpoints | Selector does not match the pod labels |
| Ingress backend uses the NodePort | It should use the Service port |
| Ingress host/path missing | Rule was not created or was overwritten |
| Ingress has no address | No ingress controller is installed; expected here |
| `curl <HOST>` fails | `/etc/hosts` not configured, or no controller |

## Cleanup

```bash
scripts/cleanup-question.sh 12
```

Cleanup removes every preset's Ingress, Service, and Deployment from the
`echo-sound` namespace.
