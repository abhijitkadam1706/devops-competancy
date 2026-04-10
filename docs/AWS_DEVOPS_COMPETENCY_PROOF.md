# AWS DevOps Competency — Evidence & Proof Checklist

> This document maps each of the **15 AWS DevOps Competency Technical Controls**
> to specific evidence from this repository and deployed infrastructure.
>
> Use this as your submission guide when preparing case study documentation.

---

## Control-by-Control Evidence Map

### PROC-001 — Customer Assessment of Internal Organization

**What to submit**: Documented process for evaluating customer's DevOps maturity.

| Evidence | Source |
|----------|--------|
| DevOps maturity assessment template | Create a PDF showing your as-is/to-be assessment methodology |
| Maturity categories | Reactive → Proactive → Predictive framework |
| Assessment criteria | Culture, Process, Technology pillars |

**Proof to capture**:
- [ ] PDF document: "DevOps Maturity Assessment Framework"
- [ ] Screenshot of assessment questionnaire/checklist

---

### PROC-002 — Methodology for Organizational Change

**What to submit**: Change management framework with stakeholder alignment.

| Evidence | Source |
|----------|--------|
| Change management process | Document showing phased rollout approach |
| Training plan | DevOps tools training matrix |
| KPIs | Deployment frequency, lead time, MTTR metrics |

**Proof to capture**:
- [ ] PDF document: "DevOps Change Management Framework"
- [ ] Training curriculum document

---

### PRIAC-001 — Templated Infrastructure Provisioning

**What to submit**: Terraform/CloudFormation templates with modular, repeatable deployments.

| Evidence | Source in This Repo |
|----------|-----|
| Modular Terraform | `terraform/modules/` — vpc, eks, jenkins, monitoring |
| Environment separation | `terraform/environments/production/` |
| Variable-driven config | `terraform.tfvars` — parameterized, reusable |
| State management | S3 backend with state locking |
| Version-controlled IaC | Git history of `terraform/` directory |

**Proof to capture**:
- [ ] Screenshot: `terraform plan` output showing resource creation
- [ ] Screenshot: `terraform apply` successful completion
- [ ] Screenshot: AWS Console → EC2/EKS showing provisioned resources
- [ ] Screenshot: Git history showing IaC commits with proper messages
- [ ] Code snippet: Module structure (`terraform/modules/` layout)

---

### PRIAC-002 — Configuration Management

**What to submit**: Automated configuration via SSM, user_data, and infrastructure code.

| Evidence | Source in This Repo |
|----------|-----|
| SSM Parameter Store | All secrets managed as SecureString parameters |
| EC2 user_data automation | `terraform/modules/jenkins/main.tf` — automated bootstrap |
| Configuration-driven | All config via variables, no manual server setup |
| Immutable infrastructure | AMI auto-resolution, reproducible from scratch |

**Proof to capture**:
- [ ] Screenshot: AWS SSM → Parameter Store showing managed parameters
- [ ] Screenshot: EC2 instance user_data log (`/var/log/jenkins-master-init.log`)
- [ ] Code snippet: `user_data` bootstrap script in `main.tf`
- [ ] Screenshot: Jenkins agents auto-bootstrapped and connected

---

### PRIAC-003 — Policy as Code

**What to submit**: Automated compliance and security enforcement.

| Evidence | Source in This Repo |
|----------|-----|
| Security Groups as code | `terraform/modules/jenkins/main.tf` — least-privilege SGs |
| IAM Policies as code | `terraform/modules/iam/` — role-based access |
| Encrypted volumes | All EBS volumes encrypted at rest |
| Network policies | VPC with public/private subnet separation |

**Proof to capture**:
- [ ] Screenshot: AWS Console → VPC → Security Groups (showing restrictive rules)
- [ ] Screenshot: AWS Console → IAM → Roles (showing least-privilege policies)
- [ ] Code snippet: Security group definitions in Terraform
- [ ] Screenshot: EC2 → Volumes showing encryption enabled

---

### PRCICD-001 — Software Release Workflows

**What to submit**: Automated pipeline with defined stages, deployment strategy, rollback.

| Evidence | Source in This Repo |
|----------|-----|
| Jenkins Pipeline | `jenkins-pipeline/Jenkinsfile` — 7-stage pipeline |
| GitOps deployment | ArgoCD syncs K8s manifests from `gitops/` |
| Deployment strategy | Rolling update via Kubernetes + ArgoCD |
| Rollback capability | `argocd app rollback` — automatic via Git history |
| Release workflow | Source → Build → Test → Security → Deploy flow |

**Proof to capture**:
- [ ] Screenshot: Jenkins pipeline stage view (Blue Ocean or classic)
- [ ] Screenshot: ArgoCD application showing sync status
- [ ] Screenshot: Successful pipeline run with all stages green
- [ ] Code snippet: Jenkinsfile stages definition
- [ ] Architecture diagram: CI/CD pipeline flow (use `cicd_architecture_final.png`)

---

### PRCICD-002 — Build and Test Code

**What to submit**: Automated build, test, and code quality processes.

| Evidence | Source in This Repo |
|----------|-----|
| Build automation | Jenkins pipeline: `npm install`, `npm run build` |
| Unit testing | `npm test` with JUnit reporter |
| Static analysis (SAST) | SonarQube scanner integrated in pipeline |
| Integration testing | Newman/Postman API tests |
| DAST | OWASP ZAP dynamic security testing |
| Quality gates | SonarQube quality gate in pipeline stage |

**Proof to capture**:
- [ ] Screenshot: Jenkins build console output showing test execution
- [ ] Screenshot: SonarCloud dashboard for `mern-auth` project
- [ ] Screenshot: SonarQube quality gate pass/fail result
- [ ] Screenshot: Newman test report (HTML or JUnit XML)
- [ ] Screenshot: OWASP ZAP scan results
- [ ] Code snippet: Jenkinsfile build and test stages

---

### PRVCL-001 — Source Control

**What to submit**: Version control setup, branching strategy, code review process.

| Evidence | Source in This Repo |
|----------|-----|
| GitHub repository | `https://github.com/abhijitkadam1706/devops-competancy.git` |
| Branching strategy | `master` (stable) + feature branches |
| Versioned IaC | All Terraform code in version control |
| Versioned pipeline | Jenkinsfile stored in Git |
| GitOps manifests | `gitops/` directory tracked in Git |

**Proof to capture**:
- [ ] Screenshot: GitHub repository overview showing directory structure
- [ ] Screenshot: Git commit history with descriptive messages
- [ ] Screenshot: Branch protection rules (if configured)
- [ ] Screenshot: Pull request workflow example

---

### PRMSC-001 — Container Services

**What to submit**: Container strategy with EKS, ECR, and container builds.

| Evidence | Source in This Repo |
|----------|-----|
| Container orchestration | Amazon EKS v1.30 cluster |
| Container registry | Amazon ECR (staging + production repos) |
| Container builds | Kaniko (rootless, no Docker socket) |
| Container scanning | Trivy vulnerability scanner |
| Image signing | Cosign for supply chain security |
| Kubernetes manifests | `k8s/` and `gitops/` directories |

**Proof to capture**:
- [ ] Screenshot: AWS EKS Console showing cluster details
- [ ] Screenshot: AWS ECR showing pushed container images
- [ ] Screenshot: Trivy scan output (no CRITICAL vulnerabilities)
- [ ] Screenshot: `kubectl get pods` showing running application
- [ ] Code snippet: Kubernetes deployment manifests
- [ ] Architecture diagram: Container deployment flow

---

### PRMLO-001 — Cloud and Network Monitoring

**What to submit**: Monitoring dashboards, alerts, metrics, and logs.

| Evidence | Source in This Repo |
|----------|-----|
| CloudWatch Logs | Log groups for API and application |
| CloudWatch Alarms | CPU, memory, error rate alarms |
| SNS Alerts | Email notifications to `kadamabhijit1706@gmail.com` |
| Prometheus | Metrics collection from EKS workloads |
| Grafana | Visualization dashboards |
| Monitoring IaC | `terraform/modules/monitoring/` |

**Proof to capture**:
- [ ] Screenshot: CloudWatch → Log Groups showing Jenkins/EKS logs
- [ ] Screenshot: CloudWatch → Alarms showing configured alarms
- [ ] Screenshot: SNS topic with confirmed email subscription
- [ ] Screenshot: Grafana dashboard with application metrics
- [ ] Screenshot: Prometheus targets showing scrape status

---

### PRMLO-002 — Distributed Tracing

**What to submit**: Application-level tracing and performance monitoring.

| Evidence | Source in This Repo |
|----------|-----|
| Application metrics | Prometheus metrics endpoint in MERN app |
| Request tracing | Prometheus + Grafana service-level metrics |
| Performance analysis | Grafana dashboards with latency/error panels |

**Proof to capture**:
- [ ] Screenshot: Grafana dashboard with request latency metrics
- [ ] Screenshot: Prometheus query showing request traces
- [ ] Description of how tracing helps debug production issues

> **Note**: If AWS X-Ray is not used, document the alternative approach
> (Prometheus/Grafana) with justification for the case study.

---

### PRMLO-003 — Activity and API Usage Tracking

**What to submit**: CloudTrail logging and API activity monitoring.

| Evidence | Source in This Repo |
|----------|-----|
| CloudTrail | Enabled by default in AWS account |
| API logging | CloudTrail captures all AWS API calls |
| Log analysis | CloudWatch Logs Insights for query/analysis |

**Proof to capture**:
- [ ] Screenshot: AWS CloudTrail → Event history showing API calls
- [ ] Screenshot: CloudTrail trail configuration showing S3 storage
- [ ] Example query: CloudWatch Logs Insights showing API analysis

---

### PRPAS-001 — Orchestration to Run and Manage Web Apps

**What to submit**: Application deployment and management strategy.

| Evidence | Source in This Repo |
|----------|-----|
| Container orchestration | Amazon EKS manages app deployment |
| GitOps deployment | ArgoCD automates Kubernetes deployments |
| Auto-scaling | EKS node auto-scaling + HPA for pods |
| Health monitoring | Kubernetes liveness/readiness probes |
| Load balancing | AWS ALB via Kubernetes Ingress |

**Proof to capture**:
- [ ] Screenshot: ArgoCD showing application sync and health
- [ ] Screenshot: `kubectl get pods,svc,ingress` output
- [ ] Screenshot: AWS ALB showing target group health
- [ ] Description of deployment strategy (rolling update)

---

### PRSEC-001 — Communication of DevSecOps Best Practices

**What to submit**: Security integration throughout the SDLC.

| Evidence | Source in This Repo |
|----------|-----|
| Shift-left security | SAST (SonarQube) runs early in pipeline |
| Container scanning | Trivy scans images before deployment |
| Image signing | Cosign signs verified images |
| DAST | OWASP ZAP runtime security testing |
| Encryption at rest | All EBS and DocumentDB volumes encrypted |
| Encryption in transit | HTTPS via ALB + ACM (when domain configured) |
| Secret management | AWS SSM Parameter Store (KMS encrypted) |
| Least-privilege IAM | Role-based IAM policies per component |

**Proof to capture**:
- [ ] Screenshot: SonarQube security analysis results
- [ ] Screenshot: Trivy scan output showing vulnerability check
- [ ] Screenshot: Pipeline stage showing security scan execution
- [ ] Screenshot: SSM Parameter Store showing encrypted secrets
- [ ] PDF document: "DevSecOps Best Practices for MERN Applications"
- [ ] Architecture diagram showing security controls at each layer

---

## Summary: Evidence Collection Checklist

### Screenshots Needed (Total: ~25)

| Category | Count | Items |
|----------|-------|-------|
| Terraform/IaC | 4 | plan, apply, console resources, git history |
| Jenkins Pipeline | 5 | login, agents, pipeline run, stage view, build log |
| SonarQube | 2 | dashboard, quality gate |
| Container/EKS | 4 | EKS console, ECR images, pods, Trivy scan |
| Monitoring | 4 | CloudWatch logs/alarms, Grafana, Prometheus |
| ArgoCD | 2 | app sync, deployment health |
| Security | 3 | SSM params, security groups, IAM roles |
| CloudTrail | 1 | API event history |

### Documents Needed (Total: 3)

1. **DevOps Maturity Assessment Framework** (PDF) — for PROC-001
2. **Change Management Methodology** (PDF) — for PROC-002
3. **DevSecOps Best Practices** (PDF) — for PRSEC-001

### Architecture Diagrams Needed (Total: 2)

1. **CI/CD Pipeline Flow** — `cicd_architecture_final.png` (already exists)
2. **Infrastructure Architecture** — VPC, EKS, Jenkins, monitoring components

---

## Quick Reference: AWS Services Used

| Service | Purpose | Control |
|---------|---------|---------|
| EKS | Container orchestration | PRMSC-001 |
| ECR | Container registry | PRMSC-001 |
| EC2 | Jenkins master and agents | PRCICD-002 |
| SSM Parameter Store | Secret management | PRIAC-002, PRSEC-001 |
| CloudWatch | Monitoring, logging, alarms | PRMLO-001 |
| CloudTrail | API activity tracking | PRMLO-003 |
| SNS | Alert notifications | PRMLO-001 |
| IAM | Role-based access control | PRSEC-001 |
| VPC | Network isolation | PRIAC-003 |
| ALB | Load balancing | PRPAS-001 |
| DocumentDB | MongoDB-compatible database | Application |
| S3 | Terraform state, CloudTrail logs | PRIAC-001 |
| KMS | Encryption key management | PRSEC-001 |
