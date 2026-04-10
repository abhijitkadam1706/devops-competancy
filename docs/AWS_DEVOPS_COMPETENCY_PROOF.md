# AWS DevOps Competency — Evidence & Proof Checklist

> **Who is this for?** You — the person submitting the AWS DevOps Competency case study.
> This document tells you exactly **what proof to collect** for each of the 15 technical
> controls, and **where in this project** to find it.
>
> Think of it as a checklist. Work through each section, collect the screenshots or documents
> listed, and you will have everything needed for submission.

---

## How the Controls Map to This Project

```
PROC-001 → Assessment document (PDF you create)
PROC-002 → Change management document (PDF you create)
PRIAC-001 → Terraform modules in terraform/
PRIAC-002 → SSM Parameter Store + EC2 bootstrap automation
PRIAC-003 → Security Groups, IAM policies, KMS encryption
PRCICD-001 → Jenkins Jenkinsfile 7-stage pipeline + ArgoCD
PRCICD-002 → Build, test, lint stages in the pipeline
PRVCL-001 → GitHub repository and Git history
PRMSC-001 → Amazon EKS + ECR + Kaniko builds
PRMLO-001 → CloudWatch, Prometheus, Grafana, SNS alerts
PRMLO-002 → Prometheus metrics in the MERN app + Grafana
PRMLO-003 → AWS CloudTrail
PRPAS-001 → EKS + ArgoCD + ALB + HPA
PRSEC-001 → Trivy, Cosign, OWASP ZAP, WAF, SSM, KMS
```

---

## PROC-001 — Customer Assessment of Internal Organization

**In plain English:** Show that you have a structured way to evaluate how "mature" a customer's
DevOps setup is before you start working with them.

**What to submit:**

- [ ] **PDF document** titled "DevOps Maturity Assessment Framework"
  - Include a table with 3 columns: Area | Current State | Target State
  - Cover at least: Culture, Processes, Tools & Automation, Monitoring
  - Show the maturity levels: Reactive → Proactive → Predictive
- [ ] **Screenshot** of assessment questionnaire or checklist you use with customers

> **Tip:** This does not need to be about the MERN app specifically. It is a methodology
> document that shows you know *how* to assess DevOps maturity.

---

## PROC-002 — Methodology for Organizational Change

**In plain English:** Show that you have a structured approach for helping organizations
change to DevOps practices — not just technical change but people and process too.

**What to submit:**

- [ ] **PDF document** titled "DevOps Transformation Change Management Plan"
  - Show phased approach: Discovery → Pilot → Scale → Embed
  - Include a training plan (who learns what tool/process)
  - Include KPI metrics: deployment frequency, lead time, MTTR, change failure rate
- [ ] **Training matrix document** showing team skill gaps and learning path

---

## PRIAC-001 — Templated Infrastructure Provisioning

**In plain English:** All infrastructure (servers, networks, databases) is created from code
templates, not by clicking in the AWS Console.

**Where it is in this project:**

| Evidence | Location |
|----------|---------|
| Modular Terraform templates | `terraform/modules/` — vpc, eks, iam, jenkins, alb, documentdb, monitoring |
| Production environment config | `terraform/environments/production/` |
| No hardcoded values | `terraform.tfvars` controls all sizes and settings |
| S3 backend (state management) | `terraform/environments/production/backend.tf` |
| Git-tracked IaC changes | Git commit history for `terraform/` directory |

**Screenshots to take:**

- [ ] `terraform plan` output in your terminal — shows planned resource creation
- [ ] `terraform apply` — the final "Apply complete! X added" success message
- [ ] AWS Console → EC2 showing Jenkins master and 3 agent instances
- [ ] AWS Console → EKS showing the `mern-auth-prod` cluster
- [ ] GitHub → repository showing the `terraform/modules/` folder structure
- [ ] Git log showing commit messages — proof everything is version-controlled

---

## PRIAC-002 — Configuration Management

**In plain English:** Server configuration is automated. Nothing is done manually on servers
after they are created — software is installed and configured by code.

**Where it is in this project:**

| Evidence | Location |
|----------|---------|
| All passwords/tokens in SSM | AWS SSM Parameter Store → `/mern-auth-prod/jenkins/*` |
| Jenkins bootstrap automation | `terraform/modules/jenkins/main.tf` → `user_data` script |
| Environment tags on all resources | Every AWS resource has `Name` + `Environment` tags |
| Immutable infra (new AMI, fresh server) | EC2 `aws_ami` data source — always latest Amazon Linux 2 |

**Screenshots to take:**

- [ ] AWS Console → Systems Manager → Parameter Store — showing all `/mern-auth-prod/jenkins/*` parameters with `SecureString` type
- [ ] Jenkins EC2 instance tag showing `Environment = production`
- [ ] EC2 → Instance → Actions → View user data — shows the automated bootstrap script
- [ ] CloudWatch Logs → `/aws/ec2/jenkins-master` → the bootstrap log with `[1/5] [2/5]...` entries

---

## PRIAC-003 — Policy as Code

**In plain English:** Security rules (who can access what, what traffic is allowed) are written
in Terraform code, not configured manually in the AWS Console.

**Where it is in this project:**

| Evidence | Location |
|----------|---------|
| Least-privilege security groups | `terraform/modules/jenkins/main.tf` — exact ports only |
| Per-role IAM policies | `terraform/modules/iam/main.tf` — separate role per Jenkins node |
| Encrypted EBS volumes | All EC2 `root_block_device` blocks have `encrypted = true` |
| IMDSv2 enforcement | All EC2 instances have `metadata_options { http_tokens = required }` |
| VPC isolation | `terraform/modules/vpc/main.tf` — public/private/database subnet tiers |
| WAF (Web Application Firewall) | `terraform/modules/alb/main.tf` — AWS Managed Rules enabled |

**Screenshots to take:**

- [ ] AWS Console → VPC → Security Groups — showing Jenkins master SG with only ports 8080 (HTTP) and 22 (SSH from VPC only)
- [ ] AWS Console → IAM → Roles — search for "mern-auth-prod" to see all 4 Jenkins roles
- [ ] One IAM role → Permissions tab — shows the exact minimal permissions
- [ ] AWS Console → EC2 → Volumes — all volumes show "Encrypted: Yes"

---

## PRCICD-001 — Software Release Workflows

**In plain English:** Code changes automatically go through a complete pipeline: build → test → security check → deploy. Releases are controlled and rollbacks are possible.

**Where it is in this project:**

| Evidence | Location |
|----------|---------|
| 7-stage Jenkins pipeline | `jenkins-pipeline/Jenkinsfile` |
| Staging deployment (auto) | ArgoCD watches `gitops/staging/` — auto-syncs on commit |
| Production promotion (manual) | PR-based workflow to `gitops/production/` → manual ArgoCD sync |
| Rollback | `argocd app rollback mern-auth-staging` — rolls back to any previous Git commit |
| Build number and Git SHA in image tags | Format: `<BUILD_NUMBER>-<8-char-SHA>` |

**Screenshots to take:**

- [ ] Jenkins → Pipeline → Stage View showing all 7 stages green
- [ ] ArgoCD UI showing `mern-auth-staging` application with "Synced" and "Healthy" status
- [ ] ArgoCD → App Details → History — showing multiple previous deployment versions
- [ ] Jenkins console log showing the GitOps commit message (`ci(staging): deploy XXXXXX [build #N]`)

---

## PRCICD-002 — Build and Test Code

**In plain English:** Code is automatically built, tested for bugs, scanned for security issues, and must reach a quality threshold before being deployed.

**Where it is in this project:**

| Evidence | Location |
|----------|---------|
| Build automation | Jenkinsfile Stage 1 — `npm ci`, `npm run build` |
| Unit tests | Jenkinsfile Stage 1 — Vitest with coverage report |
| Static analysis (SAST) | Jenkinsfile Stage 2 — SonarQube scanner → SonarCloud |
| Code coverage gate | Jenkinsfile Stage 3 — fails if < 80% line coverage |
| Integration tests | Jenkinsfile Stage 5 — Newman/Postman API test collection |
| DAST | Jenkinsfile Stage 5 — OWASP ZAP baseline scan |
| Test script | `mern-auth/package.json` — `npm run test` and `npm run test:coverage` |

**Screenshots to take:**

- [ ] Jenkins build console output showing `npm test` passing
- [ ] SonarCloud dashboard at `https://sonarcloud.io` showing the `mern-auth` project
- [ ] SonarCloud quality gate result — "Passed" badge
- [ ] Newman HTML/JUnit report showing API test results (in Jenkins artifacts)
- [ ] OWASP ZAP XML report in Jenkins → Build → Artifacts
- [ ] Jenkins Stage View showing Stage 2 and Stage 3 green

---

## PRVCL-001 — Source Control

**In plain English:** All code — application, infrastructure, pipeline scripts, Kubernetes manifests — is stored in Git with clear history.

**Where it is in this project:**

| Evidence | Location |
|----------|---------|
| Central repository | `https://github.com/abhijitkadam1706/devops-competancy.git` |
| IaC version controlled | All `terraform/` changes tracked in Git |
| Pipeline as code | `jenkins-pipeline/Jenkinsfile` stored in Git |
| GitOps manifests in Git | `gitops/base/`, `gitops/staging/`, `gitops/production/` |
| Conventional commit messages | Descriptive messages like `"security: harden Jenkins..."` |

**Screenshots to take:**

- [ ] GitHub repository home page — showing the folder structure
- [ ] GitHub → Commits → showing commit history with descriptive messages
- [ ] GitHub → showing `terraform/`, `gitops/`, `jenkins-pipeline/`, `mern-auth/` folders
- [ ] *(Optional)* GitHub → Branch protection rules if configured

---

## PRMSC-001 — Container Services

**In plain English:** The application runs in containers, managed by Kubernetes (EKS), with images stored in Amazon ECR.

**Where it is in this project:**

| Evidence | Location |
|----------|---------|
| Container orchestration | Amazon EKS v1.30, `mern-auth-prod` cluster |
| Container registry | Amazon ECR — 3 repos: `mern-auth/stage`, `mern-auth/prod`, `kaniko-cache` |
| ECR image scanning | `scan_on_push = true` on stage and prod repos |
| ECR image immutability | `image_tag_mutability = "IMMUTABLE"` — tags cannot be overwritten |
| Container builds (rootless) | Kaniko — no Docker socket, no `--privileged` flag |
| Container vulnerability scanning | Trivy — blocks pipeline if CRITICAL CVEs found |
| Image signing | Cosign — signs every image pushed to ECR |
| Kubernetes manifests | `gitops/base/` — Deployment, Service, Ingress, HPA, PDB |

**Screenshots to take:**

- [ ] AWS Console → Amazon EKS → `mern-auth-prod` cluster → Overview tab
- [ ] AWS Console → Amazon ECR → showing `mern-auth/stage` repository with pushed images
- [ ] Jenkins Stage 4 log — showing Kaniko build completing and Trivy scan result
- [ ] `kubectl get pods -n mern-auth-staging` — showing pods in Running state
- [ ] Cosign verification: `cosign verify <ECR_IMAGE> --key cosign.pub`

---

## PRMLO-001 — Cloud and Network Monitoring

**In plain English:** The infrastructure and application are monitored. Alerts fire automatically when something goes wrong.

**Where it is in this project:**

| Evidence | Location |
|----------|---------|
| VPC Flow Logs | CloudWatch Logs → `/aws/vpc/mern-auth-prod/flow-logs` |
| CloudWatch Alarms | `terraform/modules/monitoring/` — CPU, memory, error rate alarms |
| Email alerts via SNS | Alerts go to `kadamabhijit1706@gmail.com` |
| Prometheus | Helm chart installed on EKS — scrapes app and Kubernetes metrics |
| Grafana | Pre-built dashboards for EKS and application metrics |

**Screenshots to take:**

- [ ] CloudWatch → Log Groups — showing `/aws/vpc/mern-auth-prod/flow-logs`
- [ ] CloudWatch → Alarms — showing configured alarms (all in OK state = green)
- [ ] SNS → Topics — showing the alert topic and confirmed email subscription
- [ ] Grafana home page — showing dashboards (Kubernetes / MERN app metrics)
- [ ] Prometheus → Targets — showing scrape endpoints as "UP"

---

## PRMLO-002 — Distributed Tracing

**In plain English:** You can see how requests flow through the application and identify where slowdowns happen.

**Where it is in this project:**

| Evidence | Location |
|----------|---------|
| Application Prometheus metrics | `mern-auth/api/index.js` — `express-prom-bundle` middleware |
| Metrics endpoint | `/metrics` on the running app — HTTP request duration, count, status codes |
| Visualization | Grafana dashboards showing request latency and error rate per endpoint |

**Screenshots to take:**

- [ ] Browser showing `http://<APP_URL>/metrics` — raw Prometheus metrics output
- [ ] Grafana panel showing `http_request_duration_seconds` histogram by route
- [ ] Grafana showing error rate (5xx responses) over time

> **Note:** This project uses Prometheus/Grafana instead of AWS X-Ray. Both are valid
> approaches for the competency. Document this choice in your case study narrative.

---

## PRMLO-003 — Activity and API Usage Tracking

**In plain English:** Every action taken in AWS is logged and auditable — who did what, when.

**Where it is in this project:**

| Evidence | Source |
|----------|--------|
| AWS CloudTrail | Enabled by default in your AWS account |
| All API calls logged | Every Terraform change, Jenkins action, kubectl command is recorded |
| CloudWatch Logs Insights | Query tool to search through API event history |

**Screenshots to take:**

- [ ] AWS Console → CloudTrail → Event history — showing recent API calls (filter by "mern-auth")
- [ ] CloudTrail → Trails — if you created a custom trail, show it storing to S3
- [ ] CloudWatch → Logs Insights — run a sample query showing API activity

---

## PRPAS-001 — Orchestration to Run and Manage Web Apps

**In plain English:** The application deploys automatically, scales automatically, and recovers automatically from failures.

**Where it is in this project:**

| Evidence | Location |
|----------|---------|
| Kubernetes deployment | `gitops/base/deployment.yaml` — rolling update strategy |
| Auto-scaling (pods) | `gitops/base/hpa.yaml` — scales 2 to 10 pods based on CPU/memory |
| High availability | `gitops/base/pdb.yaml` — PodDisruptionBudget keeps at least 1 pod alive |
| Load balancing | `gitops/base/ingress.yaml` — AWS ALB routes traffic to healthy pods |
| GitOps automation | ArgoCD deploys automatically on every new image tag commit |

**Screenshots to take:**

- [ ] ArgoCD → `mern-auth-staging` → "Synced" and "Healthy" status
- [ ] `kubectl get pods,svc,hpa -n mern-auth-staging` — showing all resources
- [ ] AWS Console → EC2 → Load Balancers — showing ALB with healthy targets
- [ ] ArgoCD → History tab — showing multiple deployment versions (proof of rollback capability)

---

## PRSEC-001 — Communication of DevSecOps Best Practices

**In plain English:** Security is built into every step of the process, not added at the end.

**Where it is in this project:**

| Layer | Evidence | Location |
|-------|----------|---------|
| Code | SAST via SonarCloud | Jenkinsfile Stage 2 |
| Code | ESLint security rules | Jenkinsfile Stage 2 |
| Container | Trivy scans images for CVEs | Jenkinsfile Stage 4 |
| Container | Cosign signs every image | Jenkinsfile Stage 4 |
| Container | SBOM (Software Bill of Materials) generated | Jenkinsfile Stage 4 |
| Runtime | OWASP ZAP DAST scan | Jenkinsfile Stage 5 |
| Secrets | SSM Parameter Store (KMS encrypted) | `terraform/environments/production/main.tf` |
| Network | WAF with AWS Managed Rules | `terraform/modules/alb/main.tf` |
| Network | VPC with private subnets | `terraform/modules/vpc/main.tf` |
| Compute | IMDSv2 enforced on all EC2 | `terraform/modules/jenkins/main.tf` |
| Data | KMS encryption at rest (EBS + DocumentDB) | All `encrypted = true` in Terraform |
| IAM | Least-privilege per role | `terraform/modules/iam/main.tf` |

**Screenshots to take:**

- [ ] SonarCloud dashboard — Security tab showing 0 vulnerabilities
- [ ] Trivy scan output in Jenkins — "No CRITICAL vulnerabilities found"
- [ ] Jenkins Stage 4 log — showing Cosign sign command completing
- [ ] OWASP ZAP report — Stage 5 output showing 0 HIGH-risk alerts
- [ ] AWS Console → SSM → Parameter Store — all secrets as `SecureString` (not `String`)
- [ ] AWS WAF → Web ACLs — showing `mern-auth-prod-waf` with Common and SQLi rules enabled
- [ ] AWS Console → EC2 → Instances → `mern-auth-prod-jenkins-master` → Instance metadata — showing "IMDSv2 required"

- [ ] **PDF document** titled "DevSecOps Best Practices for MERN-Auth Application"
  - Describe each security layer: code → container → runtime → network → data
  - Include diagrams showing where each tool fits in the pipeline

---

## Summary Checklist

### Screenshots to Collect (Total: ~30)

| Category | Count | Key Items |
|----------|-------|-----------|
| IaC / Terraform | 6 | plan, apply, EC2 console, EKS console, folder structure, git log |
| Jenkins | 5 | login page, agents online, stage view, build success, console log |
| SonarCloud | 3 | project dashboard, quality gate pass, security tab |
| Containers / EKS | 5 | EKS cluster, ECR images, Trivy clean, Cosign sign, kubectl pods |
| Monitoring | 5 | CloudWatch log groups, alarms, Grafana, Prometheus targets, SNS |
| ArgoCD / GitOps | 3 | app synced, history tab, app health |
| Security | 4 | SSM params, WAF rules, IMDSv2, ZAP report |
| CloudTrail | 1 | Event history |

### PDF Documents to Create (Total: 3)

| Document | For Control | Approximate Length |
|----------|------------|-------------------|
| 1. DevOps Maturity Assessment Framework | PROC-001 | 3–5 pages |
| 2. DevOps Transformation Change Management Plan | PROC-002 | 4–6 pages |
| 3. DevSecOps Best Practices for MERN Applications | PRSEC-001 | 4–6 pages |

### Architecture Diagrams to Include (Total: 2)

1. **CI/CD Pipeline Flow** — Shows code commit → Jenkins stages → ECR → ArgoCD → EKS
2. **Infrastructure Architecture** — Shows VPC layers, EKS, Jenkins, DocumentDB, ALB, WAF

---

## Quick Reference: AWS Services Used

| AWS Service | What It Does in This Project | Competency Control |
|-------------|-----------------------------|--------------------|
| EKS | Runs the application containers | PRMSC-001 |
| ECR | Stores Docker images | PRMSC-001 |
| EC2 | Jenkins master + 3 agent servers | PRCICD-001 |
| SSM Parameter Store | Stores all secrets (encrypted) | PRIAC-002, PRSEC-001 |
| KMS | Encryption keys for SSM, EBS, DocDB | PRSEC-001 |
| CloudWatch | Logs, metrics, alarms | PRMLO-001 |
| CloudTrail | Records all AWS API activity | PRMLO-003 |
| SNS | Sends email alerts | PRMLO-001 |
| IAM | Controls who can do what | PRIAC-003, PRSEC-001 |
| VPC | Network isolation (public/private/db subnets) | PRIAC-003 |
| ALB | Load balancer for the application | PRPAS-001 |
| WAF | Blocks web attacks (SQLi, XSS, bad bots) | PRSEC-001 |
| DocumentDB | MongoDB-compatible database | Application |
| S3 | Stores Terraform remote state | PRIAC-001 |
