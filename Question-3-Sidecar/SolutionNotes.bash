# Solution notes for Question 3 - Sidecar Container
#
# LabSetUp.bash prints the namespace, deployment, main container, log file,
# mount path, and sidecar values for this run. Substitute those values below.
#
# Sidecar notes:
# 1) Exam-preferred solution: co-located container pattern (n + 1 containers).
#    - Add a regular container alongside the main app container in the same pod.
#    - This is the approach the CKA exam expects for Deployments.
#    - Use `tail -F` (capital F) instead of `tail -f` (lowercase):
#      - `-F` follows log files across rotation and re-creation.
#      - `-f` can miss logs after rotation.
# 2) To verify the shared log volume is mounted:
#    - write or confirm the main container's log line in <LOG_FILE>
#    - then check the same file from the sidecar with `kubectl exec`
#    - if both containers can see the same line, the volume is mounted and shared

# ─────────────────────────────────────────────────────────────────────────────
# EXAM-PREFERRED SOLUTION: Co-located sidecar container (n + 1 pattern)
# ─────────────────────────────────────────────────────────────────────────────
# The exam expects a regular co-located container (not an initContainer) added
# to the Deployment. Use kubectl edit or apply a full manifest with -f.

# Option A – kubectl edit (imperative, fastest in exam conditions):
kubectl edit deployment <DEPLOY> -n <NAMESPACE>
# The existing main container already runs the log-writing command in this lab,
# so you only need to add three things:
#   1. A shared volume under spec.template.spec
#   2. A volumeMount for the existing main container
#   3. The new co-located sidecar container
#
#   spec:
#     template:
#       spec:
#         volumes:
#         - name: logs
#           emptyDir: {}
#         containers:
#         - name: <APP_CONTAINER>   # existing container – add volumeMounts here
#           ...
#           volumeMounts:
#           - name: logs
#             mountPath: <MOUNT_PATH>
#         - name: sidecar           # new co-located container
#           image: busybox:stable
#           command: ['sh', '-c', 'tail -F <LOG_FILE>']
#           volumeMounts:
#           - name: logs
#             mountPath: <MOUNT_PATH>

# Option B – apply a full manifest with kubectl apply -f (declarative):
# Keep the existing main container command exactly as it is; only add the
# volume and volumeMount. Inspect it first if you are recreating the Deployment:
kubectl get deployment <DEPLOY> -n <NAMESPACE> \
  -o jsonpath='{.spec.template.spec.containers[?(@.name=="<APP_CONTAINER>")].command}'

cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: <DEPLOY>
  namespace: <NAMESPACE>
  labels:
    app: <APP_LABEL>
spec:
  replicas: 1
  selector:
    matchLabels:
      app: <APP_LABEL>
  template:
    metadata:
      labels:
        app: <APP_LABEL>
    spec:
      volumes:
      - name: logs
        emptyDir: {}
      containers:
      - name: <APP_CONTAINER>
        image: wordpress:php8.2-apache
        ports:
        - containerPort: 80
        command:
        - /bin/sh
        - -c
        - while true; do echo '<LOG_MESSAGE>' >> <LOG_FILE>; sleep 5; done
        volumeMounts:
        - name: logs
          mountPath: <MOUNT_PATH>
      - name: sidecar
        image: busybox:stable
        command: ['sh', '-c', 'tail -F <LOG_FILE>']
        volumeMounts:
        - name: logs
          mountPath: <MOUNT_PATH>
EOF

kubectl rollout status deployment <DEPLOY> -n <NAMESPACE>
kubectl get pods -n <NAMESPACE> -l app=<APP_LABEL>

# Manual verification commands:
# 1) Confirm the Pod and containers are running
kubectl get pods -n <NAMESPACE> -l app=<APP_LABEL> -o wide
kubectl describe pod -n <NAMESPACE> -l app=<APP_LABEL>

# 2) Confirm the shared log file contains the main container's output
POD=$(kubectl get pods -n <NAMESPACE> -l app=<APP_LABEL> -o jsonpath='{.items[0].metadata.name}')
kubectl exec "$POD" -n <NAMESPACE> -c <APP_CONTAINER> -- sh -c 'tail <LOG_FILE>'

# 3) Confirm the sidecar can see the same file
kubectl exec "$POD" -n <NAMESPACE> -c sidecar -- sh -c 'tail <LOG_FILE>'

# 4) Optional: verify the mounted path inside both containers
kubectl exec "$POD" -n <NAMESPACE> -c <APP_CONTAINER> -- sh -c 'mount | grep <MOUNT_PATH>'
kubectl exec "$POD" -n <NAMESPACE> -c sidecar -- sh -c 'mount | grep <MOUNT_PATH>'

# ─────────────────────────────────────────────────────────────────────────────
# FOR REFERENCE / LEARNING ONLY: InitContainer sidecar pattern
# ─────────────────────────────────────────────────────────────────────────────
# Kubernetes 1.29+ introduced native sidecar support via initContainers with
# restartPolicy: Always. This is useful for Jobs (where regular containers
# would keep the Job alive), but the CKA exam for Deployment tasks expects the
# co-located container approach above. This section is provided for learning.
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: <DEPLOY>
  namespace: <NAMESPACE>
  labels:
    app: <APP_LABEL>
spec:
  replicas: 1
  selector:
    matchLabels:
      app: <APP_LABEL>
  template:
    metadata:
      labels:
        app: <APP_LABEL>
    spec:
      volumes:
      - name: logs
        emptyDir: {}
      containers:
      - name: <APP_CONTAINER>
        image: wordpress:php8.2-apache
        ports:
        - containerPort: 80
        command:
        - /bin/sh
        - -c
        - while true; do echo '<LOG_MESSAGE>' >> <LOG_FILE>; sleep 5; done
        volumeMounts:
        - name: logs
          mountPath: <MOUNT_PATH>
      initContainers:
      - name: sidecar
        image: busybox:stable
        restartPolicy: Always
        command: ['sh', '-c', 'tail -F <LOG_FILE>']
        volumeMounts:
        - name: logs
          mountPath: <MOUNT_PATH>
EOF
