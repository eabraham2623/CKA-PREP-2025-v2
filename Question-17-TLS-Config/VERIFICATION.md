# Question 17 — Manual Verification: NGINX TLS Config

> **Run setup first.** `scripts/run-question.sh 17 [variant]` prints the exact
> initial/required `ssl_protocols`, whether the ConfigMap is immutable, and the
> expected TLS 1.2 result. Replace the `<...>` placeholders below.
>
> This lab edits `/etc/hosts`. Run it on a disposable cluster.
>
> `scripts/validate-question.sh 17` checks the ConfigMap, hosts entry, and TLS
> handshakes. This file is the human check: it shows how to inspect the loaded
> nginx config and prove the protocol behavior directly with `curl` and
> `openssl`.

## What success looks like

The ConfigMap contains the required `ssl_protocols` value. `/etc/hosts` maps
`ckaquestion.k8s.local` to the Service's ClusterIP. The Deployment has been
restarted so nginx loaded the new config. TLS 1.3 works, and TLS 1.2 fails or
works exactly as the setup output says.

## 60-second review

- [ ] The ConfigMap has the required `ssl_protocols` value.
- [ ] If the ConfigMap is immutable, it was recreated with `immutable: true`.
- [ ] `/etc/hosts` maps the hostname to the Service ClusterIP.
- [ ] The Deployment was restarted; the old pod is not serving the old config.
- [ ] `curl --tlsv1.3` succeeds.
- [ ] `curl --tls-max 1.2` matches the setup's expected result.
- [ ] `openssl s_client` confirms the same protocol behavior.

## Detailed checks

### 1. Inspect the ConfigMap

```bash
kubectl get configmap nginx-config -n nginx-static -o yaml
kubectl get configmap nginx-config -n nginx-static \
  -o jsonpath='{.immutable}{"\n"}'
```

Expected: `data.nginx.conf` contains `ssl_protocols <REQUIRED_PROTOCOLS>`.
The immutable field should match the setup:

- variants 1–2: mutable (`false` or absent);
- variant 3: `true`, and the ConfigMap must be a recreated object, not an
  in-place edit.

If the ConfigMap is immutable, an attempted `kubectl edit` or `kubectl patch`
will fail. That is expected; delete and recreate it with the required data and
`immutable: true`.

### 2. Confirm the Service IP and hosts entry

```bash
kubectl get svc nginx-static -n nginx-static -o wide
CLUSTER_IP=$(kubectl get svc nginx-static -n nginx-static -o jsonpath='{.spec.clusterIP}')
grep -n 'ckaquestion.k8s.local' /etc/hosts
getent hosts ckaquestion.k8s.local
```

Expected: the `/etc/hosts` line points `ckaquestion.k8s.local` at `$CLUSTER_IP`.
The hostname must resolve to the Service ClusterIP, not a node IP or the pod
IP.

### 3. Confirm the Deployment was restarted

```bash
kubectl get pods -n nginx-static -o wide
kubectl rollout status deployment/nginx-static -n nginx-static --timeout=180s
```

Expected: a new nginx pod, with no old pod still serving the previous config.
For the immutable variant, scaling to zero and back (or deleting/recreating the
Deployment) is the reliable way to avoid the kubelet's cached ConfigMap.

Check the loaded nginx configuration inside the pod:

```bash
kubectl exec deploy/nginx-static -n nginx-static -- nginx -T 2>&1 | grep -A2 ssl_protocols
```

Expected: the running nginx config shows `<REQUIRED_PROTOCOLS>`, not the
initial value.

### 4. Test with curl

The self-signed certificate means `-k` is required:

```bash
curl -vk --tls-max 1.2 https://ckaquestion.k8s.local
curl -vk --tlsv1.3 https://ckaquestion.k8s.local
```

Expected:

- `--tlsv1.3` succeeds and returns the `Hello TLS` body.
- `--tls-max 1.2` either fails with a TLS handshake error (TLS 1.3-only
  variants) or succeeds (the variant that requires TLS 1.2 and 1.3).

Use the setup output as the authority; do not assume TLS 1.2 must always fail.

### 5. Confirm at the protocol level with openssl

```bash
openssl s_client -connect ckaquestion.k8s.local:443 -tls1_2 </dev/null
openssl s_client -connect ckaquestion.k8s.local:443 -tls1_3 </dev/null
```

Expected:

- `-tls1_3` completes the handshake.
- `-tls1_2` fails when the ConfigMap is TLS 1.3-only, or completes when the
  variant requires both protocols.

Look for the certificate subject and the negotiated protocol in the output.
This is a stronger check than curl because it isolates the TLS version from
HTTP behavior.

### 6. Check certificate content

```bash
openssl s_client -connect ckaquestion.k8s.local:443 -tls1_3 </dev/null 2>/dev/null \
  | openssl x509 -noout -subject -dates
```

Expected: the certificate subject reflects the lab hostname and the dates are
valid. This confirms the Secret mounted into nginx is the one being served.

## Common false positives

| Symptom | Likely cause |
|---|---|
| ConfigMap changed, but TLS behavior is old | The Deployment was not restarted |
| Old pod still Running | Rolling update reused the cached immutable ConfigMap |
| `/etc/hosts` points at the node IP | It must point at the Service ClusterIP |
| `curl` cannot resolve the hostname | Missing or misspelled hosts entry |
| TLS 1.2 still works when it should fail | nginx loaded the old config, or `ssl_protocols` is wrong |
| `kubectl edit` fails on the ConfigMap | It is immutable; delete and recreate it |
| Certificate error with `curl -k` | `-k` was omitted, or the Secret is not mounted |

## Cleanup

```bash
scripts/cleanup-question.sh 17
```

Cleanup removes the namespace resources and the `/etc/hosts` entry.
