#!/bin/bash
# Shared runtime helpers for Question 15 - Etcd Fix variants.
#
# This file is sourced by LabSetUp.bash, validate.bash, and cleanup.bash.
# It owns the pristine control-plane snapshot and all manifest edits so a
# variant switch always starts from the same known-good state.

Q15_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
Q15_REPO_ROOT="$(cd "$Q15_LIB_DIR/.." && pwd)"

Q15_MANIFEST_DIR="/etc/kubernetes/manifests"
Q15_APISERVER_MANIFEST="$Q15_MANIFEST_DIR/kube-apiserver.yaml"
Q15_SCHEDULER_MANIFEST="$Q15_MANIFEST_DIR/kube-scheduler.yaml"
Q15_CONTROLLER_MANIFEST="$Q15_MANIFEST_DIR/kube-controller-manager.yaml"
Q15_BASELINE_DIR="$Q15_REPO_ROOT/.cka-state/q15-baseline"

Q15_BASELINE_READY="$Q15_BASELINE_DIR/READY"
Q15_BASELINE_APISERVER="$Q15_BASELINE_DIR/kube-apiserver.yaml"
Q15_BASELINE_SCHEDULER="$Q15_BASELINE_DIR/kube-scheduler.yaml"
Q15_BASELINE_CONTROLLER="$Q15_BASELINE_DIR/kube-controller-manager.yaml"
Q15_BASELINE_COREFILE="$Q15_BASELINE_DIR/Corefile"
Q15_BASELINE_VARIANT="$Q15_BASELINE_DIR/VARIANT"

# How long to wait for the API server and the rest of the control plane.
Q15_WAIT_SECONDS="${Q15_WAIT_SECONDS:-180}"

q15_api_ready() {
  timeout 5 kubectl get --raw='/readyz' >/dev/null 2>&1
}

q15_wait_api_ready() {
  local seconds="${1:-$Q15_WAIT_SECONDS}"
  local elapsed=0
  while (( elapsed < seconds )); do
    q15_api_ready && return 0
    sleep 2
    elapsed=$((elapsed + 2))
  done
  return 1
}

q15_wait_api_down() {
  local seconds="${1:-$Q15_WAIT_SECONDS}"
  local elapsed=0
  while (( elapsed < seconds )); do
    if ! q15_api_ready; then
      return 0
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done
  return 1
}

q15_container_running() {
  local component="$1"
  sudo crictl ps --name "^${component}$" --state Running -q 2>/dev/null | grep -q .
}

q15_control_plane_running() {
  local comp
  for comp in etcd kube-apiserver kube-scheduler kube-controller-manager; do
    q15_container_running "$comp" || return 1
  done
  return 0
}

q15_component_status() {
  local component="$1"
  kubectl -n kube-system get pods --no-headers 2>/dev/null |
    awk -v c="$component" '$1 ~ ("^" c "-") { print $3; exit }'
}

q15_wait_component_not_running() {
  local component="$1"
  local seconds="${2:-$Q15_WAIT_SECONDS}"
  local elapsed=0
  while (( elapsed < seconds )); do
    if ! q15_container_running "$component"; then
      return 0
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done
  return 1
}

# Kubelet updates the static Pod mirror object with a short delay. After the
# container has stopped, wait (best effort) for kubectl to show the same state
# so the diagnostics printed by setup do not contradict the question.
q15_wait_component_status_not_running() {
  local component="$1"
  local seconds="${2:-60}"
  local elapsed=0 phase
  while (( elapsed < seconds )); do
    phase="$(q15_component_status "$component")"
    if [[ -n "$phase" && "$phase" != "Running" ]]; then
      return 0
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done
  return 1
}

q15_wait_dns_broken() {
  local seconds="${1:-$Q15_WAIT_SECONDS}"
  local elapsed=0
  while (( elapsed < seconds )); do
    if ! q15_dns_resolves; then
      return 0
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done
  return 1
}

q15_coredns_ready() {
  local desired available
  desired="$(kubectl -n kube-system get deployment coredns -o jsonpath='{.spec.replicas}' 2>/dev/null)" || return 1
  available="$(kubectl -n kube-system get deployment coredns -o jsonpath='{.status.availableReplicas}' 2>/dev/null)" || return 1
  [[ -n "$desired" && -n "$available" ]] || return 1
  (( available >= 1 && available == desired ))
}

q15_nodes_ready() {
  kubectl get nodes --no-headers 2>/dev/null | awk '$2 !~ /^Ready/ { bad=1 } END { exit bad }'
}

q15_dns_resolves() {
  local svc_ip output
  svc_ip="$(kubectl -n kube-system get service kube-dns -o jsonpath='{.spec.clusterIP}' 2>/dev/null)" || return 1
  [[ -n "$svc_ip" ]] || return 1

  if command -v dig >/dev/null 2>&1; then
    output="$(dig @"$svc_ip" kubernetes.default.svc.cluster.local +short +time=2 +tries=1 2>/dev/null || true)"
  elif command -v nslookup >/dev/null 2>&1; then
    output="$(nslookup kubernetes.default.svc.cluster.local "$svc_ip" 2>/dev/null || true)"
  else
    # Last-resort check: a short-lived in-cluster lookup. This needs image
    # pull access, so it is only used when the host has no DNS client.
    kubectl -n default delete pod q15-dns-check --ignore-not-found --wait=true >/dev/null 2>&1 || true
    kubectl -n default run q15-dns-check --image=busybox:1.36 --restart=Never \
      --command -- nslookup kubernetes.default.svc.cluster.local >/dev/null 2>&1 || return 1
    if ! timeout 90 kubectl -n default wait --for=condition=Ready pod/q15-dns-check --timeout=80s >/dev/null 2>&1; then
      kubectl -n default delete pod q15-dns-check --ignore-not-found --wait=false >/dev/null 2>&1 || true
      return 1
    fi
    output="$(kubectl -n default logs q15-dns-check 2>/dev/null || true)"
    kubectl -n default delete pod q15-dns-check --ignore-not-found --wait=false >/dev/null 2>&1 || true
  fi

  [[ -n "$output" ]]
}

q15_cluster_healthy() {
  q15_api_ready &&
    q15_control_plane_running &&
    q15_coredns_ready &&
    q15_nodes_ready &&
    q15_dns_resolves
}

q15_pod_cpu_request() {
  local file="$1"
  sudo awk '
    /^    resources:[[:space:]]*$/ { resources=1; next }
    resources && /^      requests:[[:space:]]*$/ { requests=1; next }
    resources && /^      limits:[[:space:]]*$/ { requests=0; next }
    requests && /^        cpu:[[:space:]]*/ {
      sub(/^        cpu:[[:space:]]*/, "")
      print
      exit
    }
  ' "$file"
}

q15_pod_memory_limit() {
  local file="$1"
  sudo awk '
    /^    resources:[[:space:]]*$/ { resources=1; next }
    resources && /^      limits:[[:space:]]*$/ { limits=1; next }
    resources && /^      requests:[[:space:]]*$/ { limits=0; next }
    limits && /^        memory:[[:space:]]*/ {
      sub(/^        memory:[[:space:]]*/, "")
      print
      exit
    }
  ' "$file"
}

q15_cpu_millicores() {
  local value="${1:-}"
  if [[ -z "$value" ]]; then
    printf '0\n'
    return 0
  fi
  if [[ "$value" =~ ^([0-9]+)m$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi
  if [[ "$value" =~ ^([0-9]+)$ ]]; then
    printf '%s\n' "$(( BASH_REMATCH[1] * 1000 ))"
    return 0
  fi
  if [[ "$value" =~ ^([0-9]+)\.([0-9]+)$ ]]; then
    local whole="${BASH_REMATCH[1]}"
    local fraction="${BASH_REMATCH[2]}"
    fraction="${fraction}000"
    printf '%s\n' "$(( whole * 1000 + 10#${fraction:0:3} ))"
    return 0
  fi
  return 1
}

q15_memory_mib() {
  local value="${1:-}"
  [[ -n "$value" ]] || return 1
  if [[ "$value" =~ ^([0-9]+)Mi$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi
  if [[ "$value" =~ ^([0-9]+)Gi$ ]]; then
    printf '%s\n' "$(( BASH_REMATCH[1] * 1024 ))"
    return 0
  fi
  if [[ "$value" =~ ^([0-9]+)M$ ]]; then
    printf '%s\n' "$(( BASH_REMATCH[1] * 1000000 / 1048576 ))"
    return 0
  fi
  if [[ "$value" =~ ^([0-9]+)G$ ]]; then
    printf '%s\n' "$(( BASH_REMATCH[1] * 1000000000 / 1048576 ))"
    return 0
  fi
  return 1
}

q15_corefile_is_valid() {
  local corefile="$1"
  [[ -s "$corefile" ]] || return 1
  grep -Eq 'kubernetes[[:space:]]+cluster\.local([[:space:]]|$)' "$corefile" || return 1
  ! grep -Fq 'wrong.local' "$corefile" || return 1
  grep -Fq 'forward . /etc/resolv.conf' "$corefile" || return 1
  grep -Fq 'cache 30' "$corefile" || return 1
  local opens closes
  opens="$(grep -o '{' "$corefile" | wc -l)"
  closes="$(grep -o '}' "$corefile" | wc -l)"
  [[ "$opens" -eq "$closes" ]]
}

q15_manifests_look_healthy() {
  grep -Fq -- '--etcd-servers=https://127.0.0.1:2379' "$Q15_APISERVER_MANIFEST" 2>/dev/null || return 1
  if grep -Fq -- '2380' "$Q15_APISERVER_MANIFEST" 2>/dev/null; then
    return 1
  fi
  if grep -Fq -- '192.0.2.100' "$Q15_APISERVER_MANIFEST" 2>/dev/null; then
    return 1
  fi

  local scheduler_cpu controller_cpu controller_mem
  scheduler_cpu="$(q15_pod_cpu_request "$Q15_SCHEDULER_MANIFEST")" || return 1
  if (( $(q15_cpu_millicores "$scheduler_cpu") > 200 )); then
    return 1
  fi

  controller_cpu="$(q15_pod_cpu_request "$Q15_CONTROLLER_MANIFEST")" || return 1
  if (( $(q15_cpu_millicores "$controller_cpu") > 500 )); then
    return 1
  fi

  controller_mem="$(q15_pod_memory_limit "$Q15_CONTROLLER_MANIFEST")" || true
  if [[ -n "$controller_mem" ]]; then
    local mem_mib
    mem_mib="$(q15_memory_mib "$controller_mem")" || return 1
    if (( mem_mib < 128 )); then
      return 1
    fi
  fi

  local corefile_tmp
  corefile_tmp="$(mktemp)"
  if ! kubectl -n kube-system get configmap coredns -o jsonpath='{.data.Corefile}' > "$corefile_tmp" 2>/dev/null; then
    rm -f "$corefile_tmp"
    return 1
  fi
  q15_corefile_is_valid "$corefile_tmp"
  local rc=$?
  rm -f "$corefile_tmp"
  return "$rc"
}

q15_snapshot_baseline() {
  rm -rf "$Q15_BASELINE_DIR"
  mkdir -p "$Q15_BASELINE_DIR"

  sudo cp "$Q15_APISERVER_MANIFEST" "$Q15_BASELINE_APISERVER" || return 1
  sudo cp "$Q15_SCHEDULER_MANIFEST" "$Q15_BASELINE_SCHEDULER" || return 1
  sudo cp "$Q15_CONTROLLER_MANIFEST" "$Q15_BASELINE_CONTROLLER" || return 1

  if ! kubectl -n kube-system get configmap coredns -o jsonpath='{.data.Corefile}' > "$Q15_BASELINE_COREFILE.tmp" 2>/dev/null; then
    rm -f "$Q15_BASELINE_COREFILE.tmp"
    return 1
  fi
  mv "$Q15_BASELINE_COREFILE.tmp" "$Q15_BASELINE_COREFILE"
  [[ -s "$Q15_BASELINE_COREFILE" ]] || return 1

  date -u '+%Y-%m-%dT%H:%M:%SZ' > "$Q15_BASELINE_READY"
}

# Record the selected variant in the baseline directory. Validation requires
# this marker to match .cka-state/<question>.variant, so a hand-written state
# file or a state file changed to another valid preset fails closed.
q15_record_variant() {
  local variant="${1:-}"
  [[ "$variant" =~ ^[0-9]+$ ]] || return 1
  mkdir -p "$Q15_BASELINE_DIR" || return 1
  printf '%s\n' "$variant" > "$Q15_BASELINE_VARIANT" || return 1
  [[ "$(<"$Q15_BASELINE_VARIANT")" == "$variant" ]]
}

q15_baseline_variant() {
  local value
  [[ -s "$Q15_BASELINE_READY" ]] || return 1
  [[ -s "$Q15_BASELINE_VARIANT" ]] || return 1
  value="$(<"$Q15_BASELINE_VARIANT")"
  [[ "$value" =~ ^[0-9]+$ ]] || return 1
  printf '%s\n' "$value"
}

# Atomically install a file into the kubelet-watched manifest directory.
# Writing a static Pod manifest in place lets kubelet observe a truncated or
# empty file, which produces a parse error and a long CrashLoopBackOff, so
# always copy to a hidden sibling temp file and rename it over the target.
# Kubelet ignores dot-prefixed files in the manifest directory.
q15_atomic_install() {
  local src="$1"
  local dest="$2"
  local tmp mode owner group
  tmp="$(dirname "$dest")/.q15-tmp-$(basename "$dest").$$"
  if sudo test -e "$dest"; then
    read -r mode owner group < <(sudo stat -c '%a %u %g' "$dest")
  fi
  if ! sudo cp "$src" "$tmp"; then
    sudo rm -f "$tmp"
    return 1
  fi
  if [[ -n "${mode:-}" ]]; then
    sudo chmod "$mode" "$tmp"
    sudo chown "$owner:$group" "$tmp"
  fi
  if ! sudo mv -f "$tmp" "$dest"; then
    sudo rm -f "$tmp"
    return 1
  fi
}

q15_restore_baseline() {
  [[ -s "$Q15_BASELINE_READY" ]] || return 1

  q15_atomic_install "$Q15_BASELINE_APISERVER" "$Q15_APISERVER_MANIFEST" || return 1
  q15_atomic_install "$Q15_BASELINE_SCHEDULER" "$Q15_SCHEDULER_MANIFEST" || return 1
  q15_atomic_install "$Q15_BASELINE_CONTROLLER" "$Q15_CONTROLLER_MANIFEST" || return 1

  echo "Waiting for the API server to restart..."
  if ! q15_wait_api_ready "$Q15_WAIT_SECONDS"; then
    return 1
  fi

  if ! kubectl -n kube-system create configmap coredns \
      --from-file=Corefile="$Q15_BASELINE_COREFILE" \
      --dry-run=client -o yaml 2>/dev/null |
      kubectl apply -f - >/dev/null 2>&1; then
    return 1
  fi

  echo "Waiting for CoreDNS and cluster DNS to recover..."
  kubectl -n kube-system rollout restart deployment/coredns >/dev/null 2>&1 || true
  kubectl -n kube-system rollout status deployment/coredns \
    --timeout="${Q15_WAIT_SECONDS}s" >/dev/null 2>&1 || true
  q15_wait_cluster_healthy "$Q15_WAIT_SECONDS"
}

q15_wait_cluster_healthy() {
  local seconds="${1:-$Q15_WAIT_SECONDS}"
  local elapsed=0
  while (( elapsed < seconds )); do
    if q15_cluster_healthy; then
      return 0
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done
  return 1
}

q15_ensure_baseline() {
  if [[ -s "$Q15_BASELINE_READY" ]]; then
    echo "Restoring the pristine baseline saved by the previous run..."
    q15_restore_baseline
    return
  fi

  if ! q15_cluster_healthy; then
    echo "Error: the cluster is not healthy and no pristine Q15 baseline exists." >&2
    echo "Repair the control plane (or start a fresh disposable cluster) before running Q15." >&2
    return 1
  fi

  if ! q15_manifests_look_healthy; then
    echo "Error: the control-plane manifests do not look like a known-good baseline." >&2
    echo "Refusing to snapshot an already-broken cluster." >&2
    return 1
  fi

  echo "Capturing pristine control-plane baseline in $Q15_BASELINE_DIR"
  q15_snapshot_baseline
}

q15_set_etcd_servers() {
  local value="$1"
  local tmpdir tmp
  tmpdir="$(mktemp -d)"
  tmp="$tmpdir/kube-apiserver.yaml"
  # Edit outside the watched directory, then install atomically. GNU sed -i
  # would create a visible temp file that kubelet tries to parse as a Pod.
  if ! sudo sed -E "s#^([[:space:]]*- --etcd-servers=).*#\1${value}#" \
      "$Q15_APISERVER_MANIFEST" > "$tmp"; then
    rm -rf "$tmpdir"
    return 1
  fi
  if ! grep -Fq -- "--etcd-servers=${value}" "$tmp"; then
    rm -rf "$tmpdir"
    return 1
  fi
  if ! q15_atomic_install "$tmp" "$Q15_APISERVER_MANIFEST"; then
    rm -rf "$tmpdir"
    return 1
  fi
  rm -rf "$tmpdir"
  grep -Fq -- "--etcd-servers=${value}" "$Q15_APISERVER_MANIFEST"
}

q15_set_container_resources() {
  local file="$1"
  local cpu="${2:-}"
  local memory_limit="${3:-}"

  sudo python3 - "$file" "$cpu" "$memory_limit" <<'PY'
import os
import re
import sys
import tempfile

path, cpu, memory_limit = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as handle:
    lines = handle.read().splitlines()

resources_index = None
for i, line in enumerate(lines):
    if re.fullmatch(r'    resources:\s*', line):
        resources_index = i
        break
if resources_index is None:
    raise SystemExit("resources block not found")

end = resources_index + 1
while end < len(lines):
    line = lines[end]
    if line.strip() and (len(line) - len(line.lstrip(' '))) <= 4:
        break
    end += 1

block = lines[resources_index:end]

def indent_of(line):
    return len(line) - len(line.lstrip(' '))

def find_subsection(name):
    pattern = re.compile(r'^ {6}' + re.escape(name) + r':\s*$')
    for idx, line in enumerate(block):
        if pattern.match(line):
            return idx
    return None

def find_key(subsection_index, key):
    pattern = re.compile(r'^ {8}' + re.escape(key) + r':')
    idx = subsection_index + 1
    while idx < len(block):
        line = block[idx]
        if line.strip():
            indentation = indent_of(line)
            if indentation <= 6:
                break
            if indentation == 8 and pattern.match(line):
                return idx
        idx += 1
    return None

if cpu:
    requests_index = find_subsection('requests')
    if requests_index is None:
        block.append('      requests:')
        block.append(f'        cpu: {cpu}')
    else:
        cpu_index = find_key(requests_index, 'cpu')
        if cpu_index is None:
            block.insert(requests_index + 1, f'        cpu: {cpu}')
        else:
            block[cpu_index] = re.sub(
                r'^(\s*cpu:\s*).*$', rf'\g<1>{cpu}', block[cpu_index]
            )

if memory_limit:
    limits_index = find_subsection('limits')
    if limits_index is None:
        block.append('      limits:')
        block.append(f'        memory: {memory_limit}')
    else:
        memory_index = find_key(limits_index, 'memory')
        if memory_index is None:
            block.insert(limits_index + 1, f'        memory: {memory_limit}')
        else:
            block[memory_index] = re.sub(
                r'^(\s*memory:\s*).*$', rf'\g<1>{memory_limit}', block[memory_index]
            )

lines[resources_index:end] = block

# kubelet watches this directory: never truncate the manifest in place.
st = os.stat(path)
fd, tmp = tempfile.mkstemp(
    prefix='.q15-tmp-', dir=os.path.dirname(os.path.abspath(path))
)
try:
    with os.fdopen(fd, 'w') as handle:
        handle.write('\n'.join(lines) + '\n')
        handle.flush()
        os.fsync(handle.fileno())
    os.chmod(tmp, st.st_mode)
    try:
        os.chown(tmp, st.st_uid, st.st_gid)
    except PermissionError:
        pass
    os.replace(tmp, path)
except BaseException:
    try:
        os.unlink(tmp)
    except FileNotFoundError:
        pass
    raise
PY
}

q15_apply_coredns_fault() {
  [[ -s "$Q15_BASELINE_COREFILE" ]] || return 1
  local tmp
  tmp="$(mktemp)"
  # Point the kubernetes plugin at the wrong cluster zone. CoreDNS still runs,
  # but cluster DNS stops resolving. This is the training substitute for the
  # unverified exam ConfigMap fault described in the research notes.
  sed 's/kubernetes cluster\.local/kubernetes wrong.local/' \
    "$Q15_BASELINE_COREFILE" > "$tmp"
  if ! grep -Fq 'kubernetes wrong.local' "$tmp"; then
    rm -f "$tmp"
    return 1
  fi
  if ! kubectl -n kube-system create configmap coredns \
      --from-file=Corefile="$tmp" \
      --dry-run=client -o yaml 2>/dev/null |
      kubectl apply -f - >/dev/null 2>&1; then
    rm -f "$tmp"
    return 1
  fi
  rm -f "$tmp"
  kubectl -n kube-system rollout restart deployment/coredns >/dev/null 2>&1 || true
  kubectl -n kube-system rollout status deployment/coredns \
    --timeout="${Q15_WAIT_SECONDS}s" >/dev/null 2>&1 || true
}

q15_print_status() {
  local comp line mismatch=0 phase
  echo "Control-plane containers (latest container per component):"
  for comp in etcd kube-apiserver kube-scheduler kube-controller-manager; do
    line="$(sudo crictl ps -a --name "^${comp}$" --latest 2>/dev/null | tail -n +2)"
    if [[ -n "$line" ]]; then
      echo "$line"
    else
      echo "(no container found for $comp)"
    fi
  done
  echo
  if q15_api_ready; then
    echo "kube-system Pods:"
    kubectl -n kube-system get pods -o wide 2>/dev/null || true
    for comp in kube-scheduler kube-controller-manager; do
      if ! q15_container_running "$comp"; then
        phase="$(q15_component_status "$comp")"
        if [[ "$phase" == "Running" ]]; then
          mismatch=1
        fi
      fi
    done
    if (( mismatch )); then
      echo
      echo "Note: static Pod mirror status can lag behind the container runtime."
      echo "The crictl list above is authoritative."
    fi
  else
    echo "The API server is unavailable, so kubectl status is not shown."
  fi
}
