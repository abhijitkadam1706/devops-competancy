# System Architecture — mern-auth Enterprise Platform

## End-to-End Deployment Flow

```
Developer pushes code
        │
        ▼
┌─────────────────────────────────────────────────────────┐
│                   LAYER 1: CI (Jenkins)                 │
│                                                         │
│  Checkout → Lint/SAST → Quality Gate → Kaniko Build     │
│  → Trivy Scan → Integration Tests → ZAP DAST            │
│  → Git commit new tag to mern-auth-gitops repo          │
└────────────────────────┬────────────────────────────────┘
                         │ (Git commit only — no kubectl)
                         ▼
┌─────────────────────────────────────────────────────────┐
│              LAYER 2: GitOps (ArgoCD)                   │
│                                                         │
│  mern-auth-gitops/staging/ ──auto-sync──► Staging K8s   │
│  mern-auth-gitops/production/ ─PR merge─► Prod K8s      │
└────────────────────────┬────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│             LAYER 3: AWS Infrastructure (Terraform)     │
│                                                         │
│  VPC (Multi-AZ, private subnets)                        │
│  EKS (Private endpoint, IRSA, KMS secrets, Audit logs)  │
│  DocumentDB (Private, TLS, KMS, Secrets Manager)        │
│  ALB (HTTPS only, WAF, ACM cert)                        │
│  CloudWatch (Alarms, Dashboard, Flow logs)              │
└─────────────────────────────────────────────────────────┘
```

## Network Architecture

```
Internet
    │ HTTPS:443 only
    ▼
┌─────────────┐
│  AWS WAFv2  │  (OWASP Common Rules, SQLi Rules)
└──────┬──────┘
       │
┌──────▼──────┐
│     ALB     │  (Public subnets — ONLY public-facing component)
└──────┬──────┘
       │
       │  ←── VPC boundary ──────────────────────────────────┐
       ▼                                                      │
┌──────────────────────────────────────────────────────┐     │
│                  Private Subnets                     │     │
│                                                      │     │
│  ┌──────────────────────────────────────────────┐   │     │
│  │           EKS Node Groups (SPOT/OD)          │   │     │
│  │                                              │   │     │
│  │  mern-auth-blue pods  mern-auth-green pods   │   │     │
│  │  ArgoCD              Prometheus              │   │     │
│  └──────────────────────────────────────────────┘   │     │
│                          │                           │     │
│               ┌──────────▼──────────┐               │     │
│               │   Database Subnets  │               │     │
│               │                     │               │     │
│               │    DocumentDB       │               │     │
│               │  (Port 27017, TLS)  │               │     │
│               └─────────────────────┘               │     │
└──────────────────────────────────────────────────────┘     │
                                                             │
       NAT Gateway (Private → Internet for ECR pulls)        │
                                                             │
└────────────────────────────────────────────────────────────┘
```

## Terraform Module Dependency Graph

```
bootstrap.tf (S3 + DynamoDB)
        │
        └── environments/production/
                ├── modules/vpc         (foundation)
                ├── modules/eks         (depends on vpc)
                ├── modules/documentdb  (depends on vpc, eks)
                ├── modules/alb         (depends on vpc, eks)
                ├── modules/iam         (depends on eks, documentdb)
                └── modules/monitoring  (depends on eks, documentdb)
```

## Technology Stack

| Layer | Technology | Version |
|-------|-----------|---------|
| Application | MERN (Node.js + React + MongoDB) | Node 18 |
| Container Runtime | Docker (Kaniko for builds) | - |
| Container Registry | Amazon ECR (IMMUTABLE tags) | - |
| Orchestration | Amazon EKS | K8s 1.32 |
| GitOps | ArgoCD | stable |
| CI | Jenkins | LTS |
| IaC | Terraform | >= 1.7 |
| AWS Provider | hashicorp/aws | ~> 5.40 |
| Service Mesh | (Planned: Istio/Linkerd) | - |
| Secrets | AWS Secrets Manager + Jenkins Credentials | - |
| Monitoring | Prometheus + CloudWatch | - |
| SAST | SonarQube | - |
| Container Scan | Trivy | - |
| DAST | OWASP ZAP | stable |
