# Solution Notes for Question 7 - PriorityClass
#
# LabSetUp.bash prints the namespace, deployment, existing PriorityClass, and
# target PriorityClass for this run. Substitute the printed names for the
# <..._FROM_SETUP> placeholders below, and compute <VALUE_ONE_LESS_THAN_MAX>
# from the highest existing user-defined value.

# Inspect the existing priority classes and find the highest user-defined value
kubectl get priorityclass --sort-by=.value

# Create the new class with a value one less than that highest value
kubectl create priorityclass <TARGET_PC_FROM_SETUP> --value=<VALUE_ONE_LESS_THAN_MAX> --description="high priority"
kubectl get pc

# Patch the deployment to use it
kubectl patch deployment <DEPLOYMENT_FROM_SETUP> -n <NAMESPACE_FROM_SETUP> -p '{"spec":{"template":{"spec":{"priorityClassName":"<TARGET_PC_FROM_SETUP>"}}}}'
kubectl describe deployment <DEPLOYMENT_FROM_SETUP> -n <NAMESPACE_FROM_SETUP> | grep -i "Priority Class"
