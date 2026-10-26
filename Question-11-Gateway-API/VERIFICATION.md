# Question 11 — Manual Verification: Gateway API

> **Run setup first.** `scripts/run-question.sh 11 [variant]` prints the exact
> existing Ingress, hostname, GatewayClass, Gateway, HTTPRoute, TLS secret, and
> backend service for this run. Replace the `<...>` placeholders below.
>
> `scripts/validate-question.sh 11` checks the Gateway and HTTPRoute fields.
> This file is the human check: it compares the new objects against the existing
> Ingress and explains what cannot be tested in this lab.

## What success looks like

The Gateway reproduces the Ingress's HTTPS listener: port 443, the same
hostname, TLS termination with the same Secret. The HTTPRoute attaches to that
Gateway, uses the same hostname, path, and backend Service/port. The
configuration is structurally equivalent to the Ingress.

## 60-second review

- [ ] Gateway uses the printed GatewayClass.
- [ ] Gateway listener is HTTPS on 443 with the printed hostname.
- [ ] TLS mode is `Terminate` and references the same Secret as the Ingress.
- [ ] HTTPRoute has the Gateway as a parent.
- [ ] HTTPRoute hostname, path, backend Service, and port match the Ingress.

## Detailed checks

### 1. Read the existing Ingress first

```bash
kubectl get ingress <INGRESS> -n default -o yaml
```

Note these values:

- `spec.tls[0].hosts[0]` and `spec.tls[0].secretName`
- `spec.rules[0].host`
- `spec.rules[0].http.paths[0].path` and `pathType`
- `backend.service.name` and `backend.service.port.number`

These are the source of truth the new objects must preserve.

### 2. Inspect the Gateway

```bash
kubectl get gateway <GATEWAY> -n default -o yaml
kubectl describe gateway <GATEWAY> -n default
```

Expected:

- `spec.gatewayClassName: <GATEWAY_CLASS>`
- one listener with `protocol: HTTPS`, `port: 443`
- `hostname: <HOST>`
- `tls.mode: Terminate`
- `tls.certificateRefs[0].name: <TLS_SECRET>`

### 3. Inspect the HTTPRoute

```bash
kubectl get httproute <HTTPROUTE> -n default -o yaml
kubectl describe httproute <HTTPROUTE> -n default
```

Expected:

- `spec.parentRefs[0].name: <GATEWAY>`
- `spec.hostnames[0]: <HOST>`
- a match with the Ingress path and `PathPrefix`
- `backendRefs[0].name: <SERVICE>`
- `backendRefs[0].port: <SERVICE_PORT>`

### 4. Check the GatewayClass

```bash
kubectl get gatewayclass <GATEWAY_CLASS> -o yaml
```

Expected: the class exists and has the controller name printed by setup.

### 5. Understand the status limitation

The GatewayClass in this lab uses a placeholder controller name
(`example.net/...`) and there is no Gateway controller running. As a result,
the Gateway may show no `Accepted`/`Programmed` status, or may remain
unaccepted even when the spec is correct.

Do **not** install an extra controller or chase traffic in this lab. The
verification target is the configuration migration, not live routing. If you
want a traffic test, you need a cluster with a real Gateway controller and a
matching GatewayClass; that is outside this exercise.

## Common false positives

| Symptom | Likely cause |
|---|---|
| Gateway listener is HTTP/80 | The Ingress was HTTPS on 443; the migration lost TLS |
| TLS Secret name differs | The Ingress secret was not copied |
| HTTPRoute has no parentRef | It will not attach to the Gateway |
| HTTPRoute backend port uses the NodePort | Should use the Service port from the Ingress backend |
| Path type is `Exact` instead of `PathPrefix` | The Ingress used `Prefix` |
| Gateway status is false | Expected with the placeholder GatewayClass; check the spec instead |

## Cleanup

```bash
scripts/cleanup-question.sh 11
```

Cleanup removes the Gateway, HTTPRoute, Ingress, TLS secret, backend
Deployment/Service, and the GatewayClass.
