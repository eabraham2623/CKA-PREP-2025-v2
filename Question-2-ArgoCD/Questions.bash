# Question ArgoCD

# Task
# Install Argo CD in a Kubernetes cluster using Helm while ensuring the CRDs are not installed
# (as they are pre-installed).
# The lab setup prints the exact Helm repo name, namespace, chart version, output path,
# and the additional chart value required for this run. Use those values below.

# 1. Add the official Argo CD Helm repository using the repo name printed by setup
#    (https://argoproj.github.io/argo-helm)
# 2. Create the namespace printed by setup
# 3. Generate a Helm template from the Argo CD chart version printed by setup for that namespace
# 4. Configure the chart so the CRDs are not included and the variant-specific chart value is applied
# 5. Save the generated YAML manifest to the path printed by setup

# Note: The `--skip-crds` Helm flag does NOT reliably prevent CRD installation for all charts.
# Some charts (like argo-cd) bundle CRDs as regular templates controlled by a chart value.
# Hint: search the chart values for the crds setting and set it to false.
# The setup output also states whether to configure the server replica count or server service type.

# Video link - https://youtu.be/e0YGRSjb8CU
