# Question 3 — Manual Verification: Sidecar Container

> **Run setup first.** `scripts/run-question.sh 3 [variant]` prints the exact
> namespace, Deployment, main container, log file, and mount path for this run.
> Replace the `<...>` placeholders below with those values.
>
> `scripts/validate-question.sh 3` checks the object fields. This file is the
> human check: it proves the sidecar can actually read the main container's
> log through a shared volume.

## What success looks like

The existing Deployment has a second container named `sidecar` using
`busybox:stable`, running `tail` against the main container's log file. Both
containers mount the same `emptyDir` volume at the printed mount path, and
`kubectl logs -c sidecar` shows the lines the main container writes.

## 60-second review

- [ ] The Deployment is available and the pod is Running.
- [ ] The sidecar uses `busybox:stable`.
- [ ] The sidecar command follows the main container's log file.
- [ ] Both containers mount the same `emptyDir` at the same path.
- [ ] The sidecar log contains the main container's log message.

## Detailed checks

### 1. Inspect the containers

```bash
kubectl get deploy <DEPLOY> -n <NS> \
  -o jsonpath='{range .spec.template.spec.containers[*]}{.name}{" image="}{.image}{"\n"}{end}'
kubectl get deploy <DEPLOY> -n <NS> \
  -o jsonpath='{range .spec.template.spec.containers[*]}{.name}{" command="}{.command}{" args="}{.args}{"\n"}{end}'
```

Expected: the original main container plus `sidecar` with image
`busybox:stable`. The sidecar command should reference the exact log file
printed by setup, typically `/bin/sh -c tail -F <LOG_FILE>`.

`tail -F` is preferred over `tail -f`; it continues following the file if the
file is rotated or recreated. The validator accepts the task's `tail`
requirement, but the more robust command is `-F`.

### 2. Confirm the shared volume

```bash
kubectl get deploy <DEPLOY> -n <NS> \
  -o jsonpath='{.spec.template.spec.volumes[*].emptyDir}{"\n"}'
kubectl get deploy <DEPLOY> -n <NS> \
  -o jsonpath='{range .spec.template.spec.containers[*]}{.name}{" mounts="}{.volumeMounts[*].mountPath}{"\n"}{end}'
```

Expected: an `emptyDir` volume exists, and both the main container and
`sidecar` mount it at `<MOUNT_PATH>` (typically `/var/log`).

If only the sidecar mounts the volume, it will start successfully but will not
see the main container's log. If the main container mounts a different volume
or path, the sidecar will see an empty directory.

### 3. Prove the sidecar is reading the live log

```bash
kubectl logs deploy/<DEPLOY> -n <NS> -c sidecar --tail=20
```

Expected: lines containing the setup's log message, for example
`WordPress is running...` or the variant's equivalent.

The main container writes every few seconds, so an empty sidecar log usually
means a mount or command-path problem, not a slow application. Write a unique
line and watch it appear:

```bash
kubectl exec deploy/<DEPLOY> -n <NS> -c <MAIN_CONTAINER> -- \
  sh -c 'echo cka-sidecar-check >> <LOG_FILE>'
kubectl logs deploy/<DEPLOY> -n <NS> -c sidecar --tail=10
```

Expected: `cka-sidecar-check` appears in the sidecar output.

### 4. Confirm the pod is stable

```bash
kubectl get pods -n <NS> -l app=<DEPLOY> -o wide
kubectl describe pod -n <NS> -l app=<DEPLOY> | grep -A5 'Containers:'
```

Expected: the pod is Running, both containers are Ready, and there are no
repeated restarts or volume errors.

## Common false positives

| Symptom | Likely cause |
|---|---|
| Sidecar is Running but logs are empty | The sidecar and main container do not share the same volume |
| Sidecar exits immediately | Wrong log path, missing `tail` target, or a command that is not a long-running process |
| Sidecar reads a different file | Main container writes to a different mount path or volume |
| Sidecar restarts repeatedly | The log file was deleted/recreated and `tail -f` was used instead of `tail -F` |
| Deployment unavailable | The sidecar image cannot pull or the volume mount name is wrong |

## Cleanup

```bash
scripts/cleanup-question.sh 3
```

For variant 1 the namespace is `default`; cleanup removes only the named
Deployment and Service, not the namespace.
