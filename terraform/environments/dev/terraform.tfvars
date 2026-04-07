# =============================================================================
# Dev terraform.tfvars
# Absolute minimum footprint — 1 SPOT node, tiny DocumentDB.
# No ALB, no monitoring, no WAF — use kubectl port-forward to access locally.
# This file is safe to commit to Git.
# =============================================================================

vpc_cidr           = "10.2.0.0/16"
kubernetes_version = "1.32"
