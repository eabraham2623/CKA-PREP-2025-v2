#!/bin/bash
# Variant presets for Question 11 - Gateway API.
#
# variant_config is the single source of truth for every value that changes
# between presets: the existing Ingress, hostname, TLS secret, backend
# service/port, GatewayClass, Gateway, and HTTPRoute. The namespace, protocol,
# listener port, TLS mode, path, image, and replica count stay fixed so every
# preset has the same task, commands, and difficulty.

VARIANT_COUNT=3

# Fixed values shared by every preset.
NS="default"
PROTOCOL="HTTPS"
LISTENER_PORT=443
TLS_MODE="Terminate"
PATH_VALUE="/"
PATH_TYPE="PathPrefix"
IMAGE="nginx"
REPLICAS=2
CONTAINER_PORT=80
TARGET_PORT=80

variant_config() {
  local variant="${1:-}"

  case "$variant" in
    1)
      INGRESS="web"
      HOST="gateway.web.k8s.local"
      TLS_SECRET="web-tls"
      SERVICE="web-service"
      SERVICE_PORT=80
      DEPLOYMENT="web-deployment"
      APP_LABEL="web"
      GATEWAY_CLASS="nginx-class"
      CLASS_CONTROLLER="example.net/nginx-gateway-controller"
      GATEWAY="web-gateway"
      HTTPROUTE="web-route"
      ;;
    2)
      INGRESS="store"
      HOST="gateway.store.k8s.local"
      TLS_SECRET="store-tls"
      SERVICE="store-service"
      SERVICE_PORT=8080
      DEPLOYMENT="store-deployment"
      APP_LABEL="store"
      GATEWAY_CLASS="envoy-class"
      CLASS_CONTROLLER="example.net/envoy-gateway-controller"
      GATEWAY="store-gateway"
      HTTPROUTE="store-route"
      ;;
    3)
      INGRESS="api"
      HOST="gateway.api.k8s.local"
      TLS_SECRET="api-tls"
      SERVICE="api-service"
      SERVICE_PORT=8000
      DEPLOYMENT="api-deployment"
      APP_LABEL="api"
      GATEWAY_CLASS="haproxy-class"
      CLASS_CONTROLLER="example.net/haproxy-gateway-controller"
      GATEWAY="api-gateway"
      HTTPROUTE="api-route"
      ;;
    *)
      echo "Error: unknown variant '$variant' (expected 1..$VARIANT_COUNT)" >&2
      return 1
      ;;
  esac

  VARIANT_SUMMARY="ingress=$INGRESS, host=$HOST, gatewayClass=$GATEWAY_CLASS, gateway=$GATEWAY, httproute=$HTTPROUTE"
}

# Print the full question for the currently configured variant. LabSetUp.bash
# calls this after variant_config so the learner sees the exact values for the
# run instead of a generic question with hard-coded names.
variant_question() {
  local variant="${1:-?}"

  cat <<EOF
============================================================
 Question 11: Gateway API (Variant $variant/$VARIANT_COUNT)
============================================================

An existing web application in the $NS namespace is exposed by the Ingress
resource $INGRESS. Migrate the Ingress configuration to the Kubernetes
Gateway API while keeping the same HTTPS access and routing rules.

Tasks:
1. Create a Gateway named $GATEWAY that uses GatewayClass $GATEWAY_CLASS.
   Configure an HTTPS listener on port $LISTENER_PORT for hostname $HOST and
   terminate TLS using the certificate secret referenced by Ingress $INGRESS.
2. Create an HTTPRoute named $HTTPROUTE attached to Gateway $GATEWAY. Use
   hostname $HOST and forward the same path prefix to the same backend
   service and port used by Ingress $INGRESS.

Note: GatewayClass $GATEWAY_CLASS is already installed in the cluster.

Run details:
- Namespace: $NS
- Existing Ingress: $INGRESS
- Hostname: $HOST
- Gateway: $GATEWAY
- HTTPRoute: $HTTPROUTE
- GatewayClass: $GATEWAY_CLASS

Video Link - https://youtu.be/G9zispvOCHE

Documentation Reference
Tip: Navigate the documentation manually to build familiarity with its structure
Concepts -> Services, Load Balancing, and Networking -> Gateway API
https://kubernetes.io/docs/concepts/services-networking/gateway/
============================================================
EOF
}
