# Question 13 — Manual Verification: NetworkPolicy

> **Run setup first.** `scripts/run-question.sh 13 [variant]` prints the exact
> frontend/backend Deployments, pod labels, backend Service, and candidate
> files. Replace the `<...>` placeholders below.
>
> `scripts/validate-question.sh 13` checks that the correct policy was applied.
> This file is the human check: it proves the policy allows the frontend, blocks
> everyone else, and is the least permissive correct candidate.

## What success looks like

Exactly one NetworkPolicy is applied in the backend namespace. It selects the
backend pods, allows ingress only from frontend pods in the frontend namespace
on TCP port 80, and does not allow any `ipBlock`/CIDR source. The frontend can
reach the backend; a pod in another namespace or a pod with the wrong label
cannot.

## 60-second review

- [ ] Exactly one NetworkPolicy exists in the backend namespace.
- [ ] It selects the backend pods.
- [ ] The `from` rule combines the frontend namespace **and** frontend pod
      label in one element (AND), not two separate elements (OR).
- [ ] It allows only TCP port 80.
- [ ] It has no `ipBlock`.
- [ ] Frontend curl succeeds; default-namespace and wrong-label pods fail.

## Detailed checks

### 1. Confirm only one policy was applied

```bash
kubectl get networkpolicy -n backend
kubectl get networkpolicy -n backend -o yaml
```

Expected: exactly one policy, and its name matches the candidate selected for
this run. If all three candidate files were applied, the count is three and the
answer is wrong even if one of them is correct.

### 2. Inspect the policy semantics

```bash
kubectl describe networkpolicy -n backend <POLICY>
kubectl get networkpolicy -n backend <POLICY> -o yaml
```

Expected:

- `podSelector` matches the backend pod labels printed by setup.
- `policyTypes` includes `Ingress`.
- The ingress `from` list has **one** item containing both:
  - `namespaceSelector` for the frontend namespace; and
  - `podSelector` for the frontend pod labels.
- `ports` contains only `protocol: TCP`, `port: 80`.
- There is no `ipBlock` anywhere in the rule.

Two separate `from` list items mean OR: a pod from the frontend namespace or a
pod with the frontend label would be allowed independently. The correct policy
requires both conditions together.

### 3. Prove the allowed path works

```bash
kubectl exec -n frontend deploy/<FRONTEND_DEPLOYMENT> -- \
  curl -sS -o /dev/null -w '%{http_code}\n' --connect-timeout 5 \
  http://<BACKEND_SERVICE>.backend.svc.cluster.local:80
```

Expected: `200`. A timeout or connection refused means the policy is too
restrictive or the backend Service has no endpoints.

### 4. Prove unauthorized paths are blocked

From the default namespace:

```bash
kubectl run deny-default --image=curlimages/curl --restart=Never -- \
  curl -sS --connect-timeout 5 \
  http://<BACKEND_SERVICE>.backend.svc.cluster.local:80
kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/deny-default --timeout=20s || true
kubectl logs deny-default
```

Expected: the pod does not succeed; the log shows a timeout or connection
failure. A `200` means the policy is too open.

From the frontend namespace but with the wrong label:

```bash
kubectl -n frontend run deny-label --image=curlimages/curl \
  --labels=cka-check=wrong-label --restart=Never -- \
  curl -sS --connect-timeout 5 \
  http://<BACKEND_SERVICE>.backend.svc.cluster.local:80
kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/deny-label -n frontend --timeout=20s || true
kubectl logs deny-label -n frontend
```

Expected: also blocked. This proves the `podSelector` part of the rule is doing
its job, not just the namespace selector.

Delete the test pods:

```bash
kubectl delete pod deny-default --ignore-not-found
kubectl delete pod deny-label -n frontend --ignore-not-found
```

### 5. Confirm the backend still has endpoints

```bash
kubectl get endpoints <BACKEND_SERVICE> -n backend
```

Expected: the backend pod IP and port 80. A correct policy cannot help if the
Service selector does not match the backend pods.

## Common false positives

| Symptom | Likely cause |
|---|---|
| Frontend is blocked | Policy selects the wrong backend labels or wrong port |
| Default namespace can reach the backend | `namespaceSelector` is missing or the policy is allow-all |
| Wrong-label pod can reach the backend | The `podSelector` is in a separate `from` element (OR) |
| An `ipBlock` is present | The too-open candidate was selected |
| Three policies exist | All candidates were applied |
| Policy exists in the wrong namespace | NetworkPolicy is namespace-scoped; it must be in `backend` |

## Cleanup

```bash
scripts/cleanup-question.sh 13
```

Cleanup removes the workloads, Service, policies, and the generated
`network-policies/` directory under the caller's working directory.
