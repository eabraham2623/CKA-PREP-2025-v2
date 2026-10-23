# Solution Notes for Question 6 - CRDs (cert-manager)
#
# LabSetUp.bash prints the exact Certificate spec field for this run. Substitute
# that field for <FIELD_FROM_SETUP> below.

# Step 1: list all cert-manager CRDs
kubectl get crd | grep cert-manager | tee /root/resources.yaml

# Step 2: extract the documentation for the selected Certificate spec field
kubectl explain "certificate.<FIELD_FROM_SETUP>" | tee /root/subject.yaml

# Step 3: verify the saved output
cat /root/resources.yaml
cat /root/subject.yaml
