# Question 15 - Control-Plane Troubleshooting Walkthrough

> **Spoiler warning:** this file contains the full diagnosis and fix for every
> Q15 variant. Try the lab first and come back when you are stuck.

This walkthrough is written for the disposable CKA practice cluster. It uses
only operator tools: `kubectl`, `crictl`, `journalctl`, `ss`, `dig`/`nslookup`,
and a text editor. It does not use the repository's internal setup helpers or
the saved baseline under `.cka-state/` as a shortcut.

The lab assumes the control-plane node has about one allocatable CPU. The
scheduler and controller-manager resource faults are designed to be
unschedulable on that node. The examples use this lab's normal node name,
`controlplane`; substitute your node name if it differs. Check it with:

```bash
kubectl get node controlplane -o jsonpath='{.status.allocatable.cpu}{"\n"}'
```

Run Q15 only on a cluster you can destroy. It edits static control-plane
manifests and the CoreDNS ConfigMap.

## Start here: is the API available?

```bash
timeout 5 kubectl get --raw='/readyz'
kubectl get nodes
```

- `ok` and a node list: the API is up. Go to the API-up triage below.
- `The connection to the server ... was refused` or a timeout: the API is
  down. Go to the API-down triage below.

When the API is down, `kubectl` cannot help you. Use `crictl` and the kubelet
journal, then edit the static Pod manifests directly.

### API-down triage

```bash
sudo crictl ps -a
sudo crictl ps -a --name '^etcd$' --latest
sudo crictl ps -a --name '^kube-apiserver$' --latest
APISERVER_ID="$(sudo crictl ps -a --name '^kube-apiserver$' --latest -q)"
sudo crictl logs --tail=100 "$APISERVER_ID"
sudo journalctl -u kubelet -n 150 --no-pager
sudo grep -n -- '--etcd-servers' /etc/kubernetes/manifests/kube-apiserver.yaml
```

Useful details:

- `crictl ps` without `-a` shows only running containers. A failed component
  may be `Exited`, so use `-a`.
- `--latest` avoids reading logs from an old container attempt.
- The API server can be `Running` in `crictl` and still fail its readiness
  check. A failed readiness check is enough to make the API unavailable.
- If the newest API server container was just recreated, its log may briefly
  be empty or contain only shutdown messages. Re-run
  `sudo crictl ps -a --name '^kube-apiserver$' --latest`, take the new ID, and
  read the log again after a few seconds.
- Inspect the exit code with `sudo crictl inspect "$APISERVER_ID" | grep -E
  'exitCode|reason|message'` (or use the relevant component's container ID).
- If no container exists for a component, the kubelet probably rejected or
  could not parse its manifest. Check the kubelet journal.

### API-up triage

```bash
kubectl get nodes
kubectl -n kube-system get pods -o wide
kubectl -n kube-system get events --sort-by=.lastTimestamp | tail -30
sudo crictl ps -a --name '^kube-scheduler$' --latest
sudo crictl ps -a --name '^kube-controller-manager$' --latest
sudo journalctl -u kubelet -n 150 --no-pager
```

Static Pod mirror status can lag behind the container runtime. The `crictl`
state is authoritative when `kubectl` still shows an old `Running` or
`Pending` status.

### Pick the right section

| What you see | Start with |
|---|---|
| API down, `kube-apiserver` uses etcd port `2380` | Variant 1 |
| API down, `kube-apiserver` uses `192.0.2.100` | Variant 2 |
| API up, `kube-scheduler` container is missing or not Running | Variant 3 |
| API up, `kube-controller-manager` container is missing or not Running | Variant 4 |
| API down first, then scheduler/controller or DNS faults remain | Variant 5 |

Variant 5 starts with the same etcd fault as Variant 1. After restoring API
access, **re-run the API-up triage** before declaring the lab fixed.

## Safe edits to static Pod manifests

Static Pods are controlled by files in `/etc/kubernetes/manifests/`. Do not
use `kubectl edit pod` on `kube-apiserver-<node>` or the other mirror Pods:
the API server owns those objects, and editing them does not change the
manifest on disk.

Kubelet watches the manifest directory. Writing a file in place can expose a
truncated file for a moment, so use a hidden temporary file and an atomic
rename:

```bash
COMPONENT=kube-apiserver   # or kube-scheduler, kube-controller-manager
sudo cp "/etc/kubernetes/manifests/${COMPONENT}.yaml" "/tmp/${COMPONENT}.yaml"
# Edit /tmp/${COMPONENT}.yaml with vi, nano, or sed.
sudo install -m 600 -o root -g root "/tmp/${COMPONENT}.yaml" \
  "/etc/kubernetes/manifests/.${COMPONENT}.yaml.q15"
sudo mv "/etc/kubernetes/manifests/.${COMPONENT}.yaml.q15" \
  "/etc/kubernetes/manifests/${COMPONENT}.yaml"
```

Hidden files in the manifest directory are ignored by kubelet. The `mv` is
atomic within the filesystem. You do not need to restart kubelet: it notices
the changed manifest and recreates the static Pod.

For CoreDNS, the object is a normal ConfigMap, so `kubectl edit configmap` is
the right tool.

## Variant 1 - API server points at the etcd peer port

### Symptom

The API is unavailable. The etcd container is healthy, and the
kube-apiserver container may be `Running`, but readiness never succeeds.

### Diagnose

```bash
timeout 5 kubectl get --raw='/readyz'
sudo crictl ps -a --name '^etcd$' --latest
sudo crictl ps -a --name '^kube-apiserver$' --latest
sudo crictl logs --tail=100 "$(sudo crictl ps -a --name '^kube-apiserver$' --latest -q)" |
  grep -iE 'etcd|2380|connection|timeout'
sudo grep -n -- '--etcd-servers' /etc/kubernetes/manifests/kube-apiserver.yaml
```

Look for `connection refused` or a timeout while connecting to port `2380`.
Port `2380` is etcd's peer port; clients must use `2379`.

Confirm that local etcd itself is healthy:

```bash
ETCD_ID="$(sudo crictl ps --name '^etcd$' --latest -q)"
sudo crictl exec "$ETCD_ID" etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  endpoint health
```

### Root cause

The kube-apiserver static Pod was given the etcd peer endpoint
`https://127.0.0.1:2380` instead of the client endpoint
`https://127.0.0.1:2379`.

### Fix

```bash
sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/kube-apiserver.yaml
sudo sed -i 's#--etcd-servers=.*#--etcd-servers=https://127.0.0.1:2379#' \
  /tmp/kube-apiserver.yaml
sudo grep -n -- '--etcd-servers' /tmp/kube-apiserver.yaml
sudo install -m 600 -o root -g root /tmp/kube-apiserver.yaml \
  /etc/kubernetes/manifests/.kube-apiserver.yaml.q15
sudo mv /etc/kubernetes/manifests/.kube-apiserver.yaml.q15 \
  /etc/kubernetes/manifests/kube-apiserver.yaml
```

Use the loopback address `127.0.0.1`, not the node IP. The validator checks
for the exact local endpoint.

### Verify

```bash
for i in $(seq 1 60); do
  timeout 5 kubectl get --raw='/readyz' >/dev/null 2>&1 && break
  sleep 2
done
kubectl get nodes
sudo grep -- '--etcd-servers' /etc/kubernetes/manifests/kube-apiserver.yaml
```

Expected: `/readyz` returns `ok`, nodes are listed, and the manifest contains
`--etcd-servers=https://127.0.0.1:2379` with no `2380`.

### Common mistakes

- Using the node IP instead of `127.0.0.1`; the API may work but validation
  will fail.
- Changing the etcd manifest instead of the API server manifest. Etcd was
  already healthy; the API server had the wrong client address.
- Editing the mirror Pod with `kubectl edit pod`.
- Restarting kubelet unnecessarily. Kubelet recreates the container when the
  manifest changes.

## Variant 2 - API server points at the old external etcd

### Symptom

The API is unavailable after an etcd migration. The local etcd container is
healthy, but the API server still uses the old external endpoint.

### Diagnose

```bash
timeout 5 kubectl get --raw='/readyz'
sudo crictl ps -a --name '^etcd$' --latest
sudo crictl ps -a --name '^kube-apiserver$' --latest
sudo crictl logs --tail=100 "$(sudo crictl ps -a --name '^kube-apiserver$' --latest -q)" |
  grep -iE '192\.0\.2\.100|deadline|timeout|connection'
sudo grep -n -- '--etcd-servers' /etc/kubernetes/manifests/kube-apiserver.yaml
```

`192.0.2.100` is in the TEST-NET-1 documentation range and is not a reachable
etcd endpoint in this lab. The API server log usually shows a connection
timeout or deadline exceeded.

Confirm local etcd with the same `etcdctl endpoint health` command from
Variant 1.

### Root cause

The migration left `--etcd-servers=https://192.0.2.100:2379` in the API server
manifest. The correct local client endpoint is
`https://127.0.0.1:2379`.

### Fix

Use the same safe edit as Variant 1:

```bash
sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/kube-apiserver.yaml
sudo sed -i 's#--etcd-servers=.*#--etcd-servers=https://127.0.0.1:2379#' \
  /tmp/kube-apiserver.yaml
sudo install -m 600 -o root -g root /tmp/kube-apiserver.yaml \
  /etc/kubernetes/manifests/.kube-apiserver.yaml.q15
sudo mv /etc/kubernetes/manifests/.kube-apiserver.yaml.q15 \
  /etc/kubernetes/manifests/kube-apiserver.yaml
```

### Verify

Use the same readiness loop, node check, and manifest check as Variant 1.

### Common mistakes

- Trying to reach the old external IP and assuming etcd is down. Check the
  local etcd container and `etcdctl` first.
- Using a hostname or node IP as a replacement. The validator expects
  `https://127.0.0.1:2379`.
- Forgetting that the API server can take a little time to restart.

## Variant 3 - Scheduler cannot fit on the node

### Symptom

`kubectl` works, but new Pods stay `Pending` and Deployments do not produce
Running replicas. The kube-scheduler static Pod is missing, `Pending`, or
`UnexpectedAdmissionError`.

### Diagnose

```bash
kubectl get nodes
kubectl -n kube-system get pods -o wide
kubectl -n kube-system describe pod -l component=kube-scheduler
kubectl -n kube-system get events --sort-by=.lastTimestamp | tail -30
sudo crictl ps -a --name '^kube-scheduler$' --latest
sudo journalctl -u kubelet -n 150 --no-pager |
  grep -iE 'scheduler|admission|insufficient|parse'
kubectl get node controlplane -o jsonpath='{.status.allocatable.cpu}{"\n"}'
sudo grep -n -A6 'resources:' /etc/kubernetes/manifests/kube-scheduler.yaml
```

Look for `UnexpectedAdmissionError`, `Insufficient cpu`, or an admission
failure in the kubelet journal. On this lab's one-CPU control-plane node, a
`1999m` CPU request cannot fit. The scheduler container may never start, so
there may be no scheduler logs to read.

### Root cause

The scheduler's `resources.requests.cpu` was set to `1999m`, leaving no room
for the static Pod on the node.

### Fix

Change the CPU request to `100m` (the pristine baseline is `25m`; either is
acceptable, but `100m` is a safe working value):

```bash
sudo cp /etc/kubernetes/manifests/kube-scheduler.yaml /tmp/kube-scheduler.yaml
sudo sed -i '/^      requests:/,/^      [a-zA-Z]/ s/^        cpu:.*/        cpu: 100m/' \
  /tmp/kube-scheduler.yaml
sudo grep -n -A4 'resources:' /tmp/kube-scheduler.yaml
sudo install -m 600 -o root -g root /tmp/kube-scheduler.yaml \
  /etc/kubernetes/manifests/.kube-scheduler.yaml.q15
sudo mv /etc/kubernetes/manifests/.kube-scheduler.yaml.q15 \
  /etc/kubernetes/manifests/kube-scheduler.yaml
```

Do not change the scheduler's command-line flags or its intended function.

### Verify

```bash
for i in $(seq 1 60); do
  sudo crictl ps --name '^kube-scheduler$' --state Running -q | grep -q . && break
  sleep 2
done
kubectl -n kube-system get pods -l component=kube-scheduler -o wide
kubectl create deployment q15-scheduler-smoke \
  --image=registry.k8s.io/pause:3.9 --replicas=2
kubectl rollout status deployment/q15-scheduler-smoke --timeout=90s
kubectl get pods -l app=q15-scheduler-smoke -o wide
kubectl delete deployment q15-scheduler-smoke --ignore-not-found
```

The `rollout status` command waits for the Deployment to be observed and for
the scheduler to place the Pods. The smoke-test Pods should then show a node
in the `NODE` column. They do not need to pull a large image; `pause` is
normally already present.

### Common mistakes

- Setting the request to `1000m` or `1999m` and expecting it to fit. Use a
  small request; the validator accepts at most `200m`.
- Editing the mirror Pod instead of the manifest.
- Creating a test Deployment before fixing the scheduler and concluding the
  cluster is broken. Fix the scheduler first.
- Forgetting to delete the test Deployment.

## Variant 4 - Controller manager cannot fit on the node

### Symptom

`kubectl` works, but Deployments and ReplicaSets do not reconcile. The
kube-controller-manager static Pod is missing, `Pending`, or
`UnexpectedAdmissionError`.

### Diagnose

```bash
kubectl get nodes
kubectl -n kube-system get pods -o wide
kubectl -n kube-system describe pod -l component=kube-controller-manager
kubectl -n kube-system get events --sort-by=.lastTimestamp | tail -30
sudo crictl ps -a --name '^kube-controller-manager$' --latest
sudo journalctl -u kubelet -n 150 --no-pager |
  grep -iE 'controller-manager|admission|insufficient|oom|parse'
kubectl get node controlplane -o jsonpath='{.status.allocatable.cpu}{"\n"}'
sudo grep -n -A6 'resources:' /etc/kubernetes/manifests/kube-controller-manager.yaml
```

Look for an admission failure and a CPU request of `4` (four cores) on a
one-CPU node.

### Root cause

The controller-manager's `resources.requests.cpu` was set to `4`, so its
static Pod cannot be admitted.

### Fix

```bash
sudo cp /etc/kubernetes/manifests/kube-controller-manager.yaml \
  /tmp/kube-controller-manager.yaml
sudo sed -i '/^      requests:/,/^      [a-zA-Z]/ s/^        cpu:.*/        cpu: 100m/' \
  /tmp/kube-controller-manager.yaml
sudo grep -n -A4 'resources:' /tmp/kube-controller-manager.yaml
sudo install -m 600 -o root -g root /tmp/kube-controller-manager.yaml \
  /etc/kubernetes/manifests/.kube-controller-manager.yaml.q15
sudo mv /etc/kubernetes/manifests/.kube-controller-manager.yaml.q15 \
  /etc/kubernetes/manifests/kube-controller-manager.yaml
```

### Verify

```bash
for i in $(seq 1 60); do
  sudo crictl ps --name '^kube-controller-manager$' --state Running -q | grep -q . && break
  sleep 2
done
kubectl -n kube-system get pods -l component=kube-controller-manager -o wide
kubectl create deployment q15-controller-smoke \
  --image=registry.k8s.io/pause:3.9 --replicas=2
kubectl rollout status deployment/q15-controller-smoke --timeout=90s
kubectl get deploy,rs,pods -l app=q15-controller-smoke
kubectl delete deployment q15-controller-smoke --ignore-not-found
```

A successful rollout proves that the Deployment and ReplicaSet controllers are
reconciling again. Delete the smoke test when you are done.

### Common mistakes

- Setting CPU to another value that is still too large for the node. The
  validator accepts at most `500m`; `100m` is safe.
- Forgetting that the controller manager also owns ReplicaSet, EndpointSlice,
  and other controllers. A missing controller manager can make several
  unrelated-looking objects stop updating.
- Leaving the test Deployment behind. Cleanup will not remove it for you.

## Variant 5 - Combined migration incident

Variant 5 starts with the API down and hides several faults. Repair the API
first, then re-run triage. Do not try to edit the controller manager or
CoreDNS with `kubectl` while the API is unavailable.

### Phase 1: restore API access

Follow Variant 1 exactly:

```bash
sudo crictl ps -a --name '^etcd$' --latest
sudo crictl ps -a --name '^kube-apiserver$' --latest
sudo crictl logs --tail=100 "$(sudo crictl ps -a --name '^kube-apiserver$' --latest -q)" |
  grep -iE '2380|connection|timeout'
sudo grep -n -- '--etcd-servers' /etc/kubernetes/manifests/kube-apiserver.yaml
```

Change `--etcd-servers` to `https://127.0.0.1:2379` with the safe edit from
Variant 1. Then wait for readiness:

```bash
for i in $(seq 1 90); do
  timeout 5 kubectl get --raw='/readyz' >/dev/null 2>&1 && break
  sleep 2
done
kubectl get nodes
```

### Phase 2: repair scheduler and controller manager

```bash
kubectl -n kube-system get pods -o wide
sudo crictl ps -a --name '^kube-scheduler$' --latest
sudo crictl ps -a --name '^kube-controller-manager$' --latest
sudo grep -n -A6 'resources:' /etc/kubernetes/manifests/kube-scheduler.yaml
sudo grep -n -A8 'resources:' /etc/kubernetes/manifests/kube-controller-manager.yaml
```

Fix the scheduler with the `100m` CPU request from Variant 3. For the
controller manager, fix both resource faults:

- CPU request: `4` -> `100m`
- Memory limit: `19Mi` -> `256Mi` (or remove the limit; the validator accepts
  an absent limit or at least `128Mi`)

```bash
sudo cp /etc/kubernetes/manifests/kube-controller-manager.yaml \
  /tmp/kube-controller-manager.yaml
sudo sed -i '/^      requests:/,/^      [a-zA-Z]/ s/^        cpu:.*/        cpu: 100m/' \
  /tmp/kube-controller-manager.yaml
sudo sed -i '/^      limits:/,/^      [a-zA-Z]/ s/^        memory:.*/        memory: 256Mi/' \
  /tmp/kube-controller-manager.yaml
sudo grep -n -A8 'resources:' /tmp/kube-controller-manager.yaml
sudo install -m 600 -o root -g root /tmp/kube-controller-manager.yaml \
  /etc/kubernetes/manifests/.kube-controller-manager.yaml.q15
sudo mv /etc/kubernetes/manifests/.kube-controller-manager.yaml.q15 \
  /etc/kubernetes/manifests/kube-controller-manager.yaml
```

Wait for both components to be running:

```bash
for i in $(seq 1 60); do
  sudo crictl ps --name '^kube-scheduler$' --state Running -q | grep -q . || { sleep 2; continue; }
  sudo crictl ps --name '^kube-controller-manager$' --state Running -q | grep -q . && break
  sleep 2
done
kubectl -n kube-system get pods -o wide
```

If the controller manager starts and immediately restarts, inspect its last
state. The `19Mi` limit can cause an OOM kill even after the CPU request is
fixed.

### Phase 3: repair cluster DNS

```bash
kubectl -n kube-system get pods -l k8s-app=kube-dns -o wide
kubectl -n kube-system logs -l k8s-app=kube-dns --tail=50
kubectl -n kube-system get configmap coredns -o jsonpath='{.data.Corefile}'
```

The Corefile will contain:

```text
kubernetes wrong.local in-addr.arpa ip6.arpa {
```

Change only the cluster zone:

```bash
kubectl -n kube-system edit configmap coredns
```

Replace that line with:

```text
kubernetes cluster.local in-addr.arpa ip6.arpa {
```

Keep the existing `forward`, `cache`, and other directives unchanged. Then
restart the CoreDNS Deployment so all replicas load the corrected ConfigMap:

```bash
kubectl -n kube-system rollout restart deployment/coredns
kubectl -n kube-system rollout status deployment/coredns --timeout=120s
```

If you prefer a non-interactive edit:

```bash
kubectl -n kube-system get configmap coredns -o jsonpath='{.data.Corefile}' > /tmp/Corefile
sed -i 's/kubernetes wrong\.local/kubernetes cluster.local/' /tmp/Corefile
kubectl -n kube-system create configmap coredns \
  --from-file=Corefile=/tmp/Corefile --dry-run=client -o yaml |
  kubectl apply -f -
kubectl -n kube-system rollout restart deployment/coredns
kubectl -n kube-system rollout status deployment/coredns --timeout=120s
```

Verify DNS from the host:

```bash
KUBE_DNS_IP="$(kubectl -n kube-system get service kube-dns -o jsonpath='{.spec.clusterIP}')"
dig @"$KUBE_DNS_IP" kubernetes.default.svc.cluster.local +short
kubectl -n default get service kubernetes -o jsonpath='{.spec.clusterIP}{"\n"}'
```

The two addresses should match (typically `10.96.0.1`). If `dig` is not
installed, use `nslookup`, or run a short-lived Pod:

```bash
kubectl -n default run q15-dns-check --image=busybox:1.36 --restart=Never \
  --command -- nslookup kubernetes.default.svc.cluster.local
kubectl -n default logs q15-dns-check
kubectl -n default delete pod q15-dns-check
```

### Common mistakes

- Fixing the scheduler/controller while the API is still down. Finish Phase 1
  first.
- Lowering controller CPU but leaving the `19Mi` memory limit. The controller
  may start and then OOM.
- Editing the CoreDNS Deployment instead of the `coredns` ConfigMap.
- Changing the Corefile zone but forgetting the rollout restart.
- Fixing DNS before restoring the API and control-plane components.
- Treating a restarted add-on such as `cilium-operator` as a Q15 fault. It can
  lose leader election while the API is down and needs a few minutes to
  recover after the control plane returns.
- Leaving the temporary `q15-dns-check` Pod behind. Delete it before cleanup.

## Validate the repair

From the repository root:

```bash
scripts/validate-question.sh 15
```

Expected result: **14/14 passed, 0 failed**.

After a long API outage, other API clients can restart too. For example,
`cilium-operator` may log `Leader election lost` and enter CrashLoopBackOff
for a few minutes; it normally recovers on its own. Give add-ons a few minutes
before treating them as part of the Q15 fault. The validator focuses on the
four control-plane containers, CoreDNS, DNS, and node readiness.

If it does not pass, use this map:

| Failing check | Look at |
|---|---|
| `kube-apiserver is reachable` | API server manifest, etcd endpoint, API server logs |
| `kube-apiserver --etcd-servers is ...` | exact loopback endpoint `https://127.0.0.1:2379` |
| `... does not use peer port 2380` | remove every `2380` from the API server manifest |
| `etcd Pod is Running` | etcd container and kubelet journal |
| `all control-plane Pods are Running` | scheduler/controller containers, `crictl ps -a` |
| `kube-scheduler CPU request ...` | scheduler `resources.requests.cpu` at `200m` or less |
| `kube-controller-manager CPU request ...` | controller `resources.requests.cpu` at `500m` or less |
| `kube-controller-manager memory limit ...` | absent or at least `128Mi` |
| `CoreDNS Deployment is fully available` | CoreDNS Pods, Deployment, ConfigMap |
| `CoreDNS Corefile is valid` | `kubernetes cluster.local`, `forward`, `cache`, balanced braces |
| `cluster DNS resolves ...` | CoreDNS ConfigMap, rollout, kube-dns Service |
| `all nodes are Ready` | API/control-plane recovery, kubelet on each node |

## Clean up

Delete any smoke-test workloads you created:

```bash
kubectl delete deployment q15-scheduler-smoke --ignore-not-found
kubectl delete deployment q15-controller-smoke --ignore-not-found
kubectl delete pod q15-dns-check --ignore-not-found
```

Then restore the control-plane baseline:

```bash
scripts/cleanup-question.sh 15
```

Cleanup restores the three static control-plane manifests and the CoreDNS
Corefile from the snapshot taken by setup, waits for the API and DNS to
recover, removes `.cka-state/q15-baseline`, and clears the recorded variant.

Important:

- Cleanup does **not** delete learner-created Deployments or Pods.
- Cleanup restores only the Q15-managed files. It is not a full cluster reset.
- Do **not** delete `.cka-state/q15-baseline` while the lab is active. If
  cleanup fails, keep the baseline and retry after repairing API access.
- If the baseline is missing and the control plane is broken, use a fresh
  disposable cluster.

A final health check:

```bash
kubectl get --raw='/readyz'
kubectl get nodes
kubectl -n kube-system get pods
```

## Command cheat sheet

```bash
# API and control-plane status
timeout 5 kubectl get --raw='/readyz'
timeout 5 kubectl get --raw='/readyz?verbose'
kubectl get nodes
kubectl -n kube-system get pods -o wide
kubectl -n kube-system describe pod -l component=kube-scheduler
kubectl -n kube-system describe pod -l component=kube-controller-manager
kubectl -n kube-system get events --sort-by=.lastTimestamp | tail -30

# Containers and kubelet
sudo crictl ps -a
sudo crictl ps -a --name '^kube-apiserver$' --latest
sudo crictl ps -a --name '^kube-scheduler$' --latest
sudo crictl ps -a --name '^kube-controller-manager$' --latest
sudo crictl logs --tail=100 "<container-id>"
sudo crictl inspect "<container-id>" | grep -E 'exitCode|reason|message'
sudo journalctl -u kubelet -n 150 --no-pager

# Manifests and listeners
sudo ls -la /etc/kubernetes/manifests
sudo grep -n -- '--etcd-servers' /etc/kubernetes/manifests/kube-apiserver.yaml
sudo grep -n -A6 'resources:' /etc/kubernetes/manifests/kube-scheduler.yaml
sudo grep -n -A8 'resources:' /etc/kubernetes/manifests/kube-controller-manager.yaml
sudo ss -lntp | grep -E ':(2379|2380|6443)\b'

# etcd health
ETCD_ID="$(sudo crictl ps --name '^etcd$' --latest -q)"
sudo crictl exec "$ETCD_ID" etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  endpoint health

# DNS
kubectl -n kube-system get pods -l k8s-app=kube-dns -o wide
kubectl -n kube-system get configmap coredns -o jsonpath='{.data.Corefile}'
KUBE_DNS_IP="$(kubectl -n kube-system get service kube-dns -o jsonpath='{.spec.clusterIP}')"
dig @"$KUBE_DNS_IP" kubernetes.default.svc.cluster.local +short
```
