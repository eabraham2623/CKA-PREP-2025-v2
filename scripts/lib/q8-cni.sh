#!/bin/bash
# Shared helpers for Question 8 - CNI & Network Policy.
#
# Question 8 removes the preinstalled Cilium CNI and asks the learner to
# install either Calico or a VXLAN-overlay CNI. These helpers:
#   - snapshot the pre-Q8 Cilium state before setup removes it
#   - remove either installed CNI and its host-level artifacts
#   - restore Cilium (including kube-proxy replacement) during cleanup
#
# This file is meant to be sourced, not executed.

cka_q8_root() {
  local lib_dir
  lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cd "$lib_dir/../.." && pwd
}

cka_q8_state_dir() {
  printf '%s/.cka-state/q8-cilium\n' "$(cka_q8_root)"
}

cka_q8_pod_subnet() {
  local cfg subnet

  cfg="$(kubectl -n kube-system get cm kubeadm-config \
    -o jsonpath='{.data.ClusterConfiguration}' 2>/dev/null || true)"
  subnet="$(printf '%s\n' "$cfg" | awk '/^[[:space:]]*podSubnet:[[:space:]]*/ {print $2; exit}')"
  subnet="${subnet%\"}"
  subnet="${subnet#\"}"

  if [[ ! "$subnet" =~ ^[0-9a-fA-F:.]+/[0-9]+$ ]]; then
    echo "Error: could not determine the cluster pod subnet from kubeadm-config." >&2
    return 1
  fi

  printf '%s\n' "$subnet"
}

cka_q8_node_exists() {
  kubectl get node "$1" >/dev/null 2>&1
}

cka_q8_local_has_file() {
  sudo test -f "$1"
}

cka_q8_node_has_file() {
  local node="$1" file="$2"
  if [[ "$node" == "controlplane" || "$node" == "$(hostname)" ]]; then
    cka_q8_local_has_file "$file"
  else
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      "$node" "sudo test -f '$file'" >/dev/null 2>&1
  fi
}

cka_q8_run_host_script() {
  local script="$1"
  local rc=0 tmp

  tmp="$(mktemp /tmp/cka-q8-host.XXXXXX)" || return 1
  printf '%s\n' "$script" > "$tmp"
  chmod 700 "$tmp"

  if ! sudo bash "$tmp" >/dev/null 2>&1; then
    rc=1
  fi

  if cka_q8_node_exists node01; then
    if ! ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      node01 'sudo bash -s' < "$tmp" >/dev/null 2>&1; then
      echo "Warning: host CNI cleanup failed on node01." >&2
      rc=1
    fi
  fi

  rm -f "$tmp"
  return "$rc"
}

cka_q8_remove_other_cni_host() {
  local script
  read -r -d '' script <<'EOF' || true
#!/bin/bash
set -u
find /etc/cni/net.d -maxdepth 1 -type f \
  \( -name '*calico*' -o -name '*canal*' -o -name '*flannel*' \) \
  ! -name '*.cilium_bak' -delete 2>/dev/null || true
rm -f /opt/cni/bin/calico /opt/cni/bin/calico-ipam /opt/cni/bin/flannel
rm -rf /run/flannel /var/run/calico /var/lib/calico
for iface in vxlan.calico flannel.1 tunl0; do
  ip link delete "$iface" 2>/dev/null || true
done
for link in $(ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | sed 's/@.*//' | grep '^cali' || true); do
  ip link delete "$link" 2>/dev/null || true
done
EOF
  cka_q8_run_host_script "$script"
}

cka_q8_remove_cilium_host() {
  local script
  read -r -d '' script <<'EOF' || true
#!/bin/bash
set -u
find /etc/cni/net.d -maxdepth 1 -type f -name '*cilium*' \
  ! -name '*.cilium_bak' -delete 2>/dev/null || true
rm -f /opt/cni/bin/cilium-cni
rm -rf /var/run/cilium
for iface in cilium_host cilium_net cilium_vxlan; do
  ip link delete "$iface" 2>/dev/null || true
done
EOF
  cka_q8_run_host_script "$script"
}

cka_q8_stop_cilium() {
  # Stop the Cilium workloads but keep its Helm release, CRDs, RBAC,
  # ConfigMaps, and secrets so cleanup can restore the CNI reliably.
  kubectl delete deployment cilium-operator -n kube-system \
    --ignore-not-found --wait=true --timeout=120s >/dev/null 2>&1 || true
  kubectl delete daemonset cilium cilium-envoy -n kube-system \
    --ignore-not-found --wait=true --timeout=120s >/dev/null 2>&1 || true
}

cka_q8_cleanup_flannel() {
  local rc=0

  kubectl delete daemonset kube-flannel-ds -n kube-flannel \
    --ignore-not-found --wait=true --timeout=120s >/dev/null 2>&1 || rc=1
  kubectl delete namespace kube-flannel \
    --ignore-not-found --wait=true --timeout=120s >/dev/null 2>&1 || rc=1
  kubectl delete clusterrole flannel --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete clusterrolebinding flannel --ignore-not-found >/dev/null 2>&1 || true
  kubectl annotate nodes --all \
    flannel.alpha.coreos.com/backend-data- \
    flannel.alpha.coreos.com/backend-type- \
    flannel.alpha.coreos.com/kube-subnet-manager- \
    flannel.alpha.coreos.com/public-ip- \
    --overwrite >/dev/null 2>&1 || true

  return "$rc"
}

cka_q8_calico_namespaces_remain() {
  local ns
  for ns in tigera-operator calico-system calico-apiserver; do
    kubectl get namespace "$ns" >/dev/null 2>&1 && return 0
  done
  return 1
}

cka_q8_clear_calico_sa_finalizers() {
  local ns
  for ns in tigera-operator calico-system calico-apiserver; do
    kubectl get namespace "$ns" >/dev/null 2>&1 || continue
    kubectl get serviceaccount -n "$ns" -o name 2>/dev/null \
      | xargs -r -n1 kubectl patch -n "$ns" --type=merge \
          -p '{"metadata":{"finalizers":null}}' >/dev/null 2>&1 || true
  done
}

cka_q8_calico_cr_present() {
  kubectl get installations.operator.tigera.io >/dev/null 2>&1 \
    || kubectl get apiservers.operator.tigera.io >/dev/null 2>&1
}

cka_q8_clear_calico_cr_finalizers() {
  local kind
  for kind in installations.operator.tigera.io apiservers.operator.tigera.io; do
    kubectl get "$kind" -o name 2>/dev/null \
      | xargs -r -n1 kubectl patch --type=merge \
          -p '{"metadata":{"finalizers":null}}' >/dev/null 2>&1 || true
  done
}

cka_q8_tigera_operator_running() {
  local available
  available="$(kubectl get deployment tigera-operator -n tigera-operator \
    -o jsonpath='{.status.availableReplicas}' 2>/dev/null)"
  [[ "$available" =~ ^[0-9]+$ && "$available" -ge 1 ]]
}

cka_q8_cleanup_calico() {
  local crd rc=0 waited=0 remaining=""

  # Let the still-running operator run its own cleanup finalizers. The
  # APIServer CR owns one of the Installation finalizers, so delete it
  # first. Deleting the operator before these CRs are gone would leave the
  # finalizers unowned and block CRD deletion forever.
  if cka_q8_tigera_operator_running; then
    kubectl delete apiserver default --ignore-not-found \
      --wait=true --timeout=120s >/dev/null 2>&1 || true
    kubectl delete installation default --ignore-not-found \
      --wait=true --timeout=120s >/dev/null 2>&1 || true
  else
    kubectl delete apiserver default installation default --ignore-not-found \
      --wait=false >/dev/null 2>&1 || true
  fi

  # An interrupted or operator-less cleanup can leave the CRs terminating.
  if cka_q8_calico_cr_present; then
    cka_q8_clear_calico_cr_finalizers
    kubectl delete installations.operator.tigera.io,apiservers.operator.tigera.io \
      --all --ignore-not-found --wait=false >/dev/null 2>&1 || true
  fi

  kubectl delete daemonset calico-node -n calico-system --ignore-not-found --wait=false >/dev/null 2>&1 || true
  kubectl delete daemonset calico-node -n kube-system --ignore-not-found --wait=false >/dev/null 2>&1 || true
  kubectl delete deployment calico-kube-controllers -n calico-system --ignore-not-found --wait=false >/dev/null 2>&1 || true
  kubectl delete deployment calico-kube-controllers -n kube-system --ignore-not-found --wait=false >/dev/null 2>&1 || true

  # The Tigera operator puts a tigera.io/cni-protector finalizer on its
  # service accounts. Removing the operator before it clears those leaves
  # the namespace Terminating forever, so clear them first.
  cka_q8_clear_calico_sa_finalizers

  kubectl delete namespace tigera-operator calico-system calico-apiserver \
    --ignore-not-found --wait=false >/dev/null 2>&1 || rc=1

  # Bounded wait so cleanup can never hang on an operator-owned finalizer.
  while (( waited < 180 )); do
    cka_q8_calico_namespaces_remain || break
    cka_q8_clear_calico_sa_finalizers
    sleep 5
    waited=$((waited + 5))
  done
  if cka_q8_calico_namespaces_remain; then
    echo "Warning: Calico namespaces are still terminating." >&2
    rc=1
  fi

  # CRs must be gone (or at least releasable) before their CRDs can finish
  # deleting, otherwise customresourcecleanup retries for 60s at a time.
  cka_q8_clear_calico_cr_finalizers
  kubectl delete installations.operator.tigera.io,apiservers.operator.tigera.io \
    --all --ignore-not-found --wait=false >/dev/null 2>&1 || true

  for crd in \
    ippools.crd.projectcalico.org \
    ipamblocks.crd.projectcalico.org \
    ipamconfigs.crd.projectcalico.org \
    ipamhandles.crd.projectcalico.org \
    blockaffinities.crd.projectcalico.org \
    felixconfigurations.crd.projectcalico.org \
    bgpconfigurations.crd.projectcalico.org \
    bgpfilters.crd.projectcalico.org \
    bgppeers.crd.projectcalico.org \
    clusterinformations.crd.projectcalico.org \
    hostendpoints.crd.projectcalico.org \
    globalnetworkpolicies.crd.projectcalico.org \
    globalnetworksets.crd.projectcalico.org \
    networkpolicies.crd.projectcalico.org \
    networksets.crd.projectcalico.org \
    caliconodestatuses.crd.projectcalico.org; do
    kubectl delete "$crd" --all --ignore-not-found --wait=false >/dev/null 2>&1 || true
  done

  kubectl get crd -o name 2>/dev/null \
    | grep -E 'projectcalico\.org$|operator\.tigera\.io$' \
    | xargs -r kubectl delete --ignore-not-found --wait=false >/dev/null 2>&1 || true

  # customresourcecleanup retries for 60s at a time when it cannot finish,
  # so bound the wait and force-clear finalizers on anything left.
  waited=0
  remaining=""
  while (( waited < 120 )); do
    remaining="$(kubectl get crd -o name 2>/dev/null \
      | grep -E 'projectcalico\.org$|operator\.tigera\.io$' || true)"
    [[ -z "$remaining" ]] && break
    sleep 5
    waited=$((waited + 5))
  done
  if [[ -n "$remaining" ]]; then
    echo "Warning: clearing finalizers on remaining Calico CRDs." >&2
    printf '%s\n' "$remaining" \
      | xargs -r -n1 kubectl patch --type=merge \
          -p '{"metadata":{"finalizers":null}}' >/dev/null 2>&1 || true
    sleep 5
    remaining="$(kubectl get crd -o name 2>/dev/null \
      | grep -E 'projectcalico\.org$|operator\.tigera\.io$' || true)"
    if [[ -n "$remaining" ]]; then
      echo "Warning: Calico CRDs are still present." >&2
      rc=1
    fi
  fi

  kubectl get clusterrole,clusterrolebinding -o name 2>/dev/null \
    | grep -Ei 'calico|tigera|canal' \
    | xargs -r kubectl delete --ignore-not-found --wait=false >/dev/null 2>&1 || true
  # Automanaged APIServices are recreated while their CRD still exists, so
  # never wait for deletion here.
  kubectl get apiservice -o name 2>/dev/null \
    | grep -Ei 'projectcalico|tigera' \
    | xargs -r kubectl delete --ignore-not-found --wait=false >/dev/null 2>&1 || true

  return "$rc"
}

cka_q8_cleanup_canal() {
  kubectl delete daemonset canal -n kube-system --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete deployment calico-kube-controllers -n kube-system --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete configmap canal-config -n kube-system --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete serviceaccount canal calico-cni-plugin calico-kube-controllers \
    -n kube-system --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete poddisruptionbudget calico-kube-controllers \
    -n kube-system --ignore-not-found >/dev/null 2>&1 || true
}

cka_q8_cleanup_other_cnis() {
  local rc=0

  cka_q8_cleanup_flannel || rc=1
  cka_q8_cleanup_canal || rc=1
  cka_q8_cleanup_calico || rc=1

  return "$rc"
}

cka_q8_other_cni_present() {
  kubectl get namespace kube-flannel >/dev/null 2>&1 \
    || kubectl get namespace calico-system >/dev/null 2>&1 \
    || kubectl get namespace tigera-operator >/dev/null 2>&1 \
    || kubectl get daemonset canal -n kube-system >/dev/null 2>&1 \
    || kubectl get daemonset calico-node -n kube-system >/dev/null 2>&1
}

cka_q8_snapshot_exists() {
  [[ -f "$(cka_q8_state_dir)/restore.env" ]]
}

cka_q8_clear_snapshot() {
  rm -rf "$(cka_q8_state_dir)"
}

cka_q8_cilium_present() {
  helm status cilium -n kube-system >/dev/null 2>&1 \
    || kubectl get daemonset cilium -n kube-system >/dev/null 2>&1 \
    || kubectl get deployment cilium-operator -n kube-system >/dev/null 2>&1
}

cka_q8_snapshot_cilium() {
  local dir parent tmp meta chart version app

  dir="$(cka_q8_state_dir)"
  parent="$(dirname "$dir")"
  mkdir -p "$parent" || return 1

  if helm status cilium -n kube-system >/dev/null 2>&1; then
    tmp="$(mktemp -d "${dir}.tmp.XXXXXX")" || return 1
    if ! helm get values cilium -n kube-system --all > "$tmp/values.yaml"; then
      rm -rf "$tmp"
      return 1
    fi
    if ! helm get manifest cilium -n kube-system > "$tmp/manifest.yaml"; then
      rm -rf "$tmp"
      return 1
    fi

    meta="$(helm get metadata cilium -n kube-system -o json 2>/dev/null || true)"
    chart="$(printf '%s' "$meta" | jq -r '.chart // "cilium"' 2>/dev/null || echo cilium)"
    version="$(printf '%s' "$meta" | jq -r '.version // empty' 2>/dev/null || true)"
    app="$(printf '%s' "$meta" | jq -r '.appVersion // empty' 2>/dev/null || true)"

    if [[ -z "$version" ]]; then
      rm -rf "$tmp"
      echo "Error: could not determine the installed Cilium chart version." >&2
      return 1
    fi

    cat > "$tmp/restore.env" <<EOF
CILIUM_METHOD=helm
CILIUM_RELEASE=cilium
CILIUM_NAMESPACE=kube-system
CILIUM_CHART=$chart
CILIUM_VERSION=$version
CILIUM_APP_VERSION=$app
EOF
    chmod 700 "$tmp"
    chmod 600 "$tmp/restore.env" "$tmp/values.yaml" "$tmp/manifest.yaml"
    rm -rf "$dir"
    mv "$tmp" "$dir"
    return 0
  fi

  if kubectl get daemonset cilium -n kube-system >/dev/null 2>&1; then
    tmp="$(mktemp -d "${dir}.tmp.XXXXXX")" || return 1
    if command -v jq >/dev/null 2>&1; then
      kubectl get daemonset cilium cilium-envoy -n kube-system -o json 2>/dev/null \
        | jq 'del(.items[]?.metadata.resourceVersion, .items[]?.metadata.uid, .items[]?.metadata.creationTimestamp, .items[]?.metadata.generation, .items[]?.status)' \
        > "$tmp/live-daemonsets.json" || { rm -rf "$tmp"; return 1; }
      kubectl get deployment cilium-operator -n kube-system -o json 2>/dev/null \
        | jq 'del(.metadata.resourceVersion, .metadata.uid, .metadata.creationTimestamp, .metadata.generation, .status)' \
        > "$tmp/live-operator.json" || { rm -rf "$tmp"; return 1; }
      kubectl get configmap cilium-config -n kube-system -o json 2>/dev/null \
        | jq 'del(.metadata.resourceVersion, .metadata.uid, .metadata.creationTimestamp, .metadata.generation)' \
        > "$tmp/live-config.json" || { rm -rf "$tmp"; return 1; }
    else
      kubectl get daemonset cilium cilium-envoy -n kube-system -o yaml \
        > "$tmp/live-daemonsets.yaml" 2>/dev/null || { rm -rf "$tmp"; return 1; }
      kubectl get deployment cilium-operator -n kube-system -o yaml \
        > "$tmp/live-operator.yaml" 2>/dev/null || { rm -rf "$tmp"; return 1; }
      kubectl get configmap cilium-config -n kube-system -o yaml \
        > "$tmp/live-config.yaml" 2>/dev/null || { rm -rf "$tmp"; return 1; }
    fi

    cat > "$tmp/restore.env" <<EOF
CILIUM_METHOD=live
CILIUM_RELEASE=cilium
CILIUM_NAMESPACE=kube-system
EOF
    chmod 700 "$tmp"
    chmod 600 "$tmp/restore.env" "$tmp"/live-* 2>/dev/null || true
    rm -rf "$dir"
    mv "$tmp" "$dir"
    return 0
  fi

  return 2
}

cka_q8_wait_for_ready() {
  kubectl rollout status daemonset/cilium -n kube-system --timeout=300s >/dev/null 2>&1 || return 1
  if kubectl get daemonset cilium-envoy -n kube-system >/dev/null 2>&1; then
    kubectl rollout status daemonset/cilium-envoy -n kube-system --timeout=300s >/dev/null 2>&1 || return 1
  fi
  kubectl rollout status deployment/cilium-operator -n kube-system --timeout=300s >/dev/null 2>&1 || return 1
  kubectl wait --for=condition=Ready nodes --all --timeout=300s >/dev/null 2>&1 || return 1

  kubectl rollout restart deployment/coredns -n kube-system >/dev/null 2>&1 || return 1
  kubectl rollout status deployment/coredns -n kube-system --timeout=300s >/dev/null 2>&1 || return 1

  cka_q8_node_has_file controlplane /etc/cni/net.d/05-cilium.conflist || return 1
  if cka_q8_node_exists node01; then
    cka_q8_node_has_file node01 /etc/cni/net.d/05-cilium.conflist || return 1
  fi

  if command -v cilium >/dev/null 2>&1; then
    timeout 300 cilium status --wait >/dev/null 2>&1 || return 1
  fi

  return 0
}

cka_q8_cilium_healthy() {
  local desired ready available

  kubectl get daemonset cilium -n kube-system >/dev/null 2>&1 || return 1
  desired="$(kubectl get daemonset cilium -n kube-system -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null)"
  ready="$(kubectl get daemonset cilium -n kube-system -o jsonpath='{.status.numberReady}' 2>/dev/null)"
  [[ "$desired" =~ ^[0-9]+$ && "$desired" -gt 0 && "$ready" == "$desired" ]] || return 1

  if kubectl get daemonset cilium-envoy -n kube-system >/dev/null 2>&1; then
    desired="$(kubectl get daemonset cilium-envoy -n kube-system -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null)"
    ready="$(kubectl get daemonset cilium-envoy -n kube-system -o jsonpath='{.status.numberReady}' 2>/dev/null)"
    [[ "$desired" =~ ^[0-9]+$ && "$desired" -gt 0 && "$ready" == "$desired" ]] || return 1
  fi

  kubectl get deployment cilium-operator -n kube-system >/dev/null 2>&1 || return 1
  available="$(kubectl get deployment cilium-operator -n kube-system -o jsonpath='{.status.availableReplicas}' 2>/dev/null)"
  [[ "$available" =~ ^[0-9]+$ && "$available" -ge 1 ]] || return 1

  cka_q8_node_has_file controlplane /etc/cni/net.d/05-cilium.conflist || return 1
  if cka_q8_node_exists node01; then
    cka_q8_node_has_file node01 /etc/cni/net.d/05-cilium.conflist || return 1
  fi

  return 0
}

cka_q8_restore_cilium() {
  local dir method release namespace chart version
  dir="$(cka_q8_state_dir)"
  [[ -f "$dir/restore.env" ]] || return 2

  # shellcheck disable=SC1090
  source "$dir/restore.env"
  method="${CILIUM_METHOD:-helm}"
  release="${CILIUM_RELEASE:-cilium}"
  namespace="${CILIUM_NAMESPACE:-kube-system}"
  chart="${CILIUM_CHART:-cilium}"
  version="${CILIUM_VERSION:-}"

  if [[ "$method" == "helm" ]]; then
    if [[ -z "$version" ]]; then
      echo "Error: Cilium snapshot has no chart version." >&2
      return 1
    fi

    if helm status "$release" -n "$namespace" >/dev/null 2>&1; then
      helm upgrade --install "$release" "$chart" \
        --repo https://helm.cilium.io/ --version "$version" \
        -n "$namespace" --reuse-values --wait --timeout 10m \
        >/dev/null 2>&1 && cka_q8_wait_for_ready && return 0
    else
      helm install "$release" "$chart" \
        --repo https://helm.cilium.io/ --version "$version" \
        -n "$namespace" -f "$dir/values.yaml" --wait --timeout 10m \
        >/dev/null 2>&1 && cka_q8_wait_for_ready && return 0
    fi

    # The existing release may be in a bad state. Reinstall from the
    # snapshot values, then fall back to the saved manifest.
    if helm status "$release" -n "$namespace" >/dev/null 2>&1; then
      helm uninstall "$release" -n "$namespace" --wait --timeout 5m >/dev/null 2>&1 || true
    fi
    helm install "$release" "$chart" \
      --repo https://helm.cilium.io/ --version "$version" \
      -n "$namespace" -f "$dir/values.yaml" --wait --timeout 10m \
      >/dev/null 2>&1 && cka_q8_wait_for_ready && return 0

    kubectl apply -f "$dir/manifest.yaml" >/dev/null 2>&1 \
      && cka_q8_wait_for_ready && return 0
    return 1
  fi

  if [[ "$method" == "live" ]]; then
    if [[ -f "$dir/live-daemonsets.json" ]]; then
      kubectl apply -f "$dir/live-daemonsets.json" >/dev/null 2>&1 || return 1
      kubectl apply -f "$dir/live-operator.json" >/dev/null 2>&1 || return 1
      kubectl apply -f "$dir/live-config.json" >/dev/null 2>&1 || return 1
    else
      kubectl apply -f "$dir/live-daemonsets.yaml" >/dev/null 2>&1 || return 1
      kubectl apply -f "$dir/live-operator.yaml" >/dev/null 2>&1 || return 1
      kubectl apply -f "$dir/live-config.yaml" >/dev/null 2>&1 || return 1
    fi
    cka_q8_wait_for_ready && return 0
    return 1
  fi

  return 1
}
