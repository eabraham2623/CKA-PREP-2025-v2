# Question 2 — Manual Verification: Argo CD Helm Template

> **Run setup first.** `scripts/run-question.sh 2 [variant]` prints the exact
> Helm repo alias, namespace, chart version, output path, and the extra chart
> value for this run. Replace the `<...>` placeholders below with those values.
>
> `scripts/validate-question.sh 2` checks the rendered file. This file is the
> human check: it proves the template is reproducible, contains no CRDs, and
> really is a template rather than an installed release.

## What success looks like

The generated YAML is a complete Argo CD manifest for the requested namespace
and chart version, with CRDs excluded and the variant-specific chart value
applied. No Helm release is installed in the cluster.

## 60-second review

- [ ] The Helm repo is registered with the printed alias and URL.
- [ ] The target namespace exists.
- [ ] The output file exists, is non-empty, and contains the expected chart.
- [ ] The file contains **zero** `CustomResourceDefinition` objects.
- [ ] The variant-specific value is visible in the rendered objects.
- [ ] `helm list` shows no installed release.

## Detailed checks

### 1. Confirm the repository and namespace

```bash
helm repo list | grep <REPO>
kubectl get namespace <NS>
```

Expected: the repo alias points at `https://argoproj.github.io/argo-helm`, and
the namespace is `Active`.

### 2. Confirm this is a template, not an install

```bash
helm list -n <NS>
```

Expected: no releases. The task asks for `helm template` output, not
`helm install`.

### 3. Inspect the rendered manifest

```bash
grep -c '^kind: CustomResourceDefinition' <OUTPUT> || true
grep 'helm.sh/chart: argo-cd-<CHART_VERSION>' <OUTPUT>
grep 'namespace: <NS>' <OUTPUT>
```

Expected: the CRD count is `0`; the chart label is exactly
`argo-cd-<CHART_VERSION>`; resources that belong in the namespace show `<NS>`.

`--skip-crds` alone is not enough for this chart. Search the chart values for
the CRD switch and confirm it was set to false in the command that generated
the file. If any `CustomResourceDefinition` remains, the solution is incomplete
even if the file looks plausible.

### 4. Verify the variant-specific value

Inspect the rendered server objects:

```bash
grep -n 'argocd-server' <OUTPUT>
```

- If the setup asked for a **service type**, find the `argocd-server` Service
  and confirm `type: <VALUE>`.
- If the setup asked for **replicas**, find the `argocd-server` Deployment and
  confirm `replicas: <VALUE>`.

The exact requirement is printed by setup; do not assume it is always the same
value.

### 5. Re-render and compare

Run the same `helm template` command again into a temporary file and diff it
against the submitted file:

```bash
helm template <RELEASE_NAME> <REPO>/argo-cd \
  --version <CHART_VERSION> \
  --namespace <NS> \
  --set crds.install=false \
  --set <VARIANT_VALUE_KEY>=<VARIANT_VALUE> > /tmp/argo-check.yaml
diff -u <OUTPUT> /tmp/argo-check.yaml
```

Expected: no differences. A small diff is usually an omitted value or a
different chart version. Use the animated command from your shell history as
the source of truth, not a guessed command.

## Common false positives

| Symptom | Likely cause |
|---|---|
| CRDs appear in the file | Only `--skip-crds` was used; the chart's CRD value was not disabled |
| Output is empty or missing | Wrong output path, or the redirect failed |
| Wrong chart version | `--version` omitted or typo |
| No variant value | The extra `--set` value was not applied |
| `helm list` shows a release | `helm install` was used instead of `helm template` |
| Namespace missing | Step 2 was skipped; the template does not create it |

## Cleanup

```bash
scripts/cleanup-question.sh 2
```

Cleanup removes the namespace, any releases, and the generated output file.
