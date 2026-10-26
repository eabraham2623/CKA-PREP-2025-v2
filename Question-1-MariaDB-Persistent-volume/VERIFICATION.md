# Question 1 — Manual Verification: MariaDB Persistent Volume

> **Run setup first.** `scripts/run-question.sh 1 [variant]` prints the exact
> namespace, PV, PVC, Deployment, and storage size for this run. Replace the
> `<...>` placeholders below with those values.
>
> `scripts/validate-question.sh 1` checks the fields. This file is the human
> check: it proves the Deployment really uses the retained PV and that the data
> survives a pod restart.

## What success looks like

MariaDB is Running from a PersistentVolumeClaim that is Bound to the retained
PersistentVolume, and data written under `/var/lib/mysql` is still there after
the MariaDB pod is deleted and recreated.

## 60-second review

- [ ] The PVC is `Bound`, not `Pending`.
- [ ] The PV is `Bound` to the expected namespace/PVC.
- [ ] The Deployment mounts the PVC at `/var/lib/mysql`.
- [ ] The MariaDB pod is `Running` and stable.
- [ ] A marker written before a pod restart is readable afterwards.

## Detailed checks

### 1. PVC and PV are bound to each other

```bash
kubectl get pvc <PVC> -n <NS>
kubectl get pv <PV>
kubectl describe pvc <PVC> -n <NS> | grep -E 'Status|Volume|Capacity'
```

Expected: the PVC shows `STATUS=Bound`, `Volume: <PV>`, and `Capacity: <SIZE>`.
The PV shows `STATUS=Bound` and a claim reference of `<NS>/<PVC>`.

If the PVC is `Pending`, inspect the PVC events and its `storageClassName` /
`volumeName` fields. The PV is retained, but a mismatched size, access mode, or
storage class can still prevent binding.

### 2. The Deployment uses the PVC, not an emptyDir

```bash
kubectl get deploy <DEPLOY> -n <NS> \
  -o jsonpath='{.spec.template.spec.volumes[*].persistentVolumeClaim.claimName}{"\n"}'
kubectl get deploy <DEPLOY> -n <NS> \
  -o jsonpath='{range .spec.template.spec.containers[*]}{.name}{" -> "}{.volumeMounts[*].mountPath}{"\n"}{end}'
```

Expected: the claim name is `<PVC>`, and the MariaDB container mounts it at
`/var/lib/mysql`.

Also check the live mount inside the pod:

```bash
kubectl exec deploy/<DEPLOY> -n <NS> -- df -h /var/lib/mysql
```

The filesystem should be the PV-backed volume, not the container's writable
layer. With a `hostPath`/`local-path` PV, `df` may show the node's root
filesystem; that is expected. The PVC binding and the marker-persistence test
below are the decisive checks.

### 3. Prove that data survives a pod restart

```bash
kubectl exec deploy/<DEPLOY> -n <NS> -- \
  sh -c 'echo cka-persistence > /var/lib/mysql/cka-marker'
kubectl delete pod -n <NS> -l app=<DEPLOY>
kubectl wait --for=condition=Ready pod -l app=<DEPLOY> -n <NS> --timeout=180s
kubectl exec deploy/<DEPLOY> -n <NS> -- cat /var/lib/mysql/cka-marker
```

Expected: the last command prints `cka-persistence`.

This is the check that separates a real PVC solution from a pod that is merely
Running with an emptyDir. If the marker disappears, the Deployment is not using
the retained volume.

On a multi-node cluster, remember that a `hostPath` PV is local to one node.
Confirm the replacement pod landed on the same node before concluding the PVC
failed; otherwise the marker test is not meaningful without node affinity.

### 4. Check the Deployment is stable

```bash
kubectl get deploy <DEPLOY> -n <NS>
kubectl get pods -n <NS> -l app=<DEPLOY> -o wide
kubectl logs deploy/<DEPLOY> -n <NS> --tail=30
```

Expected: `READY 1/1`, the pod is `Running`, and the MariaDB log has no
repeated crash or permission errors.

## Common false positives

| Symptom | Likely cause |
|---|---|
| PVC stays `Pending` | Wrong size, access mode, storage class, or `volumeName` |
| PV is `Released` | The PVC was deleted; the retained PV needs its `claimRef` cleared before rebinding |
| Pod is `Running` but marker disappears | Deployment still uses `emptyDir` or the blank `claimName` was never filled in |
| Pod is `CrashLoopBackOff` | MariaDB cannot write to the mounted directory, or the PVC is not actually mounted |
| PVC is Bound to a different PV | A `volumeName` was not set and another matching PV won the bind |

## Cleanup

```bash
scripts/cleanup-question.sh 1
```

Do not delete the PV before checking the PVC/PV relationship; this lab is about
reusing it, not recreating it.
