# Question 9 — Manual Verification: cri-dockerd

> **Run setup first.** `scripts/run-question.sh 9 [variant]` downloads the
> pinned Debian package and prints the exact service name and four sysctl
> key/value pairs for this run. Replace the `<...>` placeholders below.
>
> This lab modifies host packages, systemd units, and sysctls. Run it only on a
> disposable node. Cleanup restores only the recorded sysctl baseline; it does
> not reinstall a previous container runtime.
>
> `scripts/validate-question.sh 9` checks the package, service, and sysctls.
> This file is the human check: it proves the runtime socket is live and the
> settings are both active and persistent.

## What success looks like

The cri-dockerd package is installed, `cri-docker.service` is enabled and
running, the CRI socket responds, and all four printed sysctl values are active
and persisted in `/etc/sysctl.d/kube.conf`.

## 60-second review

- [ ] The Debian package is installed.
- [ ] `cri-docker.service` is enabled and active.
- [ ] The CRI socket exists and `crictl info` succeeds.
- [ ] All four sysctl values are active now.
- [ ] All four values are present in `/etc/sysctl.d/kube.conf`.
- [ ] Re-applying the lab file keeps the values.

## Detailed checks

### 1. Confirm the package and service

```bash
dpkg -l | grep cri-docker
dpkg -s cri-dockerd | grep -E 'Status|Version'
systemctl is-enabled <CRI_DOCKER_SERVICE>
systemctl is-active <CRI_DOCKER_SERVICE>
sudo systemctl status <CRI_DOCKER_SERVICE> --no-pager
```

Expected: the package status is `install ok installed`, the service is
`enabled` and `active`, and the unit log has no repeated restart loop.

If the service is active but immediately restarts, read the unit log before
changing sysctls; the two problems can be independent.

### 2. Confirm the CRI socket works

```bash
ls -l /run/cri-dockerd.sock /var/run/cri-dockerd.sock 2>/dev/null || true
sudo crictl --runtime-endpoint unix:///run/cri-dockerd.sock \
  --image-endpoint unix:///run/cri-dockerd.sock info
```

Expected: the socket exists and `crictl info` returns runtime information
without a connection error. A socket file alone is not proof; the API must
answer.

You can also check the installed binary:

```bash
cri-dockerd --version
```

### 3. Check the live sysctl values

Repeat this for each key/value pair printed by setup:

```bash
sysctl -n <KEY_1>
sysctl -n <KEY_2>
sysctl -n <KEY_3>
sysctl -n <KEY_4>
```

Expected: each output equals the corresponding value printed by setup.

### 4. Check persistence

```bash
sudo grep -E '^(<KEY_1>|<KEY_2>|<KEY_3>|<KEY_4>)=' /etc/sysctl.d/kube.conf
```

Expected: four lines, with exactly the printed values. This file is what makes
the settings survive a reboot.

Apply only the lab file and confirm it reports the same values:

```bash
sudo sysctl -p /etc/sysctl.d/kube.conf
```

Do **not** run `sysctl --system` as part of cleanup or verification; it can
revert unrelated networking settings on the node.

### 5. Confirm the runtime is usable

```bash
sudo crictl --runtime-endpoint unix:///run/cri-dockerd.sock ps
```

Expected: the command succeeds. It may show no containers; that is fine. The
goal is to prove the CRI endpoint is reachable, not to run a workload through
it.

## Common false positives

| Symptom | Likely cause |
|---|---|
| Package installed but service disabled | `systemctl enable --now` was not run |
| Service active but socket missing | Unit failed to start or is listening on another path |
| `crictl` cannot connect | Wrong endpoint, or the service is not actually running |
| Live sysctl value is right, file is missing | The setting was applied with `sysctl -w` but not persisted |
| File is right, live value is old | `sysctl -p` was not run after writing the file |
| Service restarts repeatedly | Runtime or socket configuration problem, not necessarily sysctl |

## Cleanup

```bash
scripts/cleanup-question.sh 9
```

Cleanup removes the package, disables the units, deletes the socket/config, and
restores only the sysctl values recorded by setup.
