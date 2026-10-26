# Question 6 — Manual Verification: cert-manager CRDs

> **Run setup first.** `scripts/run-question.sh 6 [variant]` prints the exact
> target Certificate field and the field-documentation output path. Replace the
> `<...>` placeholders below.
>
> `scripts/validate-question.sh 6` checks the files for the expected markers.
> This file is the human check: it proves the CRD list is complete and that the
> field documentation is real `kubectl explain` output, not a placeholder.

## What success looks like

`/root/resources.yaml` contains all six cert-manager CRDs installed by the
pinned release, and the field-documentation file contains the `kubectl explain`
documentation for the setup's target Certificate spec field.

## 60-second review

- [ ] `/root/resources.yaml` is non-empty and contains exactly the six
      cert-manager CRDs.
- [ ] The CRD file is valid YAML, not a `kubectl get` table.
- [ ] The field-documentation file exists and is non-empty.
- [ ] Its contents match `kubectl explain` for the target field.
- [ ] No unrelated CRDs or wrong fields are included.

## Detailed checks

### 1. List the installed cert-manager CRDs

```bash
kubectl get crd -o name | grep 'cert-manager.io' | sed 's#.*/##'
```

Expected, exactly six:

```text
certificaterequests.cert-manager.io
certificates.cert-manager.io
challenges.acme.cert-manager.io
clusterissuers.cert-manager.io
issuers.cert-manager.io
orders.acme.cert-manager.io
```

Count them:

```bash
kubectl get crd -o name | grep -c 'cert-manager.io'
```

Expected: `6`.

### 2. Inspect the submitted CRD file

```bash
grep -c 'kind: CustomResourceDefinition' /root/resources.yaml || true
grep -n 'name: .*cert-manager.io' /root/resources.yaml
```

Expected: six CRD objects and the six names above.

A common mistake is to save the output of `kubectl get crd` as a table. That is
not a list of CRD manifests. The file should be YAML/JSON produced by
`kubectl get crd ... -o yaml` (or an equivalent manifest list), and it should
contain the CRD spec, not just names.

Optional structural check:

```bash
kubectl apply --dry-run=server -f /root/resources.yaml
```

Expected: the CRDs validate. Do not actually apply them if they are already
installed; the dry run is enough.

### 3. Compare the field documentation

Run the same `kubectl explain` command the task asks for, using the full field
path printed by setup (for example `spec.subject`, not just `subject`):

```bash
kubectl explain certificate.<TARGET_FIELD>
```

For example, for the subject field:

```bash
kubectl explain certificate.spec.subject
```

Open the field file:

```bash
cat <FIELD_FILE>
```

Expected content includes the `GROUP`, `KIND`, `VERSION`, `FIELD`, and
`DESCRIPTION` sections for the target field. For `spec.subject`, useful markers
include `subject`, `organizations`, `postalCodes`, and `provinces`. For other
presets, use the markers shown by the setup output and `kubectl explain`.

The output format is flexible — YAML, JSON, or plain text are acceptable — but
it must contain the actual documentation, not just the field name.

### 4. Check for stale answers

```bash
ls -l /root/resources.yaml <FIELD_FILE>
```

Expected: both files were written during this run. If setup selected a new
variant, an old field file from a previous variant must not be the one you are
inspecting.

## Common false positives

| Symptom | Likely cause |
|---|---|
| Fewer or more than six CRDs | Other operators are installed, or the cert-manager list is incomplete |
| File contains a table | `kubectl get crd` was run without `-o yaml`/`-o json` |
| Field file is empty | The redirect target was wrong or `kubectl explain` failed |
| Field file documents another field | A stale file from the previous variant |
| Markers appear only in a heading | The file contains the field name but not the actual description |
| `kubectl explain` fails | The cert-manager CRDs are not established yet; wait and retry |

## Cleanup

```bash
scripts/cleanup-question.sh 6
```

Cleanup removes the CRDs, namespace, answer files, and recorded variant.
