# Follow the question printed by LabSetUp.bash. It shows the selected CNI
# profile, exact release version, manifest source, and cluster pod subnet.
#
# Calico profile:
#   kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/<version>/manifests/tigera-operator.yaml
#   wget https://raw.githubusercontent.com/projectcalico/calico/<version>/manifests/custom-resources.yaml
#   vim custom-resources.yaml
#   # Set spec.calicoNetwork.bgp: Disabled (the underlay does not exchange BGP).
#   # Set spec.calicoNetwork.ipPools[0].cidr to the cluster pod subnet.
#   kubectl apply -f custom-resources.yaml
#   kubectl get tigerastatus
#   kubectl get pods -n calico-system
#
# VXLAN overlay profile:
#   Download the upstream manifest for the release shown by setup.
#   Edit net-conf.json so Network matches the cluster pod subnet and the
#   backend type remains vxlan.
#   kubectl apply -f kube-flannel.yml
#   kubectl get pods -n kube-flannel
#   kubectl get daemonset -n kube-flannel
#
# Both profiles:
#   kubectl get nodes
#   kubectl get pods -n kube-system
#
# Cleanup removes the installed CNI and restores the pre-Q8 Cilium CNI,
# including kube-proxy replacement.
