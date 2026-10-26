# CKA Practice (Simple Edition)

Straightforward CKA practice labs derived from the CKA-PREP playlist. Every question lives in its own folder with bash files:

**Note:** This is a living repo and may still contain bugs or rough edges. If you spot an issue—especially in lab setup or validation scripts—please open an issue or PR so it can be fixed.  This is a best effort repo and PR/Issue merges will be addressed as time permits!

**Exam prep note:** These questions are designed to be similar to the CKA exam, but they are not meant be exact matches. Learn the underlying concepts in depth and try different scenarios so you can solve variations under exam conditions.

- `LabSetUp.bash` — set up the environment for the question.
- `Questions.bash` — the scenario text plus the YouTube link for the walkthrough.
- `SolutionNotes.bash` — a step-by-step solution when you need a hint.
- `validate.bash` — automatic validation checks to confirm your solution is correct.
- `cleanup.bash` — clean up and remove resources created during the question.
- `variants.bash` — variant-enabled questions only: fixed presets and the variant-specific question text.
- `VERIFICATION.md` — Questions 1–17 only: human-readable checks that prove the solution works end to end, beyond the field-level validator.

---

## How to Use

1. Launch the [Killercoda CKA playground]([https://killercoda.com/cka](https://killercoda.com/playgrounds/scenario/cka) or your own cluster.
2. Clone this repo inside the environment:
   ```bash
   git clone https://github.com/markdjones82/CKA-PREP-2025-v2.git ~/CKA-PREP-2025-v2
   cd ~/CKA-PREP-2025-v2
   ```
3. Run a question setup by number:
   ```bash
   scripts/run-question.sh 5
   ```
4. Work through the task, then consult `SolutionNotes.bash` if you need help.
5. Validate your solution:
   ```bash
   scripts/validate-question.sh 5
   ```
6. For a human-readable checklist of behavior-level checks and expected
   observations, open the question's `VERIFICATION.md`. It is meant to be used
   together with the validator, not instead of it.
7. Clean up resources when done:
   ```bash
   scripts/cleanup-question.sh 5
   ```

### Randomized lab variants

Some questions have multiple variants. Running setup without a variant number selects one at random and prints the full question for that run, including the exact names, versions, chart values, paths, replica counts, and percentages:

```bash
scripts/run-question.sh 1
```

To repeat a specific variant, pass its number as the second argument:

```bash
scripts/run-question.sh 1 2
```

Validation reads the variant recorded by setup, so run setup before validating. Cleanup clears the recorded variant.

Question 15 is a control-plane incident lab and an intentional exception to the equal-difficulty rule: its five presets form a progression from single-fault drills (etcd endpoint, scheduler and controller-manager resources) to a combined multi-fault capstone. The CoreDNS wrong-zone fault in the capstone is a training substitute, not a reported exam value. Setup snapshots a pristine control-plane baseline under `.cka-state/q15-baseline/`, and cleanup restores it. Run these presets only on a disposable cluster. For a spoiler-heavy, per-variant diagnosis and repair walkthrough, see [Question-15-Etcd-Fix/TROUBLESHOOTING.md](Question-15-Etcd-Fix/TROUBLESHOOTING.md).

Question 17's three presets mirror reported exam variations: (1) restrict NGINX to TLS 1.3 only, (2) enable TLS 1.2 while retaining TLS 1.3, and (3) perform the TLS 1.3-only change with an immutable ConfigMap, which must be deleted and recreated. Variant 3 is an intentional immutability capstone and a recorded exception to the equal-difficulty rule.

---

## Validating Your Solutions

Each question has a `validate.bash` script that runs automated checks against your cluster to confirm the solution is correct.

### Validate a single question
```bash
# By question number
scripts/validate-question.sh 5

# By directory name
scripts/validate-question.sh Question-5-HPA
```

### Validate all questions
```bash
scripts/validate-question.sh all
```

The script outputs `PASS` or `FAIL` for each check, with a final score summary. Exit code is `0` if all checks pass, non-zero otherwise.

---

## Simulated Exam Desktop (VSCodium)

You can use **VSCodium** (an open-source VS Code build) inside the Killercoda simulated desktop to edit files in a familiar IDE environment, similar to what is available in the real CKA exam.

> **NOTE: A paid Killercoda subscription is required** for the simulated desktop environment.
> Without it, the desktop GUI is not available and VSCodium cannot be launched graphically.

### Install VSCodium
```bash
scripts/install-codium.sh
```

### Launch VSCodium
Once installed, open it from inside your repo:
```bash
cd ~/CKA-PREP-2025-v2
codium --no-sandbox --user-data-dir .
```

This opens VSCodium in the current directory, allowing you to browse and edit all question files directly.

---

## Available Questions

| # | Topic | Video |
|---|-------|-------|
| 1 | MariaDB — Persistent Volume (3 variants) | https://youtu.be/aXvvc1EB1zg |
| 2 | ArgoCD — Install via Helm (no CRDs, 3 variants) | https://youtu.be/e0YGRSjb8CU |
| 3 | Sidecar Container (3 variants) | https://youtu.be/3xraEGGQJDY |
| 4 | Resource Allocation (3 variants) | https://youtu.be/ZqGDdETii8c |
| 5 | HPA — HorizontalPodAutoscaler (3 variants) | https://youtu.be/YGkARVFKtmM |
| 6 | CRDs — cert-manager (3 variants) | https://youtu.be/SA1DzLQaDJs |
| 7 | PriorityClass (3 variants) | https://youtu.be/CZzxGyF6OHc |
| 8 | CNI & Network Policy | https://youtu.be/Uc04Ui4x3EM |
| 9 | cri-dockerd (3 variants) | https://youtu.be/ybzo1vXiqjU |
| 10 | Taints & Tolerations (3 variants) | https://youtu.be/oy6Mdqt1-jk |
| 11 | Gateway API (3 variants) | https://youtu.be/G9zispvOCHE |
| 12 | Ingress (3 variants) | https://youtu.be/sy9zABvDedQ |
| 13 | Network Policy (3 variants) | https://youtu.be/rA8mXYTU0W8 |
| 14 | Storage Class (3 variants) | https://youtu.be/di7X7OHn2fc |
| 15 | Etcd Fix (5 variants — control-plane faults) | https://youtu.be/IL448T6r8H4 |
| 16 | NodePort Service (3 variants) | — |
| 17 | TLS Config (3 variants) | — |
| 18 | kubectl patch — Resource Limits | — |
| 19 | Resource Allocation v2 — Pod Scheduling | — |
