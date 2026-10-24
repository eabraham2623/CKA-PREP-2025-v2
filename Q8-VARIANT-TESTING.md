# Q8 variant testing — status and handoff

Last updated: 2026-10-24 (session interrupted during cleanup/restore)

Branch: `variations_temp` (base commit `dbc7984 Temp`)
Work in this document's commit: `validate.bash` + `scripts/lib/q8-cni.sh` changes,
plus this file.

## TL;DR

- Variant 1 (Calico v3.28.2) was tested end-to-end: setup, unsolved validation
  (fails), solution, solved validation (22/22 pass), negative test for the new
  BGP check.
- Two real bugs were found and fixed:
  1. `validate.bash` never verified the required `calicoNetwork.bgp: Disabled`.
  2. Calico cleanup hung forever on the Tigera `tigera.io/cni-protector`
     ServiceAccount finalizer.
- Variant 2 (VXLAN overlay / Flannel v0.26.1) has **not** been tested yet.
- The cleanup/restore test was interrupted. **The cluster currently has no
  working CNI.** The Cilium restore snapshot is intact; run cleanup to recover
  (see "Recovery" below).
- The environment NATs all node-to-node traffic. Calico VXLAN drops tunnel
  packets from the NAT addresses unless they are allowed via
  `FelixConfiguration.spec.externalNodesList`. This is not yet encoded in the
  lab; see "Open decision".

## Current cluster state

- Kubernetes v1.37.1, nodes `controlplane` and `node01` Ready.
- Pod subnet `192.168.0.0/16` (from `kubeadm-config`).
- Cilium 1.20.1 Helm release exists but its DaemonSet/operator are **not
  running** (setup removed them). `05-cilium.conflist` is absent on both nodes.
- Calico is removed (no namespaces/CRDs), but `10-calico.conflist` and
  `calico-kubeconfig` still exist in `/etc/cni/net.d` on both nodes because the
  interrupted cleanup never reached host cleanup/restore.
- Existing CoreDNS pods are still Running on their old network; new pods have
  no CNI.
- Runtime state (gitignored, not committed):
  - `.cka-state/Question-8-CNI-Network-Policy.variant` = `1`
  - `.cka-state/q8-cilium/` = Cilium 1.20.1 restore snapshot
    (`restore.env`, `values.yaml`, `manifest.yaml`).
- Helm release `cilium` is still installed (revision 1) and can be restored
  with `helm upgrade --install ... --reuse-values` from the snapshot.

## Recovery (do this first)

```bash
cd /root/CKA-PREP-2025-v2
scripts/cleanup-question.sh 8
```

With the fixed `scripts/lib/q8-cni.sh` this should remove Calico/Flannel/Canal
host files, restore Cilium from `.cka-state/q8-cilium/`, wait for readiness,
and clear the recorded variant. Verify afterwards:

```bash
kubectl -n kube-system get ds cilium cilium-envoy
kubectl -n kube-system get deploy cilium-operator coredns
kubectl get nodes
cilium status --wait          # if the cilium CLI is installed
```

If the Helm restore path fails, the snapshot also contains `manifest.yaml`,
which `cka_q8_restore_cilium` falls back to. Do **not** delete
`.cka-state/q8-cilium/` until Cilium is healthy again.

## Code changes made in this session

### 1. `Question-8-CNI-Network-Policy/validate.bash`

- Added `calico_bgp_disabled()` and the check
  `Calico BGP is Disabled`. The question requires
  `calicoNetwork.bgp: Disabled`, but the old validator accepted an install
  that left the default (`Enabled`). Negative test confirmed: setting
  `Enabled` makes exactly this check fail.
- Replaced hard-coded CNI config paths in the "active on controlplane/node01"
  checks with `/etc/cni/net.d/$CNI_CONFIG_FILE` so `variants.bash` remains the
  single source of truth. The absence checks for the *other* CNIs stay
  hard-coded on purpose.

Variant 1 now reports 22 checks (was 21). Variant 2 remains at 18 checks.

### 2. `scripts/lib/q8-cni.sh`

Root cause of the hang: the Tigera operator adds the finalizer
`tigera.io/cni-protector` to the `calico-node` and `calico-cni-plugin`
ServiceAccounts. `cka_q8_cleanup_calico` deleted the operator and then the
namespace, so nothing ever removed that finalizer. `calico-system` stayed
`Terminating` for 37+ minutes and `kubectl delete namespace --wait` never
returned.

Changes:

- New `cka_q8_calico_namespaces_remain()` helper.
- New `cka_q8_clear_calico_sa_finalizers()` helper that patches
  `metadata.finalizers` to null on ServiceAccounts in `tigera-operator`,
  `calico-system`, and `calico-apiserver`.
- `cka_q8_cleanup_calico()` now:
  - clears the SA finalizers before deleting the namespaces,
  - deletes namespaces with `--wait=false`,
  - polls for up to 180s, re-clearing finalizers each iteration,
  - warns and returns non-zero if the namespaces are still terminating, so
    cleanup can never block indefinitely.

This fix has **not yet been exercised end-to-end**; the interrupted run had
already removed the namespaces manually. Re-run the variant 1 cycle to confirm
the hang is gone.

## Test evidence so far

Logs are under `/tmp/q8-test/` (not committed):

| Step | Result |
| --- | --- |
| `bash -n` on Q8 scripts + lib | pass |
| `scripts/cleanup-question.sh 8` (baseline) | pass, "Cilium is already active" |
| `scripts/run-question.sh 8 1` | pass, prints `Variant 1/2`, summary with `podSubnet=192.168.0.0/16`, full question; snapshot saved |
| `scripts/validate-question.sh 8` before solving | exit 1, expected failures |
| Calico v3.28.2 install with `bgp: Disabled` | `tigerastatus` calico=True, calico-node 2/2, controllers 1/1 |
| `scripts/validate-question.sh 8` after solving | **22/22 pass**, exit 0 |
| Negative test: `bgp: Enabled` | `FAIL: Calico BGP is Disabled` as intended |
| `scripts/cleanup-question.sh 8` | **hung >20 min** (bug above); interrupted |
| Manual finalizer patch | `calico-system` deleted |

Not yet run:

- Cleanup after the fix (and Cilium restore verification).
- Full variant 1 re-run from a clean state.
- Entire variant 2 cycle (setup → fail → Flannel install → pass → cleanup).
- Contract checks: random no-arg variant, invalid `0`/`3`/`abc`, validation
  without state, tampered state.

## Environment findings that affect the lab

### A. Inter-node traffic is NATed (QEMU/user-mode style)

The nodes cannot ARP each other (`ip neigh` stays INCOMPLETE) and every
node-to-node flow is source-NATed:

- traffic from `controlplane` arrives at `node01` as `10.244.8.158`
- traffic from `node01` arrives at `controlplane` as `10.244.7.53`

Cilium's VXLAN works because it does not filter tunnel sources. Calico's
`cali-INPUT` chain drops VXLAN from sources not in `cali40all-vxlan-net`
(node InternalIPs), so cross-node pod traffic fails with plain Calico
(`cali-INPUT` counter for "Drop IPv4 VXLAN packets from non-allowed hosts`
increases). Manually adding the NAT IPs to the ipset works only until the next
Felix resync (reverted within ~60s).

Verified workaround:

```bash
kubectl patch felixconfiguration default --type=merge \
  -p '{"spec":{"externalNodesList":["10.244.8.158/32","10.244.7.53/32"]}}'
```

With that, pod-to-pod ping works in both directions across nodes. The
`externalNodesList` field is Calico's supported way to allow tunnel traffic
from non-Calico sources. The addresses should be discovered per environment,
not hard-coded.

**Open decision:** how to handle this in the lab. Options:

1. Leave the lab as-is (validation never tests cross-node connectivity) and add
   a short troubleshooting note to `SolutionNotes.bash` for the Calico
   profile. Minimal change, keeps variant parity.
2. Add the `externalNodesList` step to the Calico variant question, with the
   NAT addresses discovered and printed by setup. Makes connectivity genuinely
   work, but adds an environment-specific step and breaks step parity with the
   Flannel variant.
3. Automate the patch from setup (for example a reconciler waiting for the
   FelixConfiguration CRD). Most transparent to the learner, most moving parts.

Recommendation: option 1 unless the lab is expected to demonstrate real
cross-node traffic, in which case option 2.

### B. No kube-proxy: ClusterIP services do not work after Cilium is removed

`kubeadm-config` has `proxy.disabled: true`; Cilium provided kube-proxy
replacement. Once Cilium is removed, nothing programs Service VIPs, so
ClusterIP DNS (`10.96.0.10`) fails even with a working CNI. CoreDNS pods are
Running and validation only checks that (same as the original lab), but do not
claim "DNS works" in the question or notes. This is pre-existing behavior, not
a variant regression. It resolves again when cleanup restores Cilium with
`kubeProxyReplacement: true`.

### C. Calico's CIDR edit is a no-op in this cluster

Calico v3.28.2's stock `custom-resources.yaml` already uses
`cidr: 192.168.0.0/16`, which equals this cluster's pod subnet. The only
required edit for variant 1 here is `bgp: Disabled`. Variant 2 (Flannel) does
require the real edit: its stock `net-conf.json` is `10.244.0.0/16`, which must
become `192.168.0.0/16`.

## Remaining work (in order)

1. Recover the cluster with `scripts/cleanup-question.sh 8`; verify Cilium,
   nodes, CoreDNS, and Service/DNS behavior are back.
2. Re-run variant 1 from scratch with the fixed cleanup:
   `cleanup 8` → `run 8 1` → validate (must fail) → apply Calico solution →
   validate (must pass 22/22) → `cleanup 8` (must finish, no hang, Cilium
   restored).
3. Variant 2 full cycle:
   - `scripts/run-question.sh 8 2`
   - validate must fail
   - install Flannel v0.26.1 from
     `https://github.com/flannel-io/flannel/releases/download/v0.26.1/kube-flannel.yml`
     after changing `net-conf.json` `Network` from `10.244.0.0/16` to
     `192.168.0.0/16` (keep `Backend.Type: vxlan`)
   - validate must pass 18/18
   - `cleanup 8`, verify Cilium restored. Flannel has no VXLAN source filter,
     so cross-node traffic should work through the NAT without
     `externalNodesList`; confirm with a two-pod ping.
4. Contract checks:
   - no-arg `scripts/run-question.sh 8` records a valid random variant
   - `scripts/run-question.sh 8 0`, `8 3`, `8 abc` fail
   - direct `LabSetUp.bash 0/3/abc` fails
   - validation with no recorded state fails
   - tampering the recorded variant to the other preset fails validation
   - `bash -n` on every touched script
5. If the NAT workaround is adopted, update
   `Question-8-CNI-Network-Policy/variants.bash`,
   `LabSetUp.bash`, `validate.bash`, `SolutionNotes.bash`,
   `AGENTS.md`, and `README.md` accordingly.
6. Re-run `scripts/validate-question.sh all` at the end (note: the wrapper's
   `all` loop still covers only questions 1–17).

## Useful commands and files

```bash
# variant selection / state
cat .cka-state/Question-8-CNI-Network-Policy.variant
ls -la .cka-state/q8-cilium/

# current topology clues
kubectl -n kube-system get cm kubeadm-config -o jsonpath='{.data.ClusterConfiguration}'
ssh node01 'ip -4 addr; ip route'
ip route; ip -d link show vxlan.calico

# NAT discovery (examples)
ssh node01 "ss -tn | grep ':22'"        # shows controlplane as 10.244.8.158
ss -tn '( sport = :6443 )'               # shows node01 clients as 10.244.7.53

# Calico tunnel-source check
sudo iptables -L cali-INPUT -n -v | grep VXLAN
sudo ipset list cali40all-vxlan-net
```

Test artifacts downloaded to `/tmp`: `q8-flannel.yml`,
`q8-calico-cr.yaml`, and `/tmp/q8-test/*.log`.
