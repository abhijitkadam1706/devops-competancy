# Zero-Trust Architecture — mern-auth Platform

Zero-Trust is the principle of **"never trust, always verify."** Every component, even those inside the private network, must authenticate and be authorized before accessing another component.

---

## The 5 Zero-Trust Pillars Implemented

### 1. Identity-Based Access (Not Network-Based)

**Old model:** "If you're inside the VPC, you can access resources."  
**Zero-Trust model:** "Prove who you are cryptographically, regardless of network location."

| Component | Zero-Trust Identity Mechanism |
|-----------|-------------------------------|
| App pods → DocumentDB | IRSA role via OIDC. Pod proves its identity, gets short-lived credentials from Secrets Manager |
| Jenkins → ECR | Scoped IAM role with `sts:AssumeRole`. Only `ecr:PutImage` — nothing else |
| ArgoCD → EKS | In-cluster service account. Never reaches in from outside |
| EKS nodes → AWS APIs | IRSA-based roles per namespace, never node-level credentials |

### 2. Least Privilege IAM Design

Every IAM role is scoped to the **minimum set of actions on the minimum set of resources**.

```hcl
# Jenkins can ONLY push images — nothing else
Statement = [{
  Sid    = "PushImagesToECR"
  Effect = "Allow"
  Action = [
    "ecr:BatchCheckLayerAvailability",
    "ecr:InitiateLayerUpload",
    "ecr:UploadLayerPart",
    "ecr:CompleteLayerUpload",
    "ecr:PutImage"
  ]
  # Only on specific repos — not *
  Resource = var.ecr_repository_arns
}]
```

### 3. Network Micro-Segmentation

No component has unrestricted network access. Every security group is defined per service:

| Component | Ingress Allowed | Egress Allowed |
|-----------|----------------|----------------|
| ALB | 0.0.0.0/0:443, 0.0.0.0/0:80 | App port to VPC CIDR only |
| EKS nodes | Cluster SG, self (inter-node), VPC:9191 | 0.0.0.0/0 via NAT gateway |
| DocumentDB | EKS node SG:27017 ONLY | None (empty egress) |
| Default VPC SG | **STRIPPED — all rules removed** | **STRIPPED** |

### 4. Supply Chain Integrity

The pipeline enforces a cryptographic chain of custody from code to container to cluster:

```
Git commit (SHA pinned)
    │
    ▼ Kaniko builds (no privileged access)
    │
    ▼ Trivy scans (CRITICAL = hard fail)
    │
    ▼ Cosign signs image (cryptographic signature)
    │
    ▼ ECR push (IMMUTABLE tag = cannot be overwritten)
    │
    ▼ ArgoCD deploys (only Cosign-verified images)
              ← (Kyverno admission webhook — planned)
```

### 5. Secrets Never at Rest in Code

| Secret Type | Storage Method |
|-------------|---------------|
| DocumentDB password | Auto-generated, stored exclusively in AWS Secrets Manager (KMS-encrypted) |
| JWT signing key | Jenkins Credentials store (`withCredentials`) |
| AWS credentials | IAM IRSA — NO static keys anywhere |
| Terraform secrets | Never in `.tfvars` — all dynamic via Secrets Manager |

---

## Control Plane Zero-Trust

The most critical zero-trust enforcement is that **Jenkins cannot reach the Kubernetes API**:

```
Jenkins CI           Kubernetes Cluster
  │                       │
  │  ❌ NO ROUTE          │
  │  (No kubeconfig)      │
  │                       ▲
  ▼                       │
Git Repo ──── ArgoCD watches & pulls from inside cluster
```

ArgoCD runs **inside** the cluster. It reaches **out** to Git. Nothing reaches **in** to Kubernetes from CI.

---

## Planned Zero-Trust Enhancements

| Enhancement | Tool | Impact |
|-------------|------|--------|
| Admission control (signature verification) | Kyverno | Blocks unsigned images at cluster level |
| Service mesh mTLS | Istio / Linkerd | East-west traffic encrypted end-to-end |
| Runtime threat detection | Falco | Kills rogue processes inside containers |
| Workload identity federation | SPIFFE/SPIRE | Cryptographic pod identity without IAM |
| Distributed tracing | OpenTelemetry + X-Ray | Full request lineage across services |
