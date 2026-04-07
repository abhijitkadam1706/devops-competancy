# ArgoCD Installation & Setup Guide

## Step 1: Install ArgoCD on your EKS Cluster

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD (latest stable)
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
```

## Step 2: Access ArgoCD UI

```bash
# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port-forward to access the UI
kubectl port-forward svc/argocd-server -n argocd 8443:443

# Open browser: https://localhost:8443
# Username: admin
# Password: (from above command)
```

## Step 3: Register the GitOps Repository

```bash
# Install ArgoCD CLI
# Windows: choco install argocd-cli
# Linux:   curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64

# Login
argocd login localhost:8443 --username admin --password <password> --insecure

# Add the GitOps repo (use a GitHub PAT with repo read access)
argocd repo add https://github.com/Data-Oceano-Infrastructure/mern-auth-gitops.git \
    --username <github-username> \
    --password <github-pat>
```

## Step 4: Deploy ArgoCD Applications

```bash
# Apply the Application CRDs (staging = auto-sync, production = manual)
kubectl apply -f argocd/mern-auth-apps.yaml
```

## Step 5: Create the GitOps Repository on GitHub

```bash
# 1. Create a new repo: Data-Oceano-Infrastructure/mern-auth-gitops
# 2. Push the gitops/ folder contents:
cd gitops
git init
git add -A
git commit -m "initial: GitOps manifests for mern-auth"
git remote add origin https://github.com/Data-Oceano-Infrastructure/mern-auth-gitops.git
git push -u origin main
```

## Step 6: Add Jenkins Credentials

In Jenkins → Manage Jenkins → Credentials → Add:
- **ID**: `gitops-repo-creds`
- **Type**: Username with Password
- **Username**: Your GitHub username
- **Password**: A GitHub Personal Access Token (PAT) with `repo` scope

## Production Promotion Workflow

```
Jenkins CI passes → commits tag to staging/ → ArgoCD auto-deploys staging
                                            ↓
                              Verify staging is healthy
                                            ↓
                              Open PR: update production/kustomization.yaml
                                            ↓
                              Release manager reviews + merges PR
                                            ↓
                              ArgoCD detects change → syncs production
```
