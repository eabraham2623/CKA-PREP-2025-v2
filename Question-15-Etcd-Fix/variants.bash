#!/bin/bash
# Variant presets for Question 15 - Etcd Fix.
#
# The single-fault presets isolate the Tier 1 faults reported in
# variant_notes/deep-research-report.md. Variant 5 reproduces the combined
# control-plane incident described by the same reports.
#
# Variant-specific values live only here. LabSetUp.bash, validate.bash, and
# cleanup.bash read them through variant_config.

VARIANT_COUNT=5

ETCD_LOCAL_ENDPOINT="https://127.0.0.1:2379"
ETCD_PEER_ENDPOINT="https://127.0.0.1:2380"
ETCD_STALE_ENDPOINT="https://192.0.2.100:2379"

SCHEDULER_BAD_CPU="1999m"
CONTROLLER_BAD_CPU="4"
CONTROLLER_BAD_MEMORY="19Mi"

variant_config() {
  local variant="${1:-}"
  local faults=()

  ETCD_FAULT=""
  ETCD_FAULT_VALUE=""
  SCHEDULER_CPU_FAULT=""
  CONTROLLER_CPU_FAULT=""
  CONTROLLER_MEMORY_FAULT=""
  COREDNS_FAULT=""

  case "$variant" in
    1)
      ETCD_FAULT="peer-port"
      ETCD_FAULT_VALUE="$ETCD_PEER_ENDPOINT"
      faults+=("etcd endpoint $ETCD_PEER_ENDPOINT")
      ;;
    2)
      ETCD_FAULT="stale-external"
      ETCD_FAULT_VALUE="$ETCD_STALE_ENDPOINT"
      faults+=("etcd endpoint $ETCD_STALE_ENDPOINT")
      ;;
    3)
      SCHEDULER_CPU_FAULT="$SCHEDULER_BAD_CPU"
      faults+=("kube-scheduler CPU request $SCHEDULER_BAD_CPU")
      ;;
    4)
      CONTROLLER_CPU_FAULT="$CONTROLLER_BAD_CPU"
      faults+=("kube-controller-manager CPU request $CONTROLLER_BAD_CPU")
      ;;
    5)
      ETCD_FAULT="peer-port"
      ETCD_FAULT_VALUE="$ETCD_PEER_ENDPOINT"
      SCHEDULER_CPU_FAULT="$SCHEDULER_BAD_CPU"
      CONTROLLER_MEMORY_FAULT="$CONTROLLER_BAD_MEMORY"
      COREDNS_FAULT="malformed-corefile"
      faults+=(
        "etcd endpoint $ETCD_PEER_ENDPOINT"
        "kube-scheduler CPU request $SCHEDULER_BAD_CPU"
        "kube-controller-manager memory limit $CONTROLLER_BAD_MEMORY"
        "invalid CoreDNS cluster zone"
      )
      ;;
    *)
      echo "Error: unknown variant '$variant' (expected 1..$VARIANT_COUNT)" >&2
      return 1
      ;;
  esac

  local joined="" fault
  for fault in "${faults[@]}"; do
    [[ -n "$joined" ]] && joined+=", "
    joined+="$fault"
  done
  VARIANT_SUMMARY="faults: $joined"
}

variant_question() {
  local variant="${1:-?}"

  cat <<EOF
============================================================
 Question 15: Etcd Fix (Variant $variant/$VARIANT_COUNT)
============================================================

EOF

  case "$variant" in
    1)
      cat <<'EOF'
The control plane is down after a migration from external HA etcd to
local etcd. The kube-apiserver is not starting.

Inspect the control-plane static Pods and their manifests, identify why
the API server cannot reach etcd, and repair it.

Success: kubectl get nodes works and all control-plane Pods in
kube-system are Running.
EOF
      ;;
    2)
      cat <<'EOF'
The control plane is down after a migration from external HA etcd to
local etcd. The kube-apiserver still uses the old external etcd endpoint.

Diagnose the static Pod failure and point the API server at the correct
local etcd client endpoint.

Success: kubectl get nodes works and all control-plane Pods in
kube-system are Running.
EOF
      ;;
    3)
      cat <<'EOF'
kubectl works, but new Pods remain Pending and Deployments do not
produce Running replicas. The kube-scheduler static Pod is not Running.

Inspect its manifest and correct the resource configuration without
changing the scheduler's intended function.

Success: kube-scheduler-<node> is Running and a test Deployment gets its
replicas scheduled.
EOF
      ;;
    4)
      cat <<'EOF'
kubectl works, but Deployments and ReplicaSets do not reconcile. The
kube-controller-manager static Pod is not Running.

Inspect its manifest and correct the resource configuration without
changing the controller-manager's intended function.

Success: kube-controller-manager-<node> is Running and a test
Deployment/ReplicaSet reconciles.
EOF
      ;;
    5)
      cat <<'EOF'
The cluster was migrated and is broken in several ways. The API server is
down. After restoring API access, additional control-plane and DNS faults
become visible.

Diagnose and repair every fault.

Success: kubectl get nodes works, all kube-system Pods are Running, and
cluster DNS resolves kubernetes.default.svc.cluster.local.
EOF
      ;;
    *)
      echo "Unknown variant '$variant'" >&2
      return 1
      ;;
  esac

  cat <<EOF

Video Link - https://youtu.be/IL448T6r8H4

Documentation Reference
Troubleshooting -> Troubleshoot Clusters
https://kubernetes.io/docs/tasks/debug/debug-cluster/
============================================================
EOF
}
