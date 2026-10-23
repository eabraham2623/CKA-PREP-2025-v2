#!/bin/bash
# Variant presets for Question 1 - MariaDB Persistent Volume.
#
# variant_config is the single source of truth for every value that changes
# between presets. LabSetUp.bash and validate.bash both call it after reading
# the recorded variant.

VARIANT_COUNT=3

variant_config() {
  local variant="${1:-}"

  case "$variant" in
    1)
      NS="mariadb"
      PV="mariadb-pv"
      PVC="mariadb"
      DEPLOY="mariadb"
      SIZE="250Mi"
      HOSTPATH="/mnt/data/mariadb"
      IMAGE="mariadb:10.6"
      ROOT_PASSWORD="rootpass"
      ;;
    2)
      NS="orders-db"
      PV="orders-db-pv"
      PVC="orders-db"
      DEPLOY="orders-db"
      SIZE="500Mi"
      HOSTPATH="/mnt/data/orders-db"
      IMAGE="mariadb:10.6"
      ROOT_PASSWORD="orderspass"
      ;;
    3)
      NS="catalog-db"
      PV="catalog-db-pv"
      PVC="catalog-db"
      DEPLOY="catalog-db"
      SIZE="1Gi"
      HOSTPATH="/mnt/data/catalog-db"
      IMAGE="mariadb:10.6"
      ROOT_PASSWORD="catalogpass"
      ;;
    *)
      echo "Error: unknown variant '$variant' (expected 1..$VARIANT_COUNT)" >&2
      return 1
      ;;
  esac

  VARIANT_SUMMARY="namespace=$NS, PV=$PV, PVC=$PVC, deployment=$DEPLOY, storage=$SIZE"
}

# Print the full question for the currently configured variant. LabSetUp.bash
# calls this after variant_config so the learner sees the exact values for the
# run instead of a generic question with hard-coded names.
variant_question() {
  local variant="${1:-?}"

  cat <<EOF
============================================================
 Question 1: MariaDB Persistent Volume (Variant $variant/$VARIANT_COUNT)
============================================================

A user accidentally deleted the MariaDB Deployment in the $NS namespace.
The deployment was configured with persistent storage. Re-establish the
deployment while preserving the existing PersistentVolume.

Task:
1. Create a PersistentVolumeClaim named $PVC in namespace $NS with:
   - Access mode: ReadWriteOnce
   - Storage request: $SIZE
2. Edit ~/mariadb-deploy.yaml so the MariaDB deployment uses PVC $PVC.
3. Apply the updated deployment.
4. Ensure the deployment $DEPLOY is running and stable.

The retained PersistentVolume for this run is named $PV.

Video Link - https://youtu.be/aXvvc1EB1zg
============================================================
EOF
}
