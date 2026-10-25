# Question 15 — Proposed Variants from the Deep-Research Notes

Status: **partially implemented and tested — see the implementation handoff in section 12**

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

## 12. Implementation handoff (2026-10-25)

Status: **implemented, but not fully re-verified from a clean state. Continue with the atomic-write fix and the remaining test matrix before declaring it done.**

### 12.1 Files added or changed

| File | Status |
|---|---|
| `Question-15-Etcd-Fix/q15-lib.bash` | New. Shared baseline, health, manifest-edit, CoreDNS, and status helpers. |
| `Question-15-Etcd-Fix/variants.bash` | New. Five presets, summaries, and full question text. |
| `Question-15-Etcd-Fix/LabSetUp.bash` | Rewritten. Baseline restore/snapshot, fault injection, symptom wait, question output. |
| `Question-15-Etcd-Fix/validate.bash` | Rewritten. Variant-aware validation; fails closed without recorded state. |
| `Question-15-Etcd-Fix/cleanup.bash` | Rewritten. Restores baseline, waits for health, removes baseline and variant state. |
| `Question-15-Etcd-Fix/Questions.bash` | Rewritten as generic variant-aware study text. |
| `Question-15-Etcd-Fix/SolutionNotes.bash` | Rewritten as a generic control-plane troubleshooting runbook. |
| `README.md` | **Not yet updated** (Q15 still says no variants). |
| `AGENTS.md` | **Not yet updated** (line 49 still describes Q15 cleanup as a no-op). |
| This plan file | Updated with implementation/test status. |

The plan file is tracked at `HEAD`. The code changes are **uncommitted**. `q15-lib.bash` and `variants.bash` are still untracked. No `git commit` or `git push` was run.

### 12.2 Implemented variant behavior

| Variant | Actual injected fault(s) |
|---|---|
| 1 | `--etcd-servers=https://127.0.0.1:2380` |
| 2 | `--etcd-servers=https://192.0.2.100:2379` |
| 3 | Scheduler `requests.cpu: 1999m` |
| 4 | Controller-manager `requests.cpu: 4` |
| 5 | Etcd peer port + scheduler `1999m` + controller `limits.memory: 19Mi` + CoreDNS `kubernetes wrong.local` |

### 12.3 Deliberate divergences from the original proposal

1. **CoreDNS fault changed from malformed Corefile to wrong cluster zone.**
   - The original malformed Corefile (missing final `}`) was tolerated by CoreDNS's `reload` plugin: the pods stayed Running and kept serving the old config, so DNS still worked.
   - The implemented fault rewrites `kubernetes cluster.local` to `kubernetes wrong.local`. CoreDNS stays Running, but `kubernetes.default.svc.cluster.local` stops resolving. This produces a reliable DNS failure that the validator can detect.
   - `q15_corefile_is_valid` now requires the exact `cluster.local` zone and rejects `wrong.local`.

2. **Validation checks static containers through `crictl`, not just mirror Pods.**
   - After the API was down and recovered, a stale mirror Pod showed `kube-scheduler` as `Running` even though no scheduler container existed.
   - `q15_container_running` uses `sudo crictl ps --name '^<component>$' --state Running`, and both health checks and validation now use it.

3. **Baseline restoration waits for the CoreDNS rollout.**
   - `kubectl rollout restart deployment/coredns` returns before the old pods are replaced. Cleanup could finish while CoreDNS was still rolling, and an immediate setup could see a temporarily unhealthy cluster.
   - `q15_restore_baseline` now runs `kubectl rollout status deployment/coredns --timeout=...` before `q15_wait_cluster_healthy`.

### 12.4 Test results so far

Individual/manual tests:

- Variant 1: setup, validation-before-fail, fix, validation 14/14, cleanup pass.
- Variant 2: same, 14/14 after fix, cleanup pass.
- Variant 3: same, 14/14 after fix, cleanup pass.
- Variant 4: same, 14/14 after fix, cleanup pass.
- Variant 5: setup, validation-before-fail (1/14 or 2/14 depending on run), manual fix after waiting for the API, validation 14/14, cleanup pass.

Matrix run 1 (`/tmp/opencode/q15-matrix.sh`, first version):

- Variants 1–4: setup, validation-before-fail, solution, validation-pass, cleanup all passed.
- Variant 5: failed only because the test harness edited scheduler/controller/CoreDNS while the API was still down after the etcd fix. The product code was not at fault.
- Cleanup still passed and restored the cluster.
- Fix applied to the harness: wait for `q15_api_ready` after repairing the etcd endpoint before applying the remaining fixes.

Matrix run 2 (second version):

- Variant 1: setup, fail-before, solve, 14/14, cleanup pass.
- Variant 2: setup, fail-before, solve, 14/14, cleanup pass.
- Variant 3: setup and fail-before completed; the session was interrupted before the solution/after/cleanup steps.
- The interrupted run left variant 3 recorded and the scheduler in a 5-minute CrashLoopBackOff. The cluster was manually cleaned up afterwards. Cleanup returned 0 and the cluster is healthy again.

Useful logs and harness:

- Test harness: `/tmp/opencode/q15-matrix.sh`
- Logs: `/tmp/opencode/q15-matrix/`
- Last verified cluster state at handoff: both nodes `Ready`, all control-plane containers Running, no `.cka-state`, no pristine baseline. The cluster is healthy.

### 12.5 Known bug to fix first: non-atomic manifest writes

`q15_set_container_resources` uses Python `open(path, 'w')`, which truncates the static Pod manifest before writing. Kubelet can observe the empty/partial file. This happened during the interrupted run:

```text
can't process config file "/etc/kubernetes/manifests/kube-scheduler.yaml":
couldn't parse as pod(Object 'Kind' is missing in 'null')
```

The result was a kubelet parse error and a 5-minute `CrashLoopBackOff` before the scheduler restarted. It eventually recovered, but the edit is not safe.

Fix:

1. In `q15_set_container_resources`, write the new YAML to a temporary file in `/etc/kubernetes/manifests` (same filesystem).
2. Preserve ownership/mode.
3. Atomically replace the target with `os.replace(temp, path)` (Python) or `sudo mv temp target`.
4. Do the same audit for any other direct writes to static manifests.
5. Re-test all five variants after the fix.

`q15_set_etcd_servers` uses `sed -i`, which uses a temporary file and rename on GNU sed, so it did not show this failure. It should still be included in the atomic-write review.

### 12.6 Remaining test work

The following were **not** completed after the latest changes:

- Full clean matrix after the atomic-write fix: cleanup → setup → fail-before → solve → pass → cleanup for all five variants.
- Re-run setup for the same variant and for a different variant without cleanup, to prove baseline restore and fault isolation.
- No-argument setup records a valid random variant.
- Invalid variant arguments `0`, `6`, and non-numeric fail.
- Validation without recorded state fails.
- Tampered recorded state for another variant fails.
- `bash -n` on all touched scripts after the final edits.
- Confirm cleanup leaves both nodes Ready, all control-plane containers Running, CoreDNS available, and cluster DNS resolving.
- Verify `scripts/validate-question.sh all` still behaves correctly with Q15 included (the wrapper loops 1..17, so Q15 is in scope).

### 12.7 Remaining documentation work

- `README.md`: change the Q15 row to `Etcd Fix (5 variants)` and document `scripts/run-question.sh 15 [variant]`.
- `AGENTS.md`: update the Q15 hazard/cleanup entry. It currently says cleanup intentionally makes no change; the implemented cleanup restores the baseline and clears state.
- Record the intentional departure from the repository's equal-difficulty and 2–4-preset guidance.
- Update sections 5 and 10 of this plan so they describe the implemented `wrong.local` CoreDNS fault rather than the original malformed-Corefile idea.

### 12.8 Open design questions for the next session

1. **Variant 5 controller fault:** `19Mi` is close to the controller's live usage. It can run for a while and then OOM/restart; in one run it was Running, in another it was CrashLoopBackOff. If that intermittent behavior is undesirable, either add the controller CPU `4` fault to Variant 5 as well (making it visible immediately) or move the `19Mi` fault into Variant 4 and use CPU `4` in Variant 5.
2. **Equal difficulty:** Variants 1–4 are single-fault drills; Variant 5 is a multi-fault capstone. This is a progression, not equal difficulty. Confirm that is acceptable before finalizing `AGENTS.md`.
3. **CoreDNS evidence strength:** the `wrong.local` zone is a training substitute, not the exact exam fault. Keep that wording explicit in learner-facing text.
4. **Question disclosure:** current questions describe symptoms and migration context but do not reveal the exact bad value. This is more exam-like than the original Q15 wording, but it is a change from the original lab.

