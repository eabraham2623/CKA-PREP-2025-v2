#!/bin/bash
# Variant presets for Question 9 - cri-dockerd.
#
# The package and service task stay fixed. Variant 1 preserves the original
# Kubernetes networking sysctls; variants 2 and 3 use conservative host queue
# and conntrack settings instead. Variants 2 and 3 only raise limits and never
# disable forwarding, so they do not remove cluster networking prerequisites.

VARIANT_COUNT=3

CRI_DOCKER_VERSION="0.3.20.3"
CRI_DOCKER_DEB="/root/cri-dockerd.deb"
CRI_DOCKER_URL="https://github.com/Mirantis/cri-dockerd/releases/download/v0.3.20/cri-dockerd_0.3.20.3-0.debian-bullseye_amd64.deb"
CRI_DOCKER_SERVICE="cri-docker.service"
SYSCTL_FILE="/etc/sysctl.d/kube.conf"

variant_config() {
  local variant="${1:-}"

  case "$variant" in
    1)
      SYSCTL_KEYS=(
        "net.bridge.bridge-nf-call-iptables"
        "net.ipv6.conf.all.forwarding"
        "net.ipv4.ip_forward"
        "net.netfilter.nf_conntrack_max"
      )
      SYSCTL_VALUES=(1 1 1 131072)
      ;;
    2)
      SYSCTL_KEYS=(
        "net.core.somaxconn"
        "net.ipv4.tcp_max_syn_backlog"
        "net.core.netdev_max_backlog"
        "net.netfilter.nf_conntrack_max"
      )
      SYSCTL_VALUES=(6144 6144 1500 196608)
      ;;
    3)
      SYSCTL_KEYS=(
        "net.core.somaxconn"
        "net.ipv4.tcp_max_syn_backlog"
        "net.core.netdev_max_backlog"
        "net.netfilter.nf_conntrack_max"
      )
      SYSCTL_VALUES=(8192 8192 2000 262144)
      ;;
    *)
      echo "Error: unknown variant '$variant' (expected 1..$VARIANT_COUNT)" >&2
      return 1
      ;;
  esac

  local i
  local settings=()
  for i in "${!SYSCTL_KEYS[@]}"; do
    settings+=("${SYSCTL_KEYS[$i]}=${SYSCTL_VALUES[$i]}")
  done
  VARIANT_SUMMARY="cri-dockerd=$CRI_DOCKER_VERSION, service=$CRI_DOCKER_SERVICE, sysctls: ${settings[*]}"
}

variant_question() {
  local variant="${1:-?}"
  local i

  cat <<EOF
============================================================
 Question 9: cri-dockerd (Variant $variant/$VARIANT_COUNT)
============================================================

Set up cri-dockerd on this node.

Tasks:
1. Install the Debian package at $CRI_DOCKER_DEB using dpkg.
2. Enable and start the $CRI_DOCKER_SERVICE service.
3. Configure the following sysctl parameters persistently in $SYSCTL_FILE,
   then apply the configuration:
EOF

  for i in "${!SYSCTL_KEYS[@]}"; do
    printf '   - %s = %s\n' "${SYSCTL_KEYS[$i]}" "${SYSCTL_VALUES[$i]}"
  done

  cat <<EOF

The package was downloaded from the cri-dockerd $CRI_DOCKER_VERSION release.

Video Link - https://youtu.be/ybzo1vXiqjU
============================================================
EOF
}
