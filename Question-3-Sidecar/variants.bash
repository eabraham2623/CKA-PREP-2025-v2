#!/bin/bash
# Variant presets for Question 3 - Sidecar Container.
#
# variant_config is the single source of truth for every value that changes
# between presets. LabSetUp.bash, validate.bash, and cleanup.bash all call it
# after reading or selecting the variant.

VARIANT_COUNT=3

# Fixed values: keep the task, images, object count, and mount path identical
# across presets so every variant has the same difficulty.
SIDECAR_NAME="sidecar"
SIDECAR_IMAGE="busybox:stable"
MAIN_IMAGE="wordpress:php8.2-apache"
MOUNT_PATH="/var/log"
SERVICE_PORT=80
TARGET_PORT=80

variant_config() {
  local variant="${1:-}"

  case "$variant" in
    1)
      NS="default"
      DEPLOY="wordpress"
      SERVICE="wordpress"
      APP_CONTAINER="wordpress"
      LOG_FILE="/var/log/wordpress.log"
      LOG_MESSAGE="WordPress is running..."
      ;;
    2)
      NS="blog"
      DEPLOY="blog"
      SERVICE="blog"
      APP_CONTAINER="blog"
      LOG_FILE="/var/log/blog.log"
      LOG_MESSAGE="Blog is running..."
      ;;
    3)
      NS="shop"
      DEPLOY="shop"
      SERVICE="shop"
      APP_CONTAINER="shop"
      LOG_FILE="/var/log/shop.log"
      LOG_MESSAGE="Shop is running..."
      ;;
    *)
      echo "Error: unknown variant '$variant' (expected 1..$VARIANT_COUNT)" >&2
      return 1
      ;;
  esac

  APP_LABEL="$DEPLOY"
  VARIANT_SUMMARY="namespace=$NS, deployment=$DEPLOY, main container=$APP_CONTAINER, log=$LOG_FILE, mount=$MOUNT_PATH"
}

# Print the full question for the currently configured variant. LabSetUp.bash
# calls this after variant_config so the learner sees the exact values for the
# run instead of a generic question with hard-coded names.
variant_question() {
  local variant="${1:-?}"

  cat <<EOF
============================================================
 Question 3: Sidecar Container (Variant $variant/$VARIANT_COUNT)
============================================================

The deployment $DEPLOY in namespace $NS runs a main container named
$APP_CONTAINER. The main container continuously writes to $LOG_FILE.

Task:
Update the existing $DEPLOY deployment by adding a co-located sidecar
container named $SIDECAR_NAME using the $SIDECAR_IMAGE image.

Add a shared emptyDir volume mounted at $MOUNT_PATH in both the main and
sidecar containers so the sidecar can read the main container's log file.

The new sidecar container has to run the following command (as given by the
exam task):
  /bin/sh -c tail -f $LOG_FILE

Note: In your solution use \`tail -F\` (capital F) - it follows log files
across rotation and re-creation, whereas \`-f\` (lowercase) can miss logs
after rotation.

Video link - https://youtu.be/3xraEGGQJDY
============================================================
EOF
}
