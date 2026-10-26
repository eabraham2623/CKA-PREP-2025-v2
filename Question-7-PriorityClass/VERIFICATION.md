# Question 7 — Manual Verification: PriorityClass

> **Run setup first.** `scripts/run-question.sh 7 [variant]` prints the exact
> namespace, Deployment, existing user-defined PriorityClass, and the target
> PriorityClass name. Replace the `<...>` placeholders below.
>
> `scripts/validate-question.sh 7` checks the recorded variant's values. This
> file is the human check: it shows how to derive the required value yourself
> and confirm the pod actually received it.

## What success looks like

A new PriorityClass exists with a value exactly one less than the highest
existing **user-defined** PriorityClass. It is not the cluster default, and the
existing Deployment uses it, so its pods report the new priority.

## 60-second review

- [ ] The target PriorityClass exists.
- [ ] Its value is exactly `highest user-defined value - 1`.
- [ ] It is not `globalDefault`.
- [ ] The Deployment names it in `priorityClassName`.
- [ ] The Deployment's pod is Running and reports the expected priority.

## Detailed checks

### 1. Find the highest user-defined class

```bash
kubectl get priorityclass --sort-by=.value
```

Expected classes include the setup's existing user-defined class and the
built-in `system-cluster-critical` and `system-node-critical` classes. The
target is based on the highest **user-defined** value, so ignore the `system-*`
classes when doing the arithmetic.

The setup prints the existing class and value. Confirm the current cluster
still matches:

```bash
kubectl get priorityclass <EXISTING_PC> -o jsonpath='{.value}{"\n"}'
```

### 2. Check the new class

```bash
kubectl get priorityclass <TARGET_PC> -o yaml
```

Expected:

- `value: <EXISTING_VALUE - 1>`
- `globalDefault: false` (or the field absent)
- A description is allowed but not required

If the new value equals the existing maximum, the answer is off by one. If it
was calculated from a `system-*` class, it is far too large and the answer is
wrong.

### 3. Confirm the Deployment uses it

```bash
kubectl get deploy <DEPLOYMENT> -n <NS> \
  -o jsonpath='{.spec.template.spec.priorityClassName}{"\n"}'
kubectl get pods -n <NS> -l app=<DEPLOYMENT> -o wide
kubectl get pod -n <NS> -l app=<DEPLOYMENT> \
  -o jsonpath='{range .items[*]}{.metadata.name}{" priority="}{.spec.priority}{"\n"}{end}'
```

Expected: `priorityClassName` is `<TARGET_PC>`, the pod is Running, and its
effective priority equals the new class value.

If the Deployment was patched but the old pod is still present, wait for the
rollout or delete the pod so the new `priorityClassName` is applied.

### 4. Confirm it is not the default

```bash
kubectl get priorityclass <TARGET_PC> \
  -o jsonpath='{.globalDefault}{"\n"}'
```

Expected: `false` or an empty line. A PriorityClass that becomes the cluster
default changes admission behavior for every pod and is not what this task
asks for.

## Common false positives

| Symptom | Likely cause |
|---|---|
| Value is equal to the existing maximum | Off-by-one error |
| Value is huge | The calculation included a `system-*` class |
| `globalDefault: true` | The class was created with the default flag |
| Deployment spec names the class, but pod priority is old | The rollout has not replaced the old pod |
| Target class exists but Deployment is unchanged | The patch was applied to the wrong Deployment or namespace |
| Wrong target class name | A stale class from another variant was reused |

## Cleanup

```bash
scripts/cleanup-question.sh 7
```

Cleanup removes the Deployment, namespace, every preset's PriorityClasses, and
the recorded variant.
