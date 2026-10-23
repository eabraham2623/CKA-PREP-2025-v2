# Solution Notes for Question 2 - ArgoCD Helm template
#
# LabSetUp.bash prints the repo name, namespace, chart version, output path, and
# the variant-specific chart value for this run. Substitute those values below.

# Step 1: create the namespace
kubectl create namespace <NAMESPACE>

# Step 2: add the official Argo CD repository and refresh it
helm repo add <REPO_NAME> https://argoproj.github.io/argo-helm
helm repo update

# Step 3: inspect the chart values to find the CRD and variant-specific settings
helm show values <REPO_NAME>/argo-cd --version <CHART_VERSION> | grep -i crd -C 4
helm show values <REPO_NAME>/argo-cd --version <CHART_VERSION> | grep -iE 'replicas|service' -A 6

# Step 4: generate the template. Use ONE of the variant value forms shown by setup:
#   replica variants:      --set server.replicas=<N>
#   service-type variants: --set server.service.type=<TYPE>
helm template argocd <REPO_NAME>/argo-cd --version <CHART_VERSION> \
  --set crds.install=false \
  --set <VARIANT_VALUE_KEY>=<VARIANT_VALUE> \
  --namespace <NAMESPACE> > <OUTPUT_FILE>

# Optional: install the chart with the same values
helm install argocd <REPO_NAME>/argo-cd --version <CHART_VERSION> \
  --set crds.install=false \
  --set <VARIANT_VALUE_KEY>=<VARIANT_VALUE> \
  --namespace <NAMESPACE>

cat <OUTPUT_FILE>   # confirm output
grep -c 'kind: CustomResourceDefinition' <OUTPUT_FILE> || true  # should print 0

# Additional Helm tips:
# To list all versions of a chart: helm search repo <REPO_NAME>/argo-cd --versions
# To show values of a chart: helm show values <REPO_NAME>/argo-cd --version <CHART_VERSION>
