# Q8 variant testing — status and handoff

Last updated: 2026-10-24, end of session 3.

Branch: `variations_temp`. This session's changes: `scripts/lib/q8-cni.sh`,
`Question-8-CNI-Network-Policy/{LabSetUp,cleanup,Questions}.bash`, `AGENTS.md`,
and this file. `validate.bash` and `variants.bash` are unchanged from
`a050107`.

## TL;DR

- Both variants pass end-to-end with the final code:
  setup → unsolved validation fails → install the selected CNI →
  **22/22 pass** → cleanup → Cilium restored.
- **Host netfilter cleanup is implemented and verified.** After setup and
  after cleanup, both nodes have zero `cali`/`FLANNEL` rules; setup also
  removes stale `CILIUM_*` rules before the new CNI is installed. A healthy
  Cilium keeps its `CILIUM_*` chains (see the `--with-cilium` contract).
- Calico's node annotations are now removed during cleanup.
- The intermittent namespace timeout from session 2 did not recur in four
  cleanups this session (45 s – 2 m 04 s).
- **Cross-node pod traffic still fails in this QEMU/NAT environment**, even
  with clean netfilter state. This is an environment limitation, not a lab
  bug; validation deliberately does not test it. The question text no longer
  claims it is exercised.
- The next session starts from a fresh state. Verify the cluster and
  `.cka-state` before trusting anything in "Current cluster state" below.

## Fresh-state warning

The environment may be reset between sessions. `/tmp`, `.cka-state/`, installed
CNIs, Helm releases, and host CNI/netfilter state can all disappear or revert.
On resume, do **not** assume a lab CNI is still installed.

First commands:

```bash
cd /root/CKA-PREP-2025-v2
kubectl get nodes
kubectl -n kube-system get ds,deploy
ls -la .cka-state 2>/dev/null || echo "no .cka-state"
ls -la /etc/cni/net.d
iptables-save | grep -cE 'cali|FLANNEL|CILIUM'
```

If a lab CNI or `.cka-state` is left over, run `scripts/cleanup-question.sh 8`
first. If Cilium is healthy, no state exists, and nodes are Ready, start a
fresh variant cycle directly.

## Current cluster state at handoff

- Kubernetes v1.37.1; nodes `controlplane` and `node01` Ready.
- Pod subnet `192.168.0.0/16` (from `kubeadm-config`).
- No variant is recorded; `.cka-state` does not exist.
- Cilium 1.20.1 is healthy (`cilium` and `cilium-envoy` DaemonSets 2/2,
  operator 1/1). CoreDNS is 2/2 Running and DNS resolution works.
- No Calico, Flannel, or Canal namespaces, CRDs, annotations, CNI configs,
  interfaces, or netfilter rules remain on either node.
- `CILIUM_*` chains are present again on both nodes (3 chains each), created
  by the restored Cilium.
- The `ipset` CLI is not installed, so ipset cleanup is best-effort.

## Test evidence this session

Logs are under `/tmp/q8-test/` (ephemeral; re-create as needed).

| Step | Result |
| --- | --- |
| `bash -n` on Q8 scripts + lib + wrappers | pass |
| Baseline cleanup (Cilium healthy, no state) | rc=0, 4.5 s, `CILIUM_*` chains kept |
| Netfilter unit test with dummy `cali-*`/`FLANNEL-*` chains | removed all dummy chains, kept `CILIUM_*` intact |
| `cka_q8_remove_other_cni_host --bogus` | rejected with rc=1 |
| V1 setup | rc=0, `Variant 1/2`, snapshot saved, full question printed |
| V1 host state after setup | 0 `cali`/`FLANNEL`/`CILIUM` lines on both nodes |
| V1 validate before solving | rc=1, 10/22 (expected failures) |
| V1 Calico install (`kubectl create` + edited CR) | operator 1/1, calico-node 2/2, BGP `Disabled` |
| V1 validate after solving | **22/22 pass, rc=0** |
| V1 cleanup #1 | rc=0, 1 m 16 s; Cilium restored; 0 leftovers; DNS OK |
| V2 setup | rc=0, `Variant 2/2`; 0 netfilter leftovers on both nodes |
| V2 validate before solving | rc=1, 10/22 |
| V2 Flannel install (v0.26.1, network 192.168.0.0/16, vxlan) | DS 2/2 Ready |
| V2 validate after solving | **22/22 pass, rc=0** (20/22 on the first run, see timing note) |
| V2 cross-node pod ping | **FAIL, 100% loss both directions** |
| V2 cleanup | rc=0, 45 s; Cilium restored; 0 leftovers |
| V1 cycle 2 setup/validate | rc=0 / 10/22 expected failures |
| V1 cycle 2 Calico install + validate | **22/22 pass, rc=0** |
| V1 cycle 2 cleanup | rc=0, 2 m 04 s; annotations cleared; 0 leftovers |
| No-arg `run-question.sh 8` | selected + recorded variant 2, printed its question |
| `run-question.sh 8 0/3/abc/-1/"1 2"` | all rejected, no state written |
| Direct `LabSetUp.bash 0/3/abc` | all rejected |
| Validate with no recorded state | rc=1, "no variant recorded ... run setup first" |
| Tamper test (Flannel solved, state changed 2→1) | rc=1, `Variant: 1/2`, 8/22 (14 failures) |
| V2 cleanup after tamper test | rc=0, 58 s; 0 leftovers |
| `scripts/validate-question.sh all` | no crashes; expected failures because labs are not set up |
| Q18 / Q19 validators run explicitly | no crashes; expected failures |

Timing note: immediately after the Flannel DaemonSet rollout, `controlplane`
briefly reported `NetworkPluginNotReady`; validation run at that instant saw
20/22. About 18 s later both nodes were Ready and validation was 22/22. This
is normal kubelet/containerd CNI-config pickup, not a lab defect.

Both profiles report **22 checks**.

## Code changes this session

All in `scripts/lib/q8-cni.sh` unless noted.

### 1. Host netfilter cleanup (fixes session 2 bug 4)

`cka_q8_remove_other_cni_host [--with-cilium]` now runs a root script on the
local node and `node01` that:

- deletes Calico/Flannel/Canal CNI configs, binaries, state dirs, and
  `vxlan.calico`/`flannel.1`/`tunl0`/`cni0`/`cali*` interfaces;
- deletes `/var/lib/cni/networks/{cni0,flannel}` (Flannel's bridge/host-local
  state);
- for `filter`, `nat`, `mangle`, and `raw` in both `iptables` and `ip6tables`:
  removes every rule that jumps to a `cali*`, `FLANNEL*`, or (optionally)
  `CILIUM*` chain or carries a `cali:`/`cilium:` comment, then flushes and
  deletes those chains;
- destroys `cali*` ipsets (and `cilium*` with `--with-cilium`) when the
  `ipset` CLI exists;
- verifies the result and exits nonzero if `cali`/`FLANNEL` (plus `CILIUM`
  when requested) state remains.

The `--with-cilium` contract matters:

- `LabSetUp.bash` calls it **with** `--with-cilium`, after `cka_q8_stop_cilium`,
  so the old Cilium rules cannot interfere with the newly installed CNI.
- `cleanup.bash` computes `CILIUM_ACTIVE` before deleting anything. If Cilium
  is healthy it is retained and the helper runs **without** the flag; if
  Cilium will be reinstalled from the snapshot, the flag purges stale Cilium
  rules first.
- Never pass `--with-cilium` while a healthy Cilium is being kept.

Implementation notes:

- References to a target chain are removed before the chain is flushed and
  deleted; otherwise `iptables -X` fails with "Too many links".
- Rule deletion uses the canonical `iptables-save` text via `eval`, because
  quoted comments contain spaces and would not survive word splitting.
- On this image `iptables` is `iptables-nft`, so deleting via the iptables
  compatibility layer also removes the corresponding nft chains.

### 2. Calico node annotation cleanup

`cka_q8_cleanup_calico()` now removes
`projectcalico.org/IPv4Address`, `IPv6Address`, `IPv4IPIPTunnelAddr`, and
`IPv4VXLANTunnelAddr` from all nodes. They previously survived cleanup and
were visible to Flannel's subnet manager.

### 3. `Questions.bash` wording

The generic study text no longer states that cross-node pod-to-pod
communication is exercised. It now says the pod network must be configured and
Ready on every node, and notes that cross-node traffic is not tested in this
environment.

### 4. `cleanup.bash` ordering

Cilium health is sampled once, before CNI removal, and reused for both the
host-cleanup mode and the restore decision. This avoids a race where the
health check runs after the helper and sees a different state.

## Prior fixes still in place

From session 2 (`scripts/lib/q8-cni.sh`):

- APIServer CR is deleted before the Installation CR while the operator is
  running, so the operator can clear its own finalizers.
- CR finalizers are force-cleared when the operator is not running.
- CRD deletion is bounded; `customresourcecleanup` finalizers are force-cleared
  if the CRDs are still present after 120 s.
- APIServices are deleted with `--wait=false` because they are automanaged and
  recreated while their CRD exists.
- Calico namespace deletion is bounded at 180 s with repeated clearing of
  `tigera.io/cni-protector` service-account finalizers.

From session 1 (`a050107`):

- Namespace finalizer handling and the 22-check validator for both profiles.

## Bugs / limitations status

1. **Namespace finalizer hang** — fixed in `a050107`; one 12 m 33 s rc=1 run
   occurred in session 2, but four cleanups this session passed in 45 s–2 m 04 s.
   Not reproduced. If it recurs, capture `kubectl get ns -o yaml` and
   `kubectl get events -A` before the timeout.
2. **Installation CR finalizers block CRD deletion** — fixed session 2.
3. **`kubectl delete apiservice` hang** — fixed session 2.
4. **Stale host netfilter state** — fixed this session; verified zero
   `cali`/`FLANNEL` lines and zero nft chains after cleanup on both nodes.
5. **Calico node annotations** — fixed this session.
6. **Cross-node pod traffic** — environment limitation, see below.

## Environment findings / open decisions

### A. Cross-node VXLAN does not work here

Confirmed again this session with a clean netfilter state:

- Underlay ICMP between `172.30.1.2` (controlplane) and `172.30.2.2`
  (node01) works with 0% loss.
- Flannel `flannel.1` is up on both nodes with VNI 1, port 8472, MTU 1400,
  `udpcsum`, and correct FDB/neighbor entries.
- Pod ping fails 100% in both directions (`192.168.0.4` ↔ `192.168.1.2`).
- `flannel.1` TX packets increase and `tx_dropped` increases; RX stays 0.
- A capture on controlplane's `enp1s0` shows outgoing VXLAN packets, but
  tcpdump marks the outer UDP checksum as bad. A capture on node01 sees no
  encapsulated packets during the same ping.
- Session 2's manual VXLAN test showed return packets arriving from node01's
  NAT source with `bad udp cksum` and being dropped. The underlay itself is
  not blocking generic UDP.

Conclusion: the QEMU/NAT path does not carry the VXLAN outer checksum
correctly. Cilium's VXLAN baseline works, so the difference is likely in how
Cilium handles the outer checksum/offload. A possible experiment (not done) is
`iptables -t mangle -A POSTROUTING -p udp --dport 8472 -j CHECKSUM
--checksum-fill` on both nodes to force software checksums, then retest. This
should not be added to the lab task: the learner's job is to install a CNI,
not to work around the playground's NAT.

Until this is understood or worked around: do not claim cross-node pod
connectivity works in the question, solution notes, or validation. The
validation intentionally checks CNI readiness, node readiness, and CoreDNS,
not pod-to-pod traffic.

### B. No kube-proxy: ClusterIP/DNS does not work without Cilium

`kubeadm-config` has `proxy.disabled: true`; Cilium provided kube-proxy
replacement. With Cilium removed, ClusterIP DNS (10.96.0.10) fails even with a
working CNI. CoreDNS pods can still be Running, and validation only checks
that. Do not claim DNS works while the lab CNI is installed. DNS works again
after cleanup restores Cilium with `kubeProxyReplacement: true` (verified this
session with a busybox `nslookup` → `10.96.0.1`).

### C. Calico CIDR edit is a no-op here

Calico v3.28.2's stock `custom-resources.yaml` already uses
`cidr: 192.168.0.0/16`, equal to this cluster's pod subnet. The only required
edit for variant 1 here is `bgp: Disabled`. Flannel still needs the real edit:
its stock `net-conf.json` is `10.244.0.0/16` and must become `192.168.0.0/16`.

### D. `kubectl apply` fails for tigera-operator.yaml

`kubectl apply -f tigera-operator.yaml` fails with
`metadata.annotations: Too long: may not be more than 262144 bytes`. Use
`kubectl create -f tigera-operator.yaml`, which is what `SolutionNotes.bash`
already says. A partial `kubectl apply` leaves resources behind and makes a
later server-side apply report conflicts; start clean if that happens.

Also allow a few seconds for the `installations.operator.tigera.io` CRD to be
established before applying `custom-resources.yaml`; applying immediately can
fail with `no matches for kind "Installation"`.

## Remaining work

Nothing is blocking. Optional follow-ups:

1. Test the `CHECKSUM --checksum-fill` hypothesis for cross-node traffic and,
   only if it is clean and does not change the task, decide whether to mention
   it in the environment notes. Do not add it to the lab requirements.
2. If the intermittent namespace timeout recurs, capture namespace and event
   state at the 180 s bound before changing the bound or finalizer logic.
3. `validate-question.sh all` and `cleanup-question.sh all` still hard-code
   `seq 1 17`; target Q18/Q19 explicitly until those loops are fixed.
4. Re-run the Q8 contract checks after any future edit to the helper or
   wrappers (see the table above for the expected outcomes).

## Useful commands and files

```bash
# state and topology
cat .cka-state/Question-8-CNI-Network-Policy.variant 2>/dev/null
ls -la .cka-state/q8-cilium/
kubectl get nodes
kubectl -n kube-system get ds,deploy
ls -la /etc/cni/net.d
ssh node01 'ls -la /etc/cni/net.d'

# netfilter inspection / verification
iptables-save | grep -E 'cali|FLANNEL|CILIUM' | head
iptables -S FORWARD
iptables -t nat -S | grep -i cali
nft list ruleset | grep -iE 'cali|flannel|cilium'
command -v ipset && ipset list -n | grep -i cali

# Calico cleanup state
kubectl get installation,apiservers.operator.tigera.io -A
kubectl get crd | grep -E 'projectcalico|tigera'
kubectl get ns | grep -E 'calico|tigera'

# cross-node test (two pods pinned to nodes)
kubectl run q8-ping-cp --image=busybox:1.36 --restart=Never \
  --overrides='{"spec":{"nodeName":"controlplane"}}' --command -- sleep 600
kubectl run q8-ping-n1 --image=busybox:1.36 --restart=Never \
  --overrides='{"spec":{"nodeName":"node01"}}' --command -- sleep 600
# then: kubectl exec q8-ping-cp -- ping -c 4 <n1-pod-ip>

# VXLAN diagnostics
ip -d link show flannel.1
ip -s -d link show flannel.1
bridge fdb show dev flannel.1
ip neigh show dev flannel.1
tcpdump -ni enp1s0 -nn -vv 'udp port 8472'
```

Downloaded manifests and test logs are under `/tmp/q8-test/`:
`v1-setup`, `v1-unsolved`, `v1-solved`, `v1-cleanup`, `v2-setup`,
`v2-unsolved`, `v2-solved`, `v2-cleanup`, `v1-cycle2-*`, `random-setup`,
`tamper-*`, `no-state-validate`, `validate-all`, plus the tcpdump captures.
These are not committed and may be gone after a reset.
