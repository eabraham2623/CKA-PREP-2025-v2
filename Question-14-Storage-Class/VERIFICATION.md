# Question 14 — Manual Verification: StorageClass

> **Run setup first.** `scripts/run-question.sh 14 [variant]` prints the exact
> StorageClass name, provisioner, and binding mode for this run. Replace the
> `<...>` placeholders below.
>
> `scripts/validate-question.sh 14` checks the StorageClass fields and default
> annotation. This file is the human check: it proves the old default was
> demoted and that no workloads or PVCs were disturbed.

## What success looks like

The new StorageClass exists with the printed provisioner and
`WaitForFirstConsumer` binding mode. It is the only default StorageClass; the
existing `local-path` class still exists but is no longer the default. No
Deployment or PVC was modified.

## 60-second review

- [ ] The new StorageClass exists.
- [ ] Its provisioner and binding mode match setup.
- [ ] It is marked default.
- [ ] The old `local-path` class still exists but is not default.
- [ ] `kubectl get sc` shows `(default)` only next to the new class.
- [ ] No workloads or PVCs were touched.

## Detailed checks

### 1. Inspect the new class

```bash
kubectl get storageclass <SC> -o yaml
kubectl get storageclass <SC> \
  -o jsonpath='{.provisioner}{" "}{.volumeBindingMode}{"\n"}'
```

Expected: the provisioner is `<PROVISIONER>` and the binding mode is
`WaitForFirstConsumer`.

### 2. Confirm it is the default

```bash
kubectl get storageclass
kubectl get storageclass <SC> \
  -o jsonpath='{.metadata.annotations.storageclass\.kubernetes\.io/is-default-class}{"\n"}'
```

Expected: `kubectl get sc` shows `(default)` next to `<SC>`, and the annotation
is `"true"`. The exact annotation key uses a slash; the JSONPath escape above is
intentional.

### 3. Confirm the old default was demoted

```bash
kubectl get storageclass local-path \
  -o jsonpath='{.metadata.annotations.storageclass\.kubernetes\.io/is-default-class}{"\n"}'
kubectl get storageclass
```

Expected: the old class still exists, its annotation is `"false"` or absent,
and `(default)` does not appear next to it. Deleting `local-path` is not the
task; it must remain available.

### 4. Confirm there is only one default

```bash
kubectl get storageclass -o yaml | grep -B2 -A1 'is-default-class'
```

Expected: only `<SC>` has `is-default-class: "true"`. If both classes are
default, the task is incomplete even if the new class looks correct.

### 5. Confirm workloads and PVCs were not modified

```bash
kubectl get deployments -A
kubectl get pvc -A
```

Expected: the same Deployments and PVCs that existed before the task. This is a
StorageClass-only exercise. Do not create a test PVC to prove the class works:

- `kubernetes.io/no-provisioner` does not dynamically provision;
- the `nfs.csi.k8s.io` provisioner may not be installed in this lab.

A Pending test PVC would therefore be expected and would not tell you whether
the StorageClass configuration is correct.

## Common false positives

| Symptom | Likely cause |
|---|---|
| New class is not default | The default annotation was never patched |
| Both classes are default | The old `local-path` annotation was not set to false |
| Old class was deleted | The task says not to remove it |
| Binding mode is `Immediate` | Wrong `volumeBindingMode` |
| Provisioner typo | The class exists but does not match setup |
| Workloads were edited | The task only changes StorageClass state |

## Cleanup

```bash
scripts/cleanup-question.sh 14
```

Cleanup removes the preset classes and restores `local-path` as the default.
