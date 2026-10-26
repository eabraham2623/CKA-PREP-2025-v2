# Question 10 — Manual Verification: Taints and Tolerations

> **Run setup first.** `scripts/run-question.sh 10 [variant]` prints the exact
> taint key, value (if any), effect, node, and pod details. Replace the `<...>`
> placeholders below.
>
> This lab taints `node01`. Other pods that do not tolerate the taint may be
> evicted if the variant uses `NoExecute`. Run it on a disposable cluster.
>
> `scripts/validate-question.sh 10` checks the taint, pod placement, and
> toleration. This file is the human check: it proves the taint has the intended
> scheduling effect and that the pod was not merely tolerated by accident.

## What success looks like

`node01` carries the exact printed taint, the `nginx` pod is actually scheduled
on `node01`, and its toleration matches the taint's key, value (or `Exists`
when the taint has no value), and effect. A pod without the toleration cannot
schedule there.

## 60-second review

- [ ] `node01` has the exact taint key/value/effect.
- [ ] The `nginx` pod is Running.
- [ ] The pod is on `node01`, not just tolerating the taint somewhere else.
- [ ] The toleration matches the taint.
- [ ] A non-tolerating pod stays Pending or is evicted.

## Detailed checks

### 1. Inspect the taint

```bash
kubectl get node node01 -o jsonpath='{range .spec.taints[*]}{.key}{"="}{.value}{":"}{.effect}{"\n"}{end}'
kubectl describe node node01 | grep -A3 'Taints:'
```

Expected: exactly the taint printed by setup. For a taint without a value, the
JSONPath value is empty (it may print `key=:Effect`); the taint specification
itself is `key:NoSchedule`.

### 2. Confirm pod placement

```bash
kubectl get pod nginx -n default -o wide
kubectl get pod nginx -n default -o jsonpath='{.spec.nodeName}{"\n"}'
```

Expected: `nodeName` is `node01`. A toleration permits scheduling on a tainted
node; it does not force the pod there. If the pod is Running on the control
plane, the placement requirement is not met even though the toleration may be
correct.

### 3. Inspect the toleration

```bash
kubectl get pod nginx -n default -o jsonpath='{.spec.tolerations}{"\n"}'
kubectl describe pod nginx -n default | grep -A5 'Tolerations:'
```

Expected:

- For a valued taint: `key`, `operator: Equal`, matching `value`, and matching
  `effect`.
- For a taint with no value: `operator: Exists`, matching `key` and `effect`,
  and no `value`.

A toleration with the wrong effect or value does not satisfy the task. Using
`Exists` when the taint has a value is broader than intended.

### 4. Run the negative test

Create a pod without the toleration:

```bash
kubectl run nginx-fail --image=nginx --restart=Never \
  --overrides='{"spec":{"nodeSelector":{"kubernetes.io/hostname":"node01"}}}'
kubectl get pod nginx-fail -o wide
kubectl describe pod nginx-fail | grep -A6 'Events:'
```

Expected: the pod stays `Pending` because it does not tolerate the taint. For a
`NoExecute` variant, an already-running non-tolerating pod on `node01` is
evicted instead.

Delete the test pod when done:

```bash
kubectl delete pod nginx-fail --ignore-not-found
```

If `nginx-fail` schedules successfully on `node01`, the taint is missing or
weaker than the task requires.

## Common false positives

| Symptom | Likely cause |
|---|---|
| Pod Running on the wrong node | Toleration added but no `nodeName`/`nodeSelector` |
| Taint exists with wrong effect | Typo in the taint command |
| Taint has no value but toleration uses `Equal` | Should use `Exists` |
| Toleration has a value for a valueless taint | The value does not match anything |
| Negative pod also schedules | Taint was not applied, or was removed |
| Pod is Pending despite toleration | Key/value/effect mismatch, or the image cannot pull |

## Cleanup

```bash
scripts/cleanup-question.sh 10
```

Cleanup removes every preset's taint and the lab pods.
