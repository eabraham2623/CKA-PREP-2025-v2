# Question HPA
# Create a new HorizontalPodAutoscaler (HPA) in the namespace printed by setup.

# Task
# 1. The HPA must target the existing deployment printed by setup in the
#    namespace printed by setup.
# 2. Set the HPA to target the CPU percentage per Pod printed by setup.
# 3. Configure the minimum and maximum replica counts printed by setup.
# 4. Set the downscale stabilization window printed by setup.

# Run details are printed by setup: namespace, deployment, HPA name, CPU target,
# replica bounds, and downscale stabilization window.

# Video Link - https://youtu.be/YGkARVFKtmM

#Documentation Reference
# Tip: Navigate the documentation manually to build familiarity with its structure
# (hpa) Tasks -> Run Application -> HorizontalPodAutoscaling Walkthrough
# https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/
# (downscale) Concepts -> Workloads -> Horizontal Pod Autoscaling
# https://kubernetes.io/docs/concepts/workloads/autoscaling/horizontal-pod-autoscale/
