#!/bin/bash
# Variant presets for Question 12 - Ingress.
#
# variant_config is the single source of truth for every value that changes
# between presets: the existing Deployment, Service, service port, Ingress,
# hostname, and path. The namespace, image, replica count, container port,
# service type, and path type stay fixed so every preset has the same task,
# commands, and difficulty.

VARIANT_COUNT=3

# Fixed values shared by every preset.
NS="echo-sound"
IMAGE="gcr.io/google_containers/echoserver:1.10"
REPLICAS=1
CONTAINER_PORT=8080
TARGET_PORT=8080
SERVICE_TYPE="NodePort"
PATH_TYPE="Prefix"
APP_LABEL="echo"

variant_config() {
  local variant="${1:-}"

  case "$variant" in
    1)
      DEPLOYMENT="echo"
      SERVICE="echo-service"
      SERVICE_PORT=8080
      INGRESS="echo"
      HOST="example.org"
      PATH_VALUE="/echo"
      ;;
    2)
      DEPLOYMENT="echo-api"
      SERVICE="echo-api-service"
      SERVICE_PORT=8081
      INGRESS="echo-api"
      HOST="api.example.net"
      PATH_VALUE="/api"
      ;;
    3)
      DEPLOYMENT="echo-web"
      SERVICE="echo-web-service"
      SERVICE_PORT=8082
      INGRESS="echo-web"
      HOST="web.example.com"
      PATH_VALUE="/web"
      ;;
    *)
      echo "Error: unknown variant '$variant' (expected 1..$VARIANT_COUNT)" >&2
      return 1
      ;;
  esac

  VARIANT_SUMMARY="namespace=$NS, deployment=$DEPLOYMENT, service=$SERVICE:$SERVICE_PORT->$TARGET_PORT ($SERVICE_TYPE), ingress=$INGRESS, url=http://$HOST$PATH_VALUE"
}

# Print the full question for the currently configured variant. LabSetUp.bash
# calls this after variant_config so the learner sees the exact values for the
# run instead of a generic question with hard-coded names.
variant_question() {
  local variant="${1:-?}"

  cat <<EOF
============================================================
 Question 12: Ingress (Variant $variant/$VARIANT_COUNT)
============================================================

The Deployment $DEPLOYMENT already exists in the $NS namespace. The
container listens on port $CONTAINER_PORT.

Tasks:
1. Expose the existing Deployment $DEPLOYMENT with a Service named $SERVICE
   in the $NS namespace. Use Service Port $SERVICE_PORT, target container
   port $TARGET_PORT, and type=$SERVICE_TYPE.
2. Create a new Ingress resource named $INGRESS in the $NS namespace for
   http://$HOST$PATH_VALUE.
3. The availability of the Service $SERVICE can be checked using:
   curl NODEIP:NODEPORT$PATH_VALUE

Exam tip: the check may look like:
curl -o /dev/null -s -w "%{http_code}\n" http://$HOST$PATH_VALUE
This requires an ingress controller. To test it, ensure your /etc/hosts file
has an entry mapping $HOST to your node IP.

Run details:
- Namespace: $NS
- Deployment: $DEPLOYMENT
- Service: $SERVICE (port $SERVICE_PORT -> target port $TARGET_PORT, $SERVICE_TYPE)
- Ingress: $INGRESS
- Host: $HOST
- Path: $PATH_VALUE

Video Link - https://youtu.be/sy9zABvDedQ
============================================================
EOF
}
