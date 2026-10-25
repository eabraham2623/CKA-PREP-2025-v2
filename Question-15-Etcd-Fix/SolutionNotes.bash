# Question 15 - control-plane troubleshooting runbook
#
# The setup prints the exact variant. These notes cover every fault pattern
# used by the lab; do not assume the current run uses only the first one.

# 1. Work out whether the API is available.
kubectl get nodes
kubectl get --raw='/readyz'
sudo crictl ps -a | grep -E 'kube-apiserver|etcd|kube-scheduler|kube-controller-manager'
sudo crictl logs "<container-id>"
sudo journalctl -u kubelet -n 100 --no-pager

# 2. If the API is down, inspect the static Pod manifests.
sudo ls -la /etc/kubernetes/manifests/
sudo cat /etc/kubernetes/manifests/kube-apiserver.yaml
sudo cat /etc/kubernetes/manifests/etcd.yaml

# The API server must use etcd's client endpoint, normally:
#   --etcd-servers=https://127.0.0.1:2379
# Port 2380 is etcd's Raft peer port, and an old external IP/hostname may
# remain after the migration.
sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml
# kubelet recreates the static Pod when the manifest changes.
sudo crictl ps -a | grep kube-apiserver
kubectl get nodes

# 3. If the API is up but workloads are not progressing, check the
#    scheduler and controller-manager static Pods.
kubectl -n kube-system get pods -o wide
kubectl -n kube-system describe pod -l component=kube-scheduler
kubectl -n kube-system describe pod -l component=kube-controller-manager
sudo cat /etc/kubernetes/manifests/kube-scheduler.yaml
sudo cat /etc/kubernetes/manifests/kube-controller-manager.yaml

# Look for a CPU request or memory limit that cannot fit on the node.
# Lower an excessive request or raise/remove an unusably low limit. Keep the
# component's intended command-line flags unchanged.
sudo vi /etc/kubernetes/manifests/kube-scheduler.yaml
sudo vi /etc/kubernetes/manifests/kube-controller-manager.yaml

# 4. If the control plane is healthy but DNS is broken, inspect CoreDNS.
kubectl -n kube-system get pods -l k8s-app=kube-dns
kubectl -n kube-system logs -l k8s-app=kube-dns
kubectl -n kube-system get configmap coredns -o yaml
# Repair the Corefile (the kubernetes plugin must serve the cluster.local
# zone), then restart the Deployment:
kubectl -n kube-system rollout restart deployment/coredns
kubectl -n kube-system rollout status deployment/coredns
kubectl run dns-check --image=busybox:1.36 --restart=Never --rm -it -- \
  nslookup kubernetes.default.svc.cluster.local

# 5. Verify the complete recovery.
kubectl get nodes
kubectl -n kube-system get pods
kubectl -n kube-system get --raw='/readyz'
