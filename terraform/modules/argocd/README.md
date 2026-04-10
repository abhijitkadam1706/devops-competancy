# =============================================================================
# ArgoCD Module — README
# =============================================================================

# ArgoCD Terraform Module

## Overview
This module installs **ArgoCD** onto an existing EKS cluster using the official
Helm chart, and creates two `Application` resources:

| App | Namespace | Auto-sync | Trigger |
|-----|-----------|-----------|---------|
| `<cluster>-staging` | `mern-auth-staging` | ✅ ON | Jenkins git commit |
| `<cluster>-production` | `mern-auth-production` | ❌ OFF | PR merge → manual sync |

## What Terraform Manages
- ArgoCD Helm release (pinned chart version)
- `mern-auth-staging` and `mern-auth-production` Kubernetes namespaces
- ArgoCD `Application` manifests (via `kubectl_manifest`)
- ArgoCD admin password stored in **AWS SSM** (no manual `kubectl get secret`)

## Providers Required (configured in ROOT, not this module)
```
helm       ~> 2.13
kubernetes ~> 2.30
kubectl    ~> 1.14   (gavinbunney/kubectl)
aws        ~> 5.50
```

## Inputs
| Variable | Description | Default |
|----------|-------------|---------|
| `cluster_name` | EKS cluster name | required |
| `environment` | production / staging | required |
| `argocd_chart_version` | Pinned argo-cd chart version | `7.3.3` |
| `gitops_repo_url` | HTTPS GitOps repo URL | required |
| `gitops_branch` | Branch ArgoCD tracks | `main` |
| `staging_namespace` | Staging namespace | `mern-auth-staging` |
| `production_namespace` | Production namespace | `mern-auth-production` |

## Outputs
| Output | Description |
|--------|-------------|
| `argocd_admin_password_ssm_path` | SSM path to retrieve admin password |
| `staging_app_name` | ArgoCD Application name for staging |
| `production_app_name` | ArgoCD Application name for production |

## Retrieve ArgoCD Admin Password
```bash
aws ssm get-parameter \
  --name /mern-auth-prod/argocd/admin-password \
  --with-decryption \
  --query Parameter.Value \
  --output text
```

## Promoting to Production
1. Update `gitops/production/kustomization.yaml` — bump `newTag` to match staging tag
2. Open Pull Request → release manager reviews → merge
3. In ArgoCD UI: click **Sync** on the `mern-auth-prod-production` Application
