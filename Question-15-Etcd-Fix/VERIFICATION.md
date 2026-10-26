# Question 15 — Manual Verification: Control-Plane Repair

> **Disposable cluster only.** This lab edits static control-plane manifests and
> the CoreDNS ConfigMap. A mistake can leave the cluster without an API server.
> Run `scripts/run-question.sh 15 [variant]` and read the printed fault list
> before starting.
>
> This page covers **post-repair verification**. For diagnosis and repair, use
> [TROUBLESHOOTING.md](TROUBLESHOOTING.md). The goal here is to prove every
> fault is gone and the control plane is genuinely healthy.

## What success looks like

The API server answers, all control-plane pods are Running, the static
manifests use the local etcd client endpoint, scheduler/controller resources are
sane, CoreDNS has a valid `cluster.local` Corefile, cluster DNS resolves, and a
test Deployment both schedules and reconciles.

## 60-second review

- [ ] `/readyz` returns `ok`.
- [ ] `kubectl get nodes` returns all nodes, all `Ready`.
- [ ] Every control-plane pod is Running.
- [ ] The API server uses local etcd on `2379`, not the peer port or a stale IP.
- [ ] Scheduler and controller-manager resources are not artificially starved.
- [ ] CoreDNS is available and DNS resolves.
- [ ] A test Deployment gets a Running pod.

## Detailed checks

### 1. Check the API and nodes

```bash
timeout 5 kubectl get --raw='/readyz'
kubectl get nodes
```

Expected: `ok` and all nodes `Ready`. If the API is down, stop here and use the
API-down triage in `TROUBLESHOOTING.md`; `kubectl` checks cannot run yet.

### 2. Check control-plane containers

```bash
kubectl -n kube-system get pods -o wide
sudo crictl ps -a --name '^etcd$' --latest
sudo crictl ps -a --name '^kube-apiserver$' --latest
sudo crictl ps -a --name '^kube-scheduler$' --latest
sudo crictl ps -a --name '^kube-controller-manager$' --latest
```

Expected: the mirror pods are Running, and the `crictl` containers are Running
(not `Exited`). `crictl` is authoritative if the mirror-pod status looks stale.

### 3. Check the static manifests

```bash
sudo grep -- '--etcd-servers' /etc/kubernetes/manifests/kube-apiserver.yaml
sudo grep -A8 'resources:' /etc/kubernetes/manifests/kube-scheduler.yaml
sudo grep -A8 'resources:' /etc/kubernetes/manifests/kube-controller-manager.yaml
```

Expected:

- API server: `--etcd-servers=https://127.0.0.1:2379`, never `:2380` and never
  the stale external address.
- Scheduler: CPU request at most `200m`.
- Controller-manager: CPU request at most `500m`, and memory limit absent or at
  least `128Mi`.

Use the setup output to confirm which faults were present for this variant; for
the combined variant, all of them must be fixed.

### 4. Check CoreDNS and cluster DNS

```bash
kubectl -n kube-system get deploy coredns
kubectl -n kube-system get configmap coredns -o yaml | grep -A5 Corefile
kubectl run dnscheck --image=busybox:stable --restart=Never -- \
  nslookup kubernetes.default.svc.cluster.local
kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/dnscheck --timeout=60s || true
kubectl logs dnscheck
```

Expected: CoreDNS is fully available, the Corefile contains the `cluster.local`
zone (not a typo such as `wrong.local`), and the DNS lookup returns the
Kubernetes Service IP. Delete the test pod:

```bash
kubectl delete pod dnscheck --ignore-not-found
```

### 5. Prove scheduling and reconciliation

Create a test Deployment:

```bash
kubectl create deployment verify-controlplane --image=nginx --replicas=1
kubectl rollout status deploy/verify-controlplane --timeout=120s
kubectl get pods -l app=verify-controlplane -o wide
kubectl delete deploy verify-controlplane
```

Expected: the rollout completes and the pod is Running. This proves:

- the scheduler can place new pods (variants 3 and 5);
- the controller-manager creates and reconciles the ReplicaSet (variants 4 and
  5);
- the API server, etcd, and CNI are healthy together.

If the Deployment is created but no pod appears, check the
`kube-controller-manager` logs and its manifest. If the pod stays Pending,
check the scheduler.

### 6. Confirm no extra faults remain

```bash
kubectl -n kube-system get pods
kubectl get events -A --sort-by=.lastTimestamp | tail -30
```

Expected: no CrashLoopBackOff, no `FailedScheduling`, and no repeated
control-plane restarts. For the combined variant, verify each fault from the
setup output individually; fixing the API server alone is not enough.

## Common false positives

| Symptom | Likely cause |
|---|---|
| API works, but new pods stay Pending | Scheduler is still broken or its CPU request is too high |
| API works, but Deployments do not create ReplicaSets | Controller-manager is still broken or resource-starved |
| CoreDNS pod Running, DNS still fails | Corefile zone is still wrong or CoreDNS has not reloaded |
| `kubectl` works but control-plane pod restarts | Static manifest still has a bad resource limit or endpoint |
| Etcd container Running, API still failing | API server points at the peer port or a stale endpoint |
| Test Deployment works, DNS fails | CoreDNS/Corefile fault remains |

## Cleanup

```bash
scripts/cleanup-question.sh 15
```

Cleanup restores the pristine control-plane baseline recorded by setup and
clears variant state. Test only on a disposable cluster.
