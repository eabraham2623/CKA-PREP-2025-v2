# AGENTS.md

## Repo facts
- Shell-only CKA practice labs: each `Question-N-Topic/` directory is an exercise against a **live Kubernetes cluster**. There is no app source, package manager, build, lint, or CI.
- Intended environment: Killercoda CKA playground or equivalent, with `kubectl`, root/`sudo`, control-plane manifests at `/etc/kubernetes/manifests`, and worker `node01` reachable over SSH. Q8/Q15 depend on this topology.
- Labs mutate cluster-wide and host state (CNI, static control-plane manifests, OS packages). Never run them against a shared or production cluster.

## Commands
Run from the repo root:
- `scripts/run-question.sh <N|Question-N-Topic> [variant]` runs `LabSetUp.bash`. Variant-enabled setups print the full question for the selected preset; single-variant labs then print `Questions.bash`. There is no `all` mode.
- `scripts/validate-question.sh <N|Question-N-Topic|all>` runs `validate.bash`.
- `scripts/cleanup-question.sh <N|Question-N-Topic|all>` runs `cleanup.bash`.
- No test/build/lint command exists; `validate.bash` is the test. It checks current cluster state and does not run setup.
- Clean up before retrying a lab: some setups are not idempotent (Q16 `kubectl create deployment`, Q17 `kubectl create secret tls`).

## Question layout
- Keep the five standard files: `LabSetUp.bash`, `Questions.bash`, `SolutionNotes.bash`, `validate.bash`, `cleanup.bash`. Variant-enabled questions also add `variants.bash`. `Questions.bash` and `SolutionNotes.bash` are study text; validation lives in `validate.bash`.
- Directory names must remain `Question-<number>-<topic>`; wrappers resolve numbers with `find ... -name "Question-$N-*"`. Add new questions to the README table.
- `validate-question.sh` and `cleanup-question.sh` hard-code `for i in $(seq 1 17)` although 19 questions exist. `all` silently skips Q18/Q19; target them explicitly and update or de-hard-code the loops when touching them.
- Validators define `check <description> <command...>`. Most end with `exit $FAIL` (failure count); Q1 and Q19 exit 0/1. The wrapper maps exit 0=pass, 2=skip, anything else=fail. Avoid returning 2 from a validator: exactly two failing checks would otherwise look like SKIP.

## Adding randomized variants
Variants are implemented for Questions 1 and 2 (three presets each) and the shared helper exists. When the user asks for variants of another lab, follow this contract; apply changes per-question, not to every lab at once unless explicitly requested.

- Treat variants as fixed, tested presets, not arbitrary runtime randomness. Randomness only chooses the preset; values inside a preset must be deterministic.
- Add `Question-N-Topic/variants.bash` containing `VARIANT_COUNT`, `variant_config <n>`, and `variant_question <n>`. `variant_config` is the single source of truth: it sets every variant-specific value used by setup and validation, plus `VARIANT_SUMMARY` containing the task values shown to the learner. `variant_question` prints the complete variant-specific task.
- Provide/use the shared helper `scripts/lib/variant.sh`:
  - `cka_variant_select <question-dir> <count> [requested]`: validates `1..count`, writes `.cka-state/<question-dir>.variant`, and prints the selected number. With no `requested` value it chooses randomly with `$RANDOM`.
  - `cka_variant_read <question-dir> <count>`: reads the recorded number and fails closed with "run setup first" if it is missing or invalid.
  - `cka_variant_clear <question-dir>`: removes the recorded state.
- CLI: `scripts/run-question.sh <N|Question-N-Topic> [variant]`. A supplied number selects that preset; no number randomizes. Direct `LabSetUp.bash <variant>` must also work. Reject non-numeric or out-of-range values; never silently fall back to random. Parse the question and variant arguments separately in the wrapper.
- Only setup selects or reveals the variant. Wrappers must not choose or print it before setup runs.
- `LabSetUp.bash` must compute its own directory, source the helper and `variants.bash`, accept an optional first argument, select the variant, print `Variant N/M` and `VARIANT_SUMMARY`, create resources from the selected values, and print the complete `variant_question` output so the learner sees the exact task for that run.
- For variant-enabled questions, `run-question.sh` must pass the optional variant through and must not print the generic `Questions.bash` after setup, because setup already printed the variant-specific question.
- `validate.bash` must read the recorded variant, print it, call `variant_config`, and assert that variant's exact values and semantics. Never accept "any of the variants"; missing state is a hard failure.
- `Questions.bash` and `SolutionNotes.bash` must not hardcode values that can vary. Keep them generic and point to the values printed by setup, or generate their text from `variant_config`. The setup output is what reveals the current task.
- `.cka-state/` is ignored runtime state: add it to `.gitignore` and never commit it. Every `cleanup.bash` clears its question's state; `cleanup-question.sh all` clears all state.
- Keep resource names, namespaces, and object counts stable where possible. If a preset needs different names, cleanup and validation must handle every preset. Do not vary the required tool, API, CNI, control-plane component, or prerequisites.
- Equal difficulty is mandatory: same task, commands, features, object count, and step count. Vary values only (names, counts, ports, sizes, percentages, labels, hostnames, supported versions), within tested cluster capacity. For Q4/Q19, derive expectations from live allocatable resources rather than assuming one node size. For destructive Q8/Q15, test only on a disposable cluster.
- Use 2-4 presets where a safe axis exists. If no safe axis exists, leave the lab single-variant rather than inventing a harder task.
- Definition of done for every new or changed variant, on a disposable cluster:
  `scripts/cleanup-question.sh N && scripts/run-question.sh N <v>` must succeed, the setup output must show the correct `Variant v/M` values and full question, validation before solving must fail, and validation after applying that variant's solution must pass for every `v`. Also verify no-arg setup records a valid random variant, invalid `0`/`N+1`/non-numeric values fail, validation without state fails, tampered state for another variant fails, and `bash -n` passes on touched scripts. Update the README for `[variant]`.

## Lab-specific hazards
- Q18: after setup, run `source /tmp/cka-q18-hook.bash` in the solving shell. Validation inspects `/tmp/cka-q18-audit.log` and shell history for `kubectl patch` and no `kubectl edit`.
- Q15: setup intentionally rewrites kube-apiserver `--etcd-servers` from 2379 to 2380 and takes the API server down. `cleanup.bash` intentionally makes no change; rerun setup to re-break after repair.
- Q8: removes the Cilium CNI and its state locally and on `node01`. Cleanup does not restore Cilium and a node restart may be required.
- Q9: setup downloads `cri-dockerd`; the solution installs the Debian package and systemd unit system-wide, and cleanup removes them.
- Q1: setup intentionally leaves `claimName: ""` in `~/mariadb-deploy.yaml`; the learner must fill it in. The namespace, PV/PVC/deployment names, and storage size vary by preset; setup prints the exact values and question. Do not "fix" the blank `claimName`.
- Q2: the Helm repo alias, namespace, chart version, output manifest path, and required extra chart value (server service type or replicas) vary by preset. Variant 1 keeps `/root/argo-helm.yaml`. Setup prints the exact values and question.
- Fixed paths matter: `/root/resources.yaml` and `/root/subject.yaml` (Q6). Q13 creates `network-policies/` under the caller's `$PWD`, so run wrappers from the repo root. Q17 leaves `tls.key`/`tls.crt` in the cwd; remove them.
