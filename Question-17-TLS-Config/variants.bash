#!/bin/bash
# Variant presets for Question 17 - NGINX TLS Config.
#
# variant_config is the single source of truth for every value that changes
# between presets: the initial and required ssl_protocols values and whether
# the ConfigMap is immutable. Resource names, the image, the hostname, and the
# verification commands stay fixed so the TLS work is the only variable.

VARIANT_COUNT=3

# Fixed values shared by every preset.
NS="nginx-static"
DEPLOYMENT="nginx-static"
SERVICE="nginx-static"
CONFIGMAP="nginx-config"
SECRET="nginx-tls"
APP_LABEL="nginx-static"
TLS_HOSTNAME="ckaquestion.k8s.local"
IMAGE="nginx:latest"
TLS_MOUNT="/etc/nginx/tls"

variant_config() {
  local variant="${1:-}"

  case "$variant" in
    1)
      # Original Q17 task: restrict NGINX to TLS 1.3 only.
      INITIAL_PROTOCOLS="TLSv1.2 TLSv1.3"
      REQUIRED_PROTOCOLS="TLSv1.3"
      INITIAL_IMMUTABLE=false
      REQUIRED_IMMUTABLE=false
      TLS12_EXPECTED="fail"
      INITIAL_DESCRIPTION="supports TLSv1.2 and TLSv1.3"
      TASK_ONE="Configure the ConfigMap to only support TLSv1.3"
      TASK_ONE_SUFFIX=""
      TASK_THREE_NOTE=""
      ;;
    2)
      # Reported exam variation: enable TLS 1.2 while retaining TLS 1.3.
      INITIAL_PROTOCOLS="TLSv1.3"
      REQUIRED_PROTOCOLS="TLSv1.2 TLSv1.3"
      INITIAL_IMMUTABLE=false
      REQUIRED_IMMUTABLE=false
      TLS12_EXPECTED="work"
      INITIAL_DESCRIPTION="only supports TLSv1.3"
      TASK_ONE="Configure the ConfigMap to support TLSv1.2 and TLSv1.3"
      TASK_ONE_SUFFIX=""
      TASK_THREE_NOTE=""
      ;;
    3)
      # Reported exam variation: TLS 1.3 only while the ConfigMap is immutable.
      # Kubernetes cannot revert immutability or edit the data, so the ConfigMap
      # must be deleted and recreated.
      INITIAL_PROTOCOLS="TLSv1.2 TLSv1.3"
      REQUIRED_PROTOCOLS="TLSv1.3"
      INITIAL_IMMUTABLE=true
      REQUIRED_IMMUTABLE=true
      TLS12_EXPECTED="fail"
      INITIAL_DESCRIPTION="supports TLSv1.2 and TLSv1.3"
      TASK_ONE="Configure the ConfigMap to only support TLSv1.3"
      TASK_ONE_SUFFIX=$'\n   The ConfigMap is immutable, so recreate it with immutable: true if necessary.'
      TASK_THREE_NOTE=$'   Note: because the ConfigMap is immutable, make sure the old pod has\n   terminated before the new pod starts (scale to 0, wait, then scale to 1).\n'
      ;;
    *)
      echo "Error: unknown variant '$variant' (expected 1..$VARIANT_COUNT)" >&2
      return 1
      ;;
  esac

  VARIANT_SUMMARY="namespace=$NS, configmap=$CONFIGMAP, initial protocols=$INITIAL_PROTOCOLS, required protocols=$REQUIRED_PROTOCOLS, immutable=$REQUIRED_IMMUTABLE"
}

# Print the full question for the currently configured variant. LabSetUp.bash
# calls this after variant_config so the learner sees the exact task for the
# run instead of a generic question with hard-coded values.
variant_question() {
  local variant="${1:-?}"

  cat <<EOF
============================================================
 Question 17: NGINX TLS Config (Variant $variant/$VARIANT_COUNT)
============================================================

There is an existing deployment in the $NS namespace. The deployment contains
a ConfigMap named $CONFIGMAP that $INITIAL_DESCRIPTION, as well as a Secret for TLS.

There is a service called $SERVICE in the $NS namespace that is currently
exposing the deployment.

Task:
1. $TASK_ONE$TASK_ONE_SUFFIX
2. Add the IP address of the service in /etc/hosts and name it $TLS_HOSTNAME
3. Restart the deployment and verify everything is working using the following commands
$TASK_THREE_NOTE    curl -vk --tls-max 1.2 https://$TLS_HOSTNAME # should $TLS12_EXPECTED
    curl -vk --tlsv1.3 https://$TLS_HOSTNAME # should work
EOF
}
