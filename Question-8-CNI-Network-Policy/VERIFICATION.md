# Question 8 — Manual Verification: CNI and NetworkPolicy

> **Disposable cluster only.** Run `scripts/run-question.sh 8` (or
> `LabSetUp.bash`). It removes Cilium and its state from this node and
> `node01`. Cleanup does **not** restore Cilium, and a node restart may be
> required. Never run this lab on a shared or production cluster.
>
> This question has no variants. The task is to install a CNI that provides pod
> connectivity **and** NetworkPolicy enforcement, from a manifest.

## What success looks like

A CNI is installed from a manifest, all nodes are Ready, pods can communicate
across nodes, and a NetworkPolicy actually blocks traffic that it should block.
Calico/Tigera is the realistic passing choice here because Flannel alone does
not enforce NetworkPolicy.

## 60-second review

- [ ] The CNI pods are Running.
- [ ] All nodes are Ready.
- [ ] CoreDNS is Running and can resolve names.
- [ ] Pods on different nodes can reach each other.
- [ ] A default-deny policy actually blocks traffic.
- [ ] The install came from a manifest, not only from a package or a preloaded
      CNI.

## Detailed checks

### 1. Check node and CNI health

```bash
kubectl get nodes -o wide
kubectl get pods -A | grep -Ei 'calico|tigera|coredns'
kubectl get tigerastatus 2>/dev/null || true
```

Expected:

- both nodes are `Ready`;
- Calico/Tigera components are Running;
- CoreDNS pods are Running;
- `kubectl get tigerastatus` shows the Calico components as `Available` (if
  the Tigera operator is installed).

A single Running `tigera-operator` pod is not enough. The node-level Calico
pods and the CNI configuration on each node must be healthy for pod traffic to
work.

### 2. Check the node CNI configuration

On the control plane:

```bash
ls -l /etc/cni/net.d/
ip -br address | grep -Ei 'cali|tunl|vxlan'
```

On `node01`:

```bash
ssh node01 'ls -l /etc/cni/net.d/; ip -br address | grep -Ei "cali|tunl|vxlan"'
```

Expected: a Calico CNI config file and a Calico interface (for example
`cali...`, `tunl0`, or `vxlan.calico`). If the config directory is empty or
still points at Cilium, the CNI is not installed correctly.

### 3. Prove cross-node pod connectivity

Create a server on `node01` and a client on the control plane:

```bash
kubectl create namespace cni-verify --dry-run=client -o yaml | kubectl apply -f -
kubectl -n cni-verify run server --image=nginx:stable --port=80 \
  --overrides='{"spec":{"nodeSelector":{"kubernetes.io/hostname":"node01"}}}'
kubectl -n cni-verify expose pod server --port=80
kubectl -n cni-verify run client --image=busybox:stable --restart=Never \
  --overrides='{"spec":{"nodeSelector":{"kubernetes.io/hostname":"controlplane"},"tolerations":[{"key":"node-role.kubernetes.io/control-plane","operator":"Exists","effect":"NoSchedule"}]}}' \
  -- wget -qO- -T 3 http://server
kubectl -n cni-verify wait --for=jsonpath='{.status.phase}'=Succeeded pod/client --timeout=60s || true
kubectl -n cni-verify logs client
```

Expected: the client logs the nginx welcome page, proving cross-node pod
networking. Substitute your node names if they differ. The control-plane
toleration in the override is required because the control-plane node is
normally tainted; without it, the client pod stays Pending.

If the server is not Running, check that it actually landed on `node01` with
`kubectl -n cni-verify get pod server -o wide`. If the client times out, check
the Calico pod logs and the node CNI config before assuming the manifest is
wrong.

### 4. Prove NetworkPolicy enforcement

Still in `cni-verify`, apply a default-deny ingress policy:

```bash
kubectl -n cni-verify apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
EOF
kubectl -n cni-verify run deny-client --image=busybox:stable --restart=Never \
  -- wget -qO- -T 3 http://server
kubectl -n cni-verify wait --for=jsonpath='{.status.phase}'=Succeeded pod/deny-client --timeout=20s || true
kubectl -n cni-verify logs deny-client
```

Expected: the request times out or fails. This is the behavior that separates a
policy-capable CNI from a connectivity-only CNI.

Remove the policy and confirm traffic returns:

```bash
kubectl -n cni-verify delete networkpolicy deny-all
kubectl -n cni-verify delete pod client deny-client --ignore-not-found
kubectl -n cni-verify run allow-client --image=busybox:stable --restart=Never \
  -- wget -qO- -T 3 http://server
kubectl -n cni-verify wait --for=jsonpath='{.status.phase}'=Succeeded pod/allow-client --timeout=60s || true
kubectl -n cni-verify logs allow-client
```

Expected: the nginx page is returned again.

If you installed Flannel, the cross-node test may pass but the deny test will
not block traffic. Flannel by itself does not implement NetworkPolicy, so it
does not satisfy this task's enforcement requirement.

### 5. Clean up the test namespace

```bash
kubectl delete namespace cni-verify --ignore-not-found
```

## Common false positives

| Symptom | Likely cause |
|---|---|
| Operator pod Running, but no node CNI pods | Only the Tigera operator manifest was applied; the custom resources/installation were not |
| Nodes NotReady | CNI config missing or stale Cilium files remain |
| CoreDNS Pending | Pod networking is not working |
| Cross-node test fails | Pod CIDR mismatch, CNI config missing on one node, or routing/firewall issue |
| Policy test does not block | CNI does not enforce NetworkPolicy, or the policy was applied in the wrong namespace |
| `kubectl get tigerastatus` not found | Calico operator is not installed, or the CRDs are missing |

## Cleanup

```bash
scripts/cleanup-question.sh 8
```

Cleanup removes lab leftovers but does not restore Cilium. Plan to rebuild or
restart the disposable cluster after this lab.
