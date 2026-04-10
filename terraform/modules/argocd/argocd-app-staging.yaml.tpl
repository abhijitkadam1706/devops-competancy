# =============================================================================
# ArgoCD Application — Staging
# Auto-sync ON: Jenkins pushes → ArgoCD deploys automatically within 3 min
# Rendered by Terraform templatefile()
# =============================================================================

apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${cluster_name}-staging
  namespace: ${argocd_namespace}
  labels:
    app.kubernetes.io/managed-by: Terraform
    environment: staging
  # Finalizer ensures Application resources are cleaned up on deletion
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default

  source:
    repoURL:        ${gitops_repo_url}
    targetRevision: ${gitops_branch}
    path:           ${gitops_path}

  destination:
    server:    https://kubernetes.default.svc
    namespace: ${dest_namespace}

  syncPolicy:
    automated:
      # Remove resources from cluster that are deleted from Git
      prune:     true
      # Revert any manual changes made to the cluster
      selfHeal:  true
      # Allow sync even when cluster resources are out of date
      allowEmpty: false

    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
      - PruneLast=true

    retry:
      limit: 5
      backoff:
        duration:    5s
        factor:      2
        maxDuration: 3m

  # Health checks — don't mark healthy until pods are truly ready
  revisionHistoryLimit: 10
