# =============================================================================
# ArgoCD Application — Production
# Auto-sync OFF: Promoted only via PR merge to production branch path.
# An operator must click "Sync" in ArgoCD UI (or use argocd CLI) after merge.
# Rendered by Terraform templatefile()
# =============================================================================

apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${cluster_name}-production
  namespace: ${argocd_namespace}
  labels:
    app.kubernetes.io/managed-by: Terraform
    environment: production
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
    # NO automated block — production requires explicit operator approval
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
      - PruneLast=true

    retry:
      limit: 3
      backoff:
        duration:    10s
        factor:      2
        maxDuration: 5m

  revisionHistoryLimit: 20   # Keep more history for production auditing
