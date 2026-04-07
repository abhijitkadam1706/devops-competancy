# =============================================================================
# Production terraform.tfvars
# Only safe, non-secret values go here.
# This file is safe to commit to Git.
# Secrets (DB passwords, tokens) are NEVER stored here —
# they are auto-generated and stored in AWS Secrets Manager by Terraform.
# =============================================================================

vpc_cidr             = "10.0.0.0/16"
kubernetes_version   = "1.32"
desired_nodes        = 3
min_nodes            = 3
max_nodes            = 10
instance_types       = ["t3.large"]
docdb_instance_class = "db.r6g.large"

# If you don't have a domain name yet, leave this as an empty string "".
# Your app will still be reachable via the free AWS ALB DNS name.
# Once you buy a domain, put it here and re-run: terraform apply
domain_name = ""

# Optional: get email alerts when servers are under stress
# Leave as empty string "" to skip
alert_email = ""
