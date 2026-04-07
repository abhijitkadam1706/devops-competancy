# =============================================================================
# Staging terraform.tfvars
# Cost-optimized settings: SPOT instances, smaller machine types.
# This file is safe to commit to Git.
# =============================================================================

vpc_cidr             = "10.1.0.0/16"
kubernetes_version   = "1.32"
desired_nodes        = 2
min_nodes            = 1
max_nodes            = 5
instance_types       = ["t3.medium"]
docdb_instance_class = "db.t3.medium"

# If you don't have a domain, leave this empty.
# Staging will be accessible via the auto-generated ALB DNS name.
base_domain = ""

# Optional email alerts
alert_email = ""
