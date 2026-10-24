#!/bin/bash
# Variant presets for Question 13 - Network Policy.
#
# variant_config is the single source of truth for every value that changes
# between presets: the deployment names, pod labels, backend service, decoy
# CIDR, and which candidate file holds which policy. The namespaces, images,
# port, and number of candidate files stay fixed so every preset has the same
# task, commands, and difficulty.
#
# The three candidate shapes are always the same:
#   - allow-all: selects every pod and allows all ingress
#   - too-open:  allows the frontend namespace OR a decoy CIDR
#   - correct:   allows the frontend namespace AND frontend-labeled pods,
#                with no ipBlock, on TCP port 80 only
# Only the values and the candidate file positions vary.

VARIANT_COUNT=3

# Fixed values shared by every preset.
NS_FRONTEND="frontend"
NS_BACKEND="backend"
IMAGE_BACKEND="nginx"
IMAGE_FRONTEND="curlimages/curl"
BACKEND_PORT=80
POLICY_PORT=80

variant_config() {
  local variant="${1:-}"

  case "$variant" in
    1)
      FRONTEND_DEPLOYMENT="frontend-deployment"
      BACKEND_DEPLOYMENT="backend-deployment"
      FRONTEND_LABEL_KEY="app"
      FRONTEND_LABEL_VALUE="frontend"
      BACKEND_LABEL_KEY="app"
      BACKEND_LABEL_VALUE="backend"
      BACKEND_SERVICE="backend-service"
      DECOY_CIDR="172.16.0.0/16"
      FILE1_KIND="allow-all"
      FILE1_NAME="policy-x"
      FILE2_KIND="too-open"
      FILE2_NAME="policy-y"
      FILE3_KIND="correct"
      FILE3_NAME="policy-z"
      CORRECT_FILE="network-policy-3.yaml"
      CORRECT_POLICY="policy-z"
      ;;
    2)
      FRONTEND_DEPLOYMENT="client-deployment"
      BACKEND_DEPLOYMENT="server-deployment"
      FRONTEND_LABEL_KEY="role"
      FRONTEND_LABEL_VALUE="client"
      BACKEND_LABEL_KEY="role"
      BACKEND_LABEL_VALUE="server"
      BACKEND_SERVICE="server-service"
      DECOY_CIDR="10.10.0.0/16"
      FILE1_KIND="too-open"
      FILE1_NAME="policy-y"
      FILE2_KIND="correct"
      FILE2_NAME="policy-x"
      FILE3_KIND="allow-all"
      FILE3_NAME="policy-z"
      CORRECT_FILE="network-policy-2.yaml"
      CORRECT_POLICY="policy-x"
      ;;
    3)
      FRONTEND_DEPLOYMENT="web-deployment"
      BACKEND_DEPLOYMENT="api-deployment"
      FRONTEND_LABEL_KEY="tier"
      FRONTEND_LABEL_VALUE="web"
      BACKEND_LABEL_KEY="tier"
      BACKEND_LABEL_VALUE="api"
      BACKEND_SERVICE="api-service"
      DECOY_CIDR="203.0.113.0/24"
      FILE1_KIND="correct"
      FILE1_NAME="policy-y"
      FILE2_KIND="allow-all"
      FILE2_NAME="policy-z"
      FILE3_KIND="too-open"
      FILE3_NAME="policy-x"
      CORRECT_FILE="network-policy-1.yaml"
      CORRECT_POLICY="policy-y"
      ;;
    *)
      echo "Error: unknown variant '$variant' (expected 1..$VARIANT_COUNT)" >&2
      return 1
      ;;
  esac

  VARIANT_SUMMARY="frontend=$FRONTEND_DEPLOYMENT ($FRONTEND_LABEL_KEY=$FRONTEND_LABEL_VALUE) in $NS_FRONTEND, backend=$BACKEND_DEPLOYMENT ($BACKEND_LABEL_KEY=$BACKEND_LABEL_VALUE) + service $BACKEND_SERVICE:$BACKEND_PORT in $NS_BACKEND"
}

# Print the full question for the currently configured variant. LabSetUp.bash
# calls this after variant_config so the learner sees the exact values for the
# run instead of a generic question with hard-coded names.
variant_question() {
  local variant="${1:-?}"

  cat <<EOF
============================================================
 Question 13: Network Policy (Variant $variant/$VARIANT_COUNT)
============================================================

There are two Deployments in this cluster:
- Frontend: $FRONTEND_DEPLOYMENT in namespace $NS_FRONTEND
  (pods labeled $FRONTEND_LABEL_KEY=$FRONTEND_LABEL_VALUE)
- Backend: $BACKEND_DEPLOYMENT in namespace $NS_BACKEND
  (pods labeled $BACKEND_LABEL_KEY=$BACKEND_LABEL_VALUE), exposed by
  Service $BACKEND_SERVICE on TCP port $BACKEND_PORT

Task:
Look at the Network Policy YAML files in ./network-policies. Decide which
of the policies provides the functionality to allow interaction between the
frontend and the backend deployments in the least permissive way and deploy
that YAML.

Notes:
- Exactly one candidate is the least permissive correct answer.
- Apply only the chosen policy; do not apply all three.
- The backend listens on TCP port $BACKEND_PORT.

Manual check:
kubectl exec -n $NS_FRONTEND deployment/$FRONTEND_DEPLOYMENT -- curl -v --connect-timeout 5 $BACKEND_SERVICE.$NS_BACKEND.svc.cluster.local:$BACKEND_PORT

Video Link - https://youtu.be/rA8mXYTU0W8
============================================================
EOF
}
