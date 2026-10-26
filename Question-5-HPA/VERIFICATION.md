# Question 5 — Manual Verification: HorizontalPodAutoscaler

> **Run setup first.** `scripts/run-question.sh 5 [variant]` prints the exact
> namespace, Deployment, HPA name, CPU target, replica bounds, and downscale
> stabilization window. Replace the `<...>` placeholders below.
>
> `scripts/validate-question.sh 5` checks the HPA fields. This file is the human
> check: it proves metrics are flowing and that the autoscaler can actually
> scale the Deployment.

## What success looks like

The HPA targets the printed Deployment and CPU percentage, has the exact
minimum/maximum replica bounds, and uses the printed downscale stabilization
window. Metrics are available, the HPA reports a real utilization percentage,
and it scales the Deployment up under load and back down after the load stops.

## 60-second review

- [ ] The HPA exists and targets the correct Deployment.
- [ ] The CPU target, min/max replicas, and stabilization window match setup.
- [ ] The HPA reports CPU utilization, not `<unknown>`.
- [ ] Under load, the Deployment scales up but never past the maximum.
- [ ] After the load stops, it scales down after the stabilization window.

## Detailed checks

### 1. Inspect the HPA spec

```bash
kubectl get hpa <HPA> -n autoscale -o yaml
kubectl describe hpa <HPA> -n autoscale
```

Expected:

- `scaleTargetRef.name: <DEPLOY>` and `kind: Deployment`
- `metrics[0].resource.name: cpu`
- `target.averageUtilization: <CPU_TARGET>`
- `minReplicas: <MIN_REPLICAS>`
- `maxReplicas: <MAX_REPLICAS>`
- `behavior.scaleDown.stabilizationWindowSeconds: <STABILIZATION>`

`kubectl describe hpa` should show `AbleToScale=True` and
`ScalingActive=True`. If it shows `<unknown>` for the current CPU, metrics are
not available yet.

### 2. Confirm metrics-server is working

```bash
kubectl get pods -n kube-system -l k8s-app=metrics-server
kubectl top pods -n autoscale
```

Expected: the metrics-server pod is Running, and `kubectl top` returns CPU and
memory for the application pods. If `kubectl top` fails, the HPA cannot compute
utilization, even if its YAML looks correct.

### 3. Generate load and watch scale-up

The setup exposes the Deployment with a Service named `<DEPLOY>` on port 80.
Run a temporary load pod:

```bash
kubectl run hpa-load --image=busybox:stable --restart=Never -- \
  /bin/sh -c 'while true; do wget -q -O- http://<DEPLOY>.autoscale.svc.cluster.local >/dev/null; done'
kubectl get hpa <HPA> -n autoscale -w
```

Expected: after a minute or two, the HPA's current CPU rises above the target
and the Deployment's replica count increases, up to `<MAX_REPLICAS>`.

Press `Ctrl-C` to stop watching. Check the replica count:

```bash
kubectl get deploy <DEPLOY> -n autoscale
kubectl top pods -n autoscale
```

### 4. Confirm scale-down respects the stabilization window

```bash
kubectl delete pod hpa-load
kubectl get hpa <HPA> -n autoscale -w
```

Expected: the HPA eventually scales back toward `<MIN_REPLICAS>`, but not
immediately. The delay should be consistent with `<STABILIZATION>` seconds.
The exact timing can vary because the HPA evaluates periodically; the important
point is that it does not scale down instantly.

## Common false positives

| Symptom | Likely cause |
|---|---|
| HPA shows `<unknown>` CPU | Metrics-server is not ready, or the Deployment has no CPU request |
| HPA never scales | CPU target is too high for the generated load, or metrics are missing |
| HPA scales above max | `maxReplicas` is wrong |
| HPA scales below min | `minReplicas` is wrong |
| Scale-down is immediate | `behavior.scaleDown.stabilizationWindowSeconds` is missing or wrong |
| HPA targets a different workload | `scaleTargetRef` points at the wrong Deployment |

## Cleanup

```bash
kubectl delete pod hpa-load --ignore-not-found
scripts/cleanup-question.sh 5
```

The lab cleanup removes the HPA, Deployment, Service, and metrics-server; the
load pod is created by this verification guide and must be deleted separately.
