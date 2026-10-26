# Question 4 — Manual Verification: Resource Allocation

> **Run setup first.** `scripts/run-question.sh 4 [variant]` prints the
> namespace, Deployment, replica count, node, reserved overhead percentage, and
> node budget for this run. Replace the `<...>` placeholders below with those
> values.
>
> `scripts/validate-question.sh 4` checks the final numbers. This file is the
> human check: it shows how to derive those numbers from live node capacity and
> confirm the scheduler can actually place every pod.

## What success looks like

Every init container and main container has the same CPU and memory request and
limit. The values are derived from the target node's **allocatable** resources,
after reserving the printed overhead percentage, divided evenly across the
printed replica count and rounded down to 10m/10Mi. All pods are Running, none
are Pending, and the Deployment is back at its required replica count.

## 60-second review

- [ ] The Deployment is at the printed replica count.
- [ ] All pods are Running; none are Pending.
- [ ] Main and init containers have identical resources.
- [ ] Requests equal limits.
- [ ] The values match an independent calculation from node allocatable
      capacity, overhead, replica count, and the round-down rule.

## Detailed checks

### 1. Read the node budget

```bash
kubectl get node <NODE> \
  -o jsonpath='{.status.allocatable.cpu}{" CPU, "}{.status.allocatable.memory}{" memory\n"}'
```

Use **allocatable**, not capacity. The setup prints the same budget in
millicores and MiB. If the node changed since setup, use the current values and
recalculate; the required per-pod target is based on the smallest Ready,
schedulable node.

The formula is:

```text
per-pod CPU    = floor(allocatable CPU    * (100 - overhead%) / replicas / 10m) * 10m
per-pod memory = floor(allocatable memory * (100 - overhead%) / replicas / 10Mi) * 10Mi
```

Round **down** to the nearest 10m/10Mi. Do not round up; that can make the
pods unschedulable.

### 2. Inspect both container types

```bash
kubectl get deploy <DEPLOY> -n wordpress \
  -o jsonpath='{range .spec.template.spec.initContainers[*]}init {.name}: requests={.resources.requests.cpu}/{.resources.requests.memory} limits={.resources.limits.cpu}/{.resources.limits.memory}{"\n"}{end}'
kubectl get deploy <DEPLOY> -n wordpress \
  -o jsonpath='{range .spec.template.spec.containers[*]}main {.name}: requests={.resources.requests.cpu}/{.resources.requests.memory} limits={.resources.limits.cpu}/{.resources.limits.memory}{"\n"}{end}'
```

Expected: the init container and main container show exactly the same CPU and
memory values, and requests equal limits for both.

A common mistake is to divide by the number of containers. Init containers do
not run at the same time as the main container, so the per-pod share is not
divided by the container count.

### 3. Confirm the pods are actually scheduled

```bash
kubectl get pods -n wordpress -l app=<DEPLOY> -o wide
kubectl get pods -n wordpress -l app=<DEPLOY> \
  -o jsonpath='{range .items[*]}{.metadata.name}{" qos="}{.status.qosClass}{" node="}{.spec.nodeName}{"\n"}{end}'
```

Expected: exactly the printed number of pods, all `Running`, all on the target
node, and `qos=Guaranteed` because requests equal limits.

Check the node's allocated requests:

```bash
kubectl describe node <NODE> | grep -A12 'Allocated resources'
```

The sum of the pod requests should fit within the node's allocatable budget,
with the intended overhead left free.

### 4. Confirm the Deployment is back at the required scale

```bash
kubectl get deploy <DEPLOY> -n wordpress
kubectl rollout status deploy/<DEPLOY> -n wordpress --timeout=180s
```

Expected: `READY <REPLICAS>/<REPLICAS>` and a successful rollout.

## Common false positives

| Symptom | Likely cause |
|---|---|
| Pods stay Pending | Values rounded up, or calculated from node capacity instead of allocatable |
| Init container differs from main | Only one container type was patched |
| Requests do not equal limits | A partial resource edit; QoS is not `Guaranteed` |
| Too few pods | Deployment was not scaled back up |
| Pods land on another node | The larger node was used for the calculation, or the scheduler had no room |
| Values look right but rollout stuck | The sum of requests exceeds the target node's free allocatable resources |

## Cleanup

```bash
scripts/cleanup-question.sh 4
```

Cleanup removes every preset's Deployment from the shared `wordpress`
namespace. It does not delete the namespace.
