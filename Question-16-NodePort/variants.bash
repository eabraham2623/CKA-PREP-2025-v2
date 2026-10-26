#!/bin/bash
# Variant presets for Question 16 - NodePort Service.
#
# variant_config is the single source of truth for every value that changes
# between presets. LabSetUp.bash and validate.bash both call it after reading
# the recorded variant. The image, container port, target port, protocol, and
# replica count stay fixed so every preset has the same task and difficulty.

VARIANT_COUNT=3

# Fixed values shared by every preset. nginx serves on container port 80 and
# the Service always targets that port; only the values below vary.
IMAGE="nginx"
CONTAINER_PORT=80
TARGET_PORT=80
PROTOCOL="TCP"
REPLICAS=2

variant_config() {
  local variant="${1:-}"

  case "$variant" in
    1)
      NS="relative"
      DEPLOY="nodeport-deployment"
      SVC="nodeport-service"
      PORT_NAME="http"
      SERVICE_PORT=80
      NODEPORT=30080
      ;;
    2)
      NS="relative-web"
      DEPLOY="web-deployment"
      SVC="web-nodeport"
      PORT_NAME="web"
      SERVICE_PORT=8080
      NODEPORT=30090
      ;;
    3)
      NS="relative-api"
      DEPLOY="api-deployment"
      SVC="api-nodeport"
      PORT_NAME="http-api"
      SERVICE_PORT=8000
      NODEPORT=30280
      ;;
    *)
      echo "Error: unknown variant '$variant' (expected 1..$VARIANT_COUNT)" >&2
      return 1
      ;;
  esac

  APP_LABEL="$DEPLOY"
  VARIANT_SUMMARY="namespace=$NS, deployment=$DEPLOY, service=$SVC, portName=$PORT_NAME, servicePort=$SERVICE_PORT -> targetPort=$TARGET_PORT, nodePort=$NODEPORT"
}

# Print the full question for the currently configured variant. LabSetUp.bash
# calls this after variant_config so the learner sees the exact values for the
# run instead of a generic question with hard-coded names.
variant_question() {
  local variant="${1:-?}"

  cat <<EOF
============================================================
 Question 16: NodePort Service (Variant $variant/$VARIANT_COUNT)
============================================================

There is a deployment named $DEPLOY in the $NS namespace.

Tasks:
1. Configure the deployment so it can be exposed on container port
   $CONTAINER_PORT (name=$PORT_NAME, protocol=$PROTOCOL).
2. Create a new Service named $SVC of type NodePort with:
   - port: $SERVICE_PORT
   - targetPort: $TARGET_PORT
   - protocol: $PROTOCOL
   - nodePort: $NODEPORT
3. Configure the Service to also expose the individual pods using
   NodePort.

Run details:
- Namespace: $NS
- Deployment: $DEPLOY
- Service: $SVC
- Container port: $CONTAINER_PORT (name $PORT_NAME, protocol $PROTOCOL)
- Service port: $SERVICE_PORT -> targetPort $TARGET_PORT
- NodePort: $NODEPORT

Video Link
============================================================
EOF
}
