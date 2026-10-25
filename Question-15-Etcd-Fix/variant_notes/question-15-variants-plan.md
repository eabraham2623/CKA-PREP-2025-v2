# Question 15 — Proposed Variants from the Deep-Research Notes

Status: **proposed plan — not implemented**

Source reviewed: `Question-15-Etcd-Fix/variant_notes/deep-research-report.md`

## 1. What the research actually supports

The report separates exam evidence into tiers. The parts that are strong enough to build exam-relevant variants from are:

| Evidence | Reported fault | Source |
|---|---|---|
| Tier 1, repeated | kube-apiserver `--etcd-servers` points at etcd peer port `2380` instead of client port `2379` | S1–S5 (report lines 15–19) |
| Tier 1, repeated | kube-apiserver still points at the old external etcd IP after migration to local etcd | S1–S3 (lines 15–17) |
| Tier 1, repeated | kube-scheduler static Pod has an excessive CPU request (`1999m` on a 2-core node), so it is Pending | S1, S2 (lines 15–16) |
| Tier 1, repeated | kube-controller-manager static Pod has resources that make it unschedulable or unstable (`19Mi` memory limit; `4` CPU request) | S1, S2 (lines 15–16) |
| Tier 1, combined | Real exam tasks bundled several control-plane faults; after fixing etcd, candidates found scheduler/controller and DNS problems | lines 31, 53–61 |
| Weaker / unresolved | CoreDNS ConfigMap was reported wrong by two candidates, but neither finished fixing it; the exact fault is not known | lines 15–16, 59, 157 |

Deliberately **not** selected because the report found no direct exam evidence:

- etcd TLS/certificate mismatch
- kubelet/Node NotReady
- CNI/NetworkPolicy DNS failures
- static Pod mount errors
- scheduler config-path typos

These are marked Tier 5 / hypothetical in the report. They are useful study topics, but they would not be honest “captured by the research” variants.

## 2. Recommended five-variant set

This set covers every Tier 1 fault family and ends with a combined incident matching the shape of the real reports.

| Variant | Scenario | Injected fault(s) | Correct fix | Evidence |
|---|---|---|---|---|
| 1 | Etcd peer port | `--etcd-servers=https://127.0.0.1:2380` | Change to `https://127.0.0.1:2379` | S1–S5 |
| 2 | Stale external etcd | `--etcd-servers=https://192.0.2.100:2379` (old external endpoint) | Change to local `https://127.0.0.1:2379` | S1–S3 |
| 3 | Scheduler starvation | `kube-scheduler.yaml` `requests.cpu: 1999m` on a 1-core control-plane node | Lower to a schedulable request (e.g. `25m`–`100m`) | S1, S2 |
| 4 | Controller starvation | `kube-controller-manager.yaml` `requests.cpu: 4` (4000m) | Lower to a schedulable request (e.g. `25m`–`100m`) | S2 |
| 5 | Full migration incident | Etcd peer port + scheduler `1999m` + controller `19Mi` memory limit + malformed CoreDNS Corefile | Repair all faults; all `kube-system` Pods must be Running and DNS must resolve | S1 + S2 composite |

### Why these five

- Variants 1 and 2 are the strongest and most repeated exam reports.
- Variants 3 and 4 isolate the secondary faults that S1/S2 found after fixing etcd.
- Variant 5 mirrors the actual multi-fault shape: API down first, then additional faults become visible.
- CoreDNS appears only in Variant 5 because the report never identifies the exact exam ConfigMap error. The proposed fault is a clearly defined training substitute (invalid Corefile), not a claim about the real exam.

## 3. Difficulty / repository-contract caveat

`AGENTS.md` requires variant presets to stay at equal difficulty and says not to vary the required control-plane component. The recommended set is intentionally a **progression**, not five equal-difficulty presets:

- V1–V2: one API-server fault, node-level diagnosis, short.
- V3–V4: one static-Pod resource fault, API remains up.
- V5: four faults and a longer repair.

The user asked for five variants, which also exceeds the repository’s default guidance of 2–4 presets. Both are explicit user choices, but they should be recorded in `AGENTS.md` when implemented.

If strict equal difficulty is required instead, the alternative is five presets of the same shape, all with an etcd endpoint fault plus exactly one secondary fault. That would be more uniform but would lose the single-fault drills and the combined capstone.

## 4. Learner-visible questions

The setup should print the selected variant and the full question. Proposed wording below deliberately gives the incident context, not the exact file/line, so the learner still has to diagnose. The existing Q15 wording can be retained for Variant 1 if continuity is preferred.

### Variant 1 — Etcd peer port

> The control plane is down after a migration from external HA etcd to local etcd. The kube-apiserver is not starting. Inspect the control-plane static Pods and their manifests, identify why the API server cannot reach etcd, and repair it.
>
> Success: `kubectl get nodes` works and all control-plane Pods in `kube-system` are Running.

### Variant 2 — Stale external etcd endpoint

> The control plane is down after a migration from external HA etcd to local etcd. The kube-apiserver still uses the old external etcd endpoint. Diagnose the static Pod failure and point the API server at the correct local etcd client endpoint.
>
> Success: `kubectl get nodes` works and all control-plane Pods in `kube-system` are Running.

### Variant 3 — Scheduler starvation

> `kubectl` works, but new Pods remain Pending and Deployments do not produce Running replicas. The kube-scheduler static Pod is not Running. Inspect its manifest and correct the resource configuration without changing the scheduler’s intended function.
>
> Success: `kube-scheduler-<node>` is Running and a test Deployment gets its replicas scheduled.

### Variant 4 — Controller-manager starvation

> `kubectl` works, but Deployments and ReplicaSets do not reconcile. The kube-controller-manager static Pod is not Running. Inspect its manifest and correct the resource configuration without changing the controller-manager’s intended function.
>
> Success: `kube-controller-manager-<node>` is Running and a test Deployment/ReplicaSet reconciles.

### Variant 5 — Full migration incident

> The cluster was migrated and is broken in several ways. The API server is down. After restoring API access, additional control-plane and DNS faults become visible. Diagnose and repair every fault.
>
> Success: `kubectl get nodes` works, all `kube-system` Pods are Running, and cluster DNS resolves `kubernetes.default.svc.cluster.local`.

## 5. Setup implementation details

### New file: `Question-15-Etcd-Fix/variants.bash`

Follow the existing contract:

- `VARIANT_COUNT=5`
- `variant_config <n>` sets every variant-specific value and `VARIANT_SUMMARY`
- `variant_question <n>` prints the full question above
- Fixed values shared across presets: namespace `kube-system`, manifest directory `/etc/kubernetes/manifests`, local etcd endpoint `https://127.0.0.1:2379`, baseline scheduler/controller CPU request `25m`, node name discovered from `kubectl get nodes`.

Suggested variables:

```bash
ETCD_LOCAL_ENDPOINT="https://127.0.0.1:2379"
ETCD_PEER_ENDPOINT="https://127.0.0.1:2380"
ETCD_STALE_ENDPOINT="https://192.0.2.100:2379"
SCHEDULER_BAD_CPU="1999m"
CONTROLLER_BAD_CPU="4"
CONTROLLER_BAD_MEMORY="19Mi"
```

Variant map:

| Variant | Etcd fault | Scheduler fault | Controller fault | CoreDNS fault |
|---|---|---|---|---|
| 1 | peer port | none | none | none |
| 2 | stale external IP | none | none | none |
| 3 | none | `1999m` | none | none |
| 4 | none | none | `4` CPU | none |
| 5 | peer port | `1999m` | `19Mi` memory limit | malformed Corefile |

### Baseline snapshot and reset

The current `LabSetUp.bash` copies the broken manifest to `/root/kube-apiserver.yaml.bak`; rerunning setup would overwrite the only good backup with an already-broken file. Variants need a **pristine baseline**:

```
.cka-state/q15-baseline/
  kube-apiserver.yaml
  kube-scheduler.yaml
  kube-controller-manager.yaml
  Corefile
  READY
```

Flow:

1. Parse/select the variant with `cka_variant_select`.
2. If `.cka-state/q15-baseline/READY` exists, restore from it.
3. If no baseline exists, verify the cluster is healthy first:
   - API `/readyz` works
   - etcd, kube-apiserver, kube-scheduler, kube-controller-manager are Running
   - CoreDNS is Available
4. If healthy, copy the four managed files and write `READY` last.
5. If unhealthy and no baseline exists, **fail closed**: explain that setup cannot safely snapshot a broken cluster and make no changes.
6. After restoring the baseline, wait for the control plane and CoreDNS to become healthy.
7. Apply the selected fault(s), with the etcd endpoint fault applied **last** so the setup script can still use `kubectl` for the other faults.
8. Wait for the expected symptom with a bounded timeout, then print diagnostics and the variant question.

The same restore function should be shared by setup and cleanup to avoid drift.

### Applying faults

- **Etcd peer port / stale endpoint:** edit the single `- --etcd-servers=` line in `kube-apiserver.yaml`. Prefer an anchored `sed` or a small Python YAML edit over a global `:2379` replacement.
- **Scheduler CPU / controller CPU-memory:** use Python with the `yaml` module if available (it is present in the current environment), with a `sed`/`awk` fallback for the fixed `resources.requests.cpu` shape. Do not depend on `kubectl edit` for static Pods.
- **CoreDNS:** replace the `Corefile` key with a malformed but recoverable version (for example, remove the closing brace of the `.:53` block or add an invalid plugin line). Then restart the CoreDNS Deployment so the bad config is loaded.
- **Combined variant:** apply scheduler/controller/CoreDNS faults first, then the API-server fault.

### Waiting for symptoms

- Etcd variants: wait until `/readyz` fails and the API server container is not Running; print `crictl ps -a | grep kube-apiserver` and the last log lines.
- Scheduler/controller variants: wait until the static Pod is Pending or CrashLoopBackOff; print `kubectl -n kube-system get pods` and `kubectl describe pod`.
- CoreDNS: wait until CoreDNS Pods are not Ready; print `kubectl -n kube-system logs` for one CoreDNS Pod.
- Use bounded retries. Never leave setup hanging indefinitely.

## 6. Validation plan

`validate.bash` must read the recorded variant with `cka_variant_read`, call `variant_config`, print the expected values, and assert the selected variant’s exact semantics. Missing/tampered state is a hard failure.

Every variant should run the same broad check set, with variant-specific expectations:

1. **API server reachable:** `kubectl get --raw='/readyz'` succeeds; `kubectl get nodes` works.
2. **Etcd endpoint:** `--etcd-servers=https://127.0.0.1:2379`; no `:2380` and no stale external address.
3. **Etcd Pod:** Running.
4. **Scheduler:** static Pod Running; `requests.cpu` is at or below the acceptable threshold (e.g. `<= 200m`), not the injected value.
5. **Controller-manager:** static Pod Running; CPU request is at or below the threshold; memory limit is absent or at least `128Mi` in Variant 5.
6. **CoreDNS:** ConfigMap `Corefile` is valid and contains the expected `kubernetes`, `forward`, and `cache` directives; CoreDNS Pods are Ready.
7. **All control-plane Pods:** etcd, kube-apiserver, kube-scheduler, kube-controller-manager are Running.
8. **DNS (Variant 5 and optionally all variants):** a temporary Pod resolves `kubernetes.default.svc.cluster.local`; delete the Pod afterward.
9. **Nodes:** all nodes Ready.

For V1/V2, the secondary components are expected to match the baseline; they should still be checked so a learner cannot “fix” etcd by breaking something else. For V3/V4, the etcd endpoint must remain correct.

Avoid accepting “any working value” for a variant-specific fault: e.g. Variant 3 must not pass if the scheduler still has `1999m` but happens to run on a larger node, and Variant 4 must not pass with `requests.cpu: 4`.

## 7. Cleanup plan

`cleanup.bash` should:

1. Restore the baseline manifests and CoreDNS Corefile if the baseline exists.
2. Wait for the control plane and CoreDNS to become healthy.
3. Remove `.cka-state/q15-baseline/`.
4. Call `cka_variant_clear` for the question.
5. If no baseline exists, print a clear warning and still clear the variant state.

This is a behavior change from the current Q15 cleanup, which intentionally does nothing. `AGENTS.md` line 49 currently documents that no-op behavior and must be updated when this is implemented. Restoring on cleanup is safer for a destructive lab and is required for predictable variant switching.

## 8. Files to change when implementing

| File | Change |
|---|---|
| `Question-15-Etcd-Fix/variants.bash` | New: 5 presets, summaries, question text |
| `Question-15-Etcd-Fix/LabSetUp.bash` | Source helper/variants; baseline capture/restore; fault injection; print variant question |
| `Question-15-Etcd-Fix/validate.bash` | Variant-aware checks; fail closed without state |
| `Question-15-Etcd-Fix/cleanup.bash` | Restore baseline, wait healthy, clear state |
| `Question-15-Etcd-Fix/Questions.bash` | Generic lab description; no hardcoded variant values |
| `Question-15-Etcd-Fix/SolutionNotes.bash` | Generic control-plane diagnostic runbook and fix recipes |
| `README.md` | Q15 row: `(5 variants)`; document `scripts/run-question.sh 15 [variant]` |
| `AGENTS.md` | Q15 hazards/cleanup note; record the 5-variant/unequal-difficulty exception |

`scripts/validate-question.sh` and `scripts/cleanup-question.sh` already include Q15 in their `1..17` loops, so no wrapper change is needed for Q15. (Their separate Q18/Q19 gap is unrelated.)

## 9. Test matrix

Run only on a disposable Killercoda-style cluster.

For each `v` in `1..5`:

1. `scripts/cleanup-question.sh 15`
2. `scripts/run-question.sh 15 "$v"`
3. Confirm setup prints `Variant v/5`, the summary, and the full question.
4. Confirm the expected symptom is present.
5. `scripts/validate-question.sh 15` — must fail before solving.
6. Apply that variant’s fix.
7. `scripts/validate-question.sh 15` — must pass.
8. Re-run setup for the same variant and for a different variant; confirm the baseline restore works and no fault leaks across variants.

Also test:

- no-argument setup records a valid random variant
- `0`, `6`, and non-numeric variant arguments fail
- validation without state fails
- tampered state for another variant fails
- `bash -n` on every touched script
- cleanup restores a healthy cluster after each variant

## 10. Open decisions before implementation

1. **Difficulty shape:** keep the progression above (recommended for exam realism), or normalize all five to equal-difficulty combined incidents.
2. **Variant 4 fault:** use controller CPU `4` (S2) as proposed, or controller memory `19Mi` (S1). The other one is covered in Variant 5.
3. **CoreDNS evidence:** keep the malformed-Corefile fault in Variant 5 as a training substitute, or omit it and make Variant 5 a pure etcd + scheduler + controller incident.
4. **Question disclosure:** keep the original Q15 style that reveals the peer-port root cause, or use the symptom-only wording proposed here.
5. **Cleanup behavior:** restore the cluster on cleanup (recommended) or only clear variant state and leave repair to the learner.

## 11. Recommendation

Implement the five-variant progression as described, keep Variant 5 as the capstone, and document the intentional departure from the equal-difficulty rule. Before writing the scripts, test the static-Pod resource behavior on the actual 1-core control-plane node: if a `1999m` scheduler request does not produce a Pending static Pod, use `4` CPU for the scheduler and `19Mi` for the controller, or choose another resource value that reliably produces the reported symptom.
