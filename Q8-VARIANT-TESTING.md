# Q8 variant testing — status and handoff

Last updated: 2026-10-24, end of session 2.

Branch: `variations_temp` (base commit `dbc7984 Temp`, previous session `a050107`).
Work in this document's commit: `scripts/lib/q8-cni.sh` cleanup changes plus
this file. `Question-8-CNI-Network-Policy/validate.bash` was already committed
in `a050107` and is unchanged this session.

## TL;DR

- Variant 1 (Calico v3.28.2) was tested end-to-end again this session:
  setup → unsolved validation fails → Calico install → **22/22 pass** →
  cleanup/restore. Two of three full cleanups passed; one hit the namespace
  timeout and returned rc=1 (details below).
- Variant 2 (VXLAN overlay / Flannel v0.26.1) was tested through solving:
  setup → unsolved validation fails → edited Flannel install → **22/22 pass**.
  **Variant 2 cleanup has not been run yet.**
- Two more Calico cleanup bugs were found and fixed in `scripts/lib/q8-cni.sh`:
  1. The Installation CR finalizers (`tigera.io/operator-cleanup`,
     `operator.tigera.io/apiserver-controller`) were left unowned because the
     operator was deleted first. That wedged the
     `customresourcecleanup.apiextensions.k8s.io` CRD finalizer.
  2. `kubectl delete apiservice` waited forever because the automanaged
     Tigera/Calico APIService is recreated while its CRD still exists.
- A significant cleanup defect remains: **host netfilter state is not
  cleaned**. After Calico/Flannel/Cilium cycles, `iptables-save` still holds
  `cali-*`, `CILIUM_*`, and `FLANNEL-*` rules/chains. This can affect later
  labs and must be handled by `cka_q8_remove_other_cni_host`.
- Cross-node pod-to-pod traffic does **not** work in this QEMU/NAT environment,
  even with Flannel. The lab validation does not test it today, so the labs
  still validate, but do not claim pod-to-pod connectivity works until this is
  understood or documented.
- The next session starts from a fresh state. Verify the cluster and
  `.cka-state` before trusting anything in "Current cluster state" below.

## Fresh-state warning

The environment may be reset between sessions. `/tmp`, `.cka-state/`, installed
CNIs, Helm releases, and host CNI/netfilter state can all disappear or revert.
On resume, do **not** assume variant 2/Flannel is still installed.

First commands:

```bash
cd /root/CKA-PREP-2025-v2
kubectl get nodes
kubectl -n kube-system get ds,deploy
ls -la .cka-state 2>/dev/null || echo "no .cka-state"
ls -la /etc/cni/net.d
```

If a lab CNI or `.cka-state` is left over, run `scripts/cleanup-question.sh 8`
first. If Cilium is healthy, no state exists, and nodes are Ready, start a
fresh variant cycle directly.

## Current cluster state at handoff (may be reset)

- Kubernetes v1.37.1; nodes `controlplane` and `node01` Ready.
- Pod subnet `192.168.0.0/16` (from `kubeadm-config`).
- **Variant 2 is selected and solved**: `.cka-state/Question-8-CNI-Network-Policy.variant`
  is `2`; Flannel v0.26.1 is installed and validation passes 22/22.
- Cilium is stopped (its DaemonSets/operator were removed by setup), but the
  Helm release and the restore snapshot under `.cka-state/q8-cilium/` still
  exist. `05-cilium.conflist` is absent on both nodes; `10-flannel.conflist`
  is present on both.
- CoreDNS is Running (2/2) on the Flannel network.
- Stale host netfilter state is present from earlier Calico/Cilium cycles:
  roughly 144 `cali` lines, 42 `CILIUM` lines, and 12 `FLANNEL` lines in
  `iptables-save` (counts vary).
- The `ipset` CLI is not installed, so `cali40all-vxlan-net` (referenced by a
  leftover `cali-INPUT` rule) cannot be inspected or destroyed with `ipset`.
- A temporary test pod `q8-net-test` was deleted; it may still be Terminating
  briefly.

## Test evidence this session

Logs are under `/tmp/q8-test/` (ephemeral; re-create as needed).

| Step | Result |
| --- | --- |
| `bash -n` on Q8 scripts + lib | pass |
| Baseline `scripts/cleanup-question.sh 8` (Cilium already healthy) | rc=0, ~8s, "Cilium is already active" |
| V1 setup (rerun) | rc=0, `Variant 1/2`, snapshot saved, full question printed |
| V1 validate before solving | rc=1, expected failures (9–10/22 depending on node readiness) |
| V1 Calico install (`kubectl create -f tigera-operator.yaml`, edited CR) | operator 1/1, calico-node 2/2, BGP `Disabled` |
| V1 validate after solving | **22/22 pass, rc=0** |
| V1 cleanup from a wedged/operator-less state | rc=0, 2m55s, Cilium restored |
| Cilium baseline after restore | `cilium status --wait` OK, nodes Ready, CoreDNS Running |
| DNS after Cilium restore | busybox pod resolved `kubernetes.default.svc.cluster.local` to `10.96.0.1` |
| V1 cleanup #2 (fresh, operator running) | **rc=1, 12m33s**: namespaces exceeded the 180s bound, but Cilium restored and state cleared |
| V1 cleanup #3 (fresh, traced with `bash -x`) | **rc=0, 4m08s** |
| V2 setup | rc=0, `Variant 2/2`, snapshot saved, full question printed |
| V2 validate before solving | rc=1, 9/22, expected failures |
| V2 Flannel install (v0.26.1, `Network: 192.168.0.0/16`, backend vxlan) | DS 2/2 Ready, both nodes Ready |
| V2 validate after solving | **22/22 pass, rc=0** |
| V2 cross-node pod ping | **FAIL, 100% loss both directions** |
| Manual VXLAN diagnostics | inconclusive; see environment finding A |
| V2 cleanup | **not run** |

Both profiles now report **22 checks**, not 18. The old "Variant 2 remains at
18 checks" note was wrong.

## Code changes in this session

All in `scripts/lib/q8-cni.sh`:

### 1. Graceful Calico CR cleanup (new helpers)

- `cka_q8_calico_cr_present()`: checks for Installation/APIServer CRs.
- `cka_q8_clear_calico_cr_finalizers()`: patches `metadata.finalizers` to null
  on `installations.operator.tigera.io` and `apiservers.operator.tigera.io`.
- `cka_q8_tigera_operator_running()`: operator Deployment availability.

`cka_q8_cleanup_calico()` now:

- If the operator is running, deletes the **APIServer CR first**, then the
  **Installation CR**, each with `--wait=true --timeout=120s`. The APIServer CR
  owns one of the Installation finalizers, so deleting the Installation first
  deadlocks until timeout.
- If the operator is not running, deletes both with `--wait=false` and
  force-clears their finalizers.
- Always force-clears CR finalizers and deletes any remaining CRs before
  deleting CRDs.
- Deletes Calico DaemonSets/Deployments with `--wait=false`.
- Keeps the existing namespace fix: clear the `tigera.io/cni-protector` SA
  finalizers, delete namespaces with `--wait=false`, poll up to 180s, clearing
  SA finalizers each round.

### 2. Bounded CRD cleanup

- After deleting Calico/Tigera CRDs with `--wait=false`, poll up to 120s.
- If any remain, force-clear their `customresourcecleanup.apiextensions.k8s.io`
  finalizers, wait 5s, and warn + rc=1 only if they are still present.
- This prevents the apiserver from retrying `crd_finalizer.go` every 60s
  forever (`context deadline exceeded`).

### 3. APIService deletion no longer waits

- Calico/Tigera APIServices are automanaged and recreated while the CRD still
  exists. `kubectl get apiservice ... | xargs kubectl delete` therefore waited
  forever.
- The cleanup now uses `--wait=false` for APIServices (and for ClusterRoles /
  ClusterRoleBindings).

## Bugs found and status

1. **Namespace finalizer hang** (from session 1): fixed in `a050107`; exercised
   again this session. Still one run exceeded 180s and returned rc=1.
2. **Installation CR finalizers block CRD deletion** (fixed this session):
   the operator was deleted before it could process
   `tigera.io/operator-cleanup` and `operator.tigera.io/apiserver-controller`.
   The Installation CR stayed Terminating, and the CRD finalizer retried
   forever.
3. **`kubectl delete apiservice` hang** (fixed this session): see above. A
   cleanup killed after 10 minutes stopped right after
   "Warning: Calico namespaces are still terminating"; the CRD had a
   `deletionTimestamp` and the apiserver logged repeated
   `crd_finalizer.go:309 ... context deadline exceeded`.
4. **Stale host netfilter state** (NOT fixed): `cka_q8_remove_other_cni_host`
   removes CNI files, binaries, dirs, and links, but not iptables/nftables
   chains or ipsets. Observed leftovers:
   - `cali-FORWARD`, `cali-INPUT`, `cali-OUTPUT`, `cali-from-wl-dispatch`
     (including an "Unknown interface" DROP), `cali-fw-*`, `cali-pri-*`,
     `cali-pro-*`, `cali-tw-*`, `cali-cidr-block`, etc.
   - `FLANNEL-FWD`, `FLANNEL-POSTRTG`.
   - `CILIUM_FORWARD`, `CILIUM_INPUT`, `CILIUM_OUTPUT`, and nft
     `CILIUM_*_nat` chains.
   - `iptables -t nat` has `cali-PREROUTING`, `cali-OUTPUT`; `raw` also has
     Calico hooks.
   - Be careful: do not remove `CILIUM_*` when Cilium is healthy and no other
     CNI is being removed. `cleanup.bash` calls the host-cleanup helper
     unconditionally before the health check, so the helper needs a flag or
     conditional.
5. **Intermittent namespace timeout** (NOT fixed): one fresh V1 cleanup took
   12m33s and returned rc=1 at the 180s namespace bound; a later identical
   run took 4m08s and passed. Root cause not identified. Options: raise the
   bound, clear finalizers on all namespaced resources (not just SAs), or
   force-finalize namespaces as a last resort. Do not simply remove the rc=1
   without understanding it.

## Environment findings / open decisions

### A. Cross-node VXLAN does not work here

Flannel v0.26.1 installs correctly, `flannel.1` is up, FDB and neighbor
entries are correct, but pod-to-pod ping fails 100% both directions:

- `flannel.1` TX packets increase per ping, `tx_dropped` also increases.
- No outer UDP 8472 packets appear on `enp1s0`; peer `flannel.1` RX stays 0.
- Manual VXLAN device (id 42, port 8473, explicit `remote`) showed outgoing
  packets with `udp sum ok`, while return packets from `10.244.7.183`
  (node01's NAT source) arrived with `bad udp cksum` and were dropped.
- Generic UDP between the nodes works (`nc -u` from controlplane to node01),
  so the underlay is not simply blocking UDP.
- Retesting with `noudpcsum` on the manual device still failed with
  "Destination Host Unreachable"; no capture was taken in that retest, so this
  is not yet conclusive.
- Cilium's VXLAN baseline works. Next diagnostic: while Cilium is healthy,
  compare `ip -d link show cilium_vxlan` (checksum flags) and
  `ip -s -d link show` with Flannel's device. Cilium may disable the outer
  UDP checksum or handle the QEMU offload differently.
- The `cali-*` leftovers may also interfere with Flannel, but the bad-checksum
  evidence points at the tunnel/offload path first. Clean the netfilter state,
  then retest before concluding.

Until this is resolved: do not claim cross-node pod connectivity works in the
question, solution notes, or validation. Option 1 from the original handoff
(document the limitation) remains the low-risk choice.

### B. No kube-proxy: ClusterIP/DNS does not work without Cilium

`kubeadm-config` has `proxy.disabled: true`; Cilium provided kube-proxy
replacement. With Cilium removed, ClusterIP DNS (10.96.0.10) fails even with a
working CNI. CoreDNS pods can still be Running, and validation only checks
that. Do not claim DNS works while the lab CNI is installed. DNS works again
after cleanup restores Cilium with `kubeProxyReplacement: true` (verified this
session with a busybox `nslookup`).

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

## Remaining work (in order)

1. **Fresh-state sanity**: check nodes, Cilium, `/etc/cni/net.d`, and
   `.cka-state`. Clean up any leftover lab CNI before starting.
2. **Implement host netfilter cleanup** in `cka_q8_remove_other_cni_host`:
   - remove `cali*` and `FLANNEL-*` iptables rules/chains (filter, nat, raw,
     mangle as needed) and matching nft rules;
   - remove `cni0` and leftover routes after Flannel;
   - remove `CILIUM_*` rules only when tearing down another CNI before a
     restore, never when Cilium is healthy and retained;
   - delete ipsets when the `ipset` CLI exists;
   - verify with `iptables-save | grep -cE 'cali|FLANNEL|CILIUM'` and
     `nft list ruleset`.
3. **Finish the variant 2 cycle**: `scripts/cleanup-question.sh 8` from the
   current solved state (or re-create it), verify Cilium restore, nodes Ready,
   CoreDNS Running, no stale rules, `.cka-state` cleared.
4. **Re-run variant 1 end-to-end** with netfilter cleanup: `cleanup 8` →
   `run 8 1` → validate fails → Calico → 22/22 → `cleanup 8` rc=0 and clean
   host. Repeat enough to catch the intermittent namespace timeout.
5. **Decide the cross-node connectivity story**: diagnose Cilium vs Flannel
   VXLAN checksum behavior. Then either document the limitation (recommended
   for this environment) or add a workaround. If the lab changes, update
   `variants.bash`, `LabSetUp.bash`, `validate.bash`, `SolutionNotes.bash`,
   `AGENTS.md`, and `README.md`.
6. **Contract checks**:
   - no-arg `scripts/run-question.sh 8` records a valid random variant;
   - `scripts/run-question.sh 8 0`, `8 3`, `8 abc` fail;
   - direct `LabSetUp.bash 0/3/abc` fails;
   - validation with no recorded state fails;
   - tampering the recorded variant to the other preset fails validation;
   - `bash -n` passes on every touched script.
7. Run `scripts/validate-question.sh all` at the end. Note: the wrapper's
   `all` loop still covers only questions 1–17, so target Q18/Q19 explicitly
   if needed.

## Useful commands and files

```bash
# state and topology
cat .cka-state/Question-8-CNI-Network-Policy.variant 2>/dev/null
ls -la .cka-state/q8-cilium/
kubectl get nodes
kubectl -n kube-system get ds,deploy
ls -la /etc/cni/net.d
ssh node01 'ls -la /etc/cni/net.d'

# stale netfilter inspection
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
`02-v1-setup`, `03-v1-unsolved`, `13-v1-solved`, `14-v1-cleanup` (10m hang),
`15-v1-cleanup-fixed`, `20`–`26` (V1 rerun), `30`–`35` (debug),
`40`–`45` (V1 cycle 3), `50`–`53` (V2), and `84`–`90` (VXLAN diagnostics).
These are not committed and may be gone after a reset.
