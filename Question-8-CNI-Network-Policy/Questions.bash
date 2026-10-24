# Question
# LabSetUp.bash selects one of two CNI profiles for this run and prints the
# complete question, including the exact version and pod subnet to use.

# Both profiles require:
# 1. Pod-to-pod communication
# 2. Installation from an upstream manifest
# 3. The CNI network to match the cluster's pod subnet

# One profile additionally requires NetworkPolicy enforcement. The other
# requires a VXLAN overlay with no BGP requirement and does not test policy.
# The setup output tells you which profile is active.

#Video Link - https://youtu.be/Uc04Ui4x3EM
