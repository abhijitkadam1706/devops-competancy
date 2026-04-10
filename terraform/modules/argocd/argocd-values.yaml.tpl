# =============================================================================
# ArgoCD Helm Values Template
# Rendered by Terraform templatefile() — variables injected at apply time
#
# ROOT CAUSE FIX — service.type: ClusterIP + Ingress (was: LoadBalancer)
# ──────────────────────────────────────────────────────────────────────────
# The original LoadBalancer type caused Helm wait=true to block until AWS
# assigned an external hostname to the service — which takes 5-10 minutes
# AFTER all pods are healthy. This consistently exceeded the Helm timeout.
#
# Fix: ClusterIP service → Helm only waits for pod readiness (fast ~3 min)
#      ALB Ingress      → provisions asynchronously, never blocks Helm
# =============================================================================

global:
  domain: ""   # Using raw ALB DNS — no custom domain required

configs:
  params:
    # Disable TLS on the server side — ALB terminates TLS
    server.insecure: true

  cm:
    # Enable status badge
    statusbadge.enabled: true
    # Application reconciliation every 3 minutes
    timeout.reconciliation: "180s"

  rbac:
    # Default role: read-only for all authenticated users
    policy.default: "role:readonly"
    policy.csv: |
      p, role:admin, applications, *, */*, allow
      p, role:admin, clusters,     get, *, allow
      p, role:admin, repositories, get, *, allow
      p, role:admin, repositories, create, *, allow
      p, role:admin, repositories, update, *, allow
      p, role:admin, repositories, delete, *, allow
      g, argocd-admins, role:admin

server:
  # ── SERVICE: ClusterIP ────────────────────────────────────────────────────
  # ClusterIP means Helm wait=true only checks pod readiness (takes ~3 min).
  # It does NOT wait for AWS to provision an ALB, eliminating the timeout race.
  service:
    type: ClusterIP

  # ── INGRESS: ALB via AWS Load Balancer Controller ─────────────────────────
  # ALB provisions asynchronously AFTER the Helm release is already marked
  # successful. This is the correct AWS pattern for EKS + ArgoCD.
  ingress:
    enabled: true
    ingressClassName: alb
    annotations:
      kubernetes.io/ingress.class: alb
      alb.ingress.kubernetes.io/scheme: internet-facing
      alb.ingress.kubernetes.io/target-type: ip
      alb.ingress.kubernetes.io/backend-protocol: HTTP
      alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
      # Health check on ArgoCD's readiness endpoint
      alb.ingress.kubernetes.io/healthcheck-path: /healthz/ready
      alb.ingress.kubernetes.io/healthcheck-protocol: HTTP
      alb.ingress.kubernetes.io/success-codes: "200,302"
    hosts:
      - ""   # Empty string = match all hostnames (raw ALB DNS)

  # Resource limits — right-sized for production
  resources:
    requests:
      cpu:    "100m"
      memory: "128Mi"
    limits:
      cpu:    "500m"
      memory: "512Mi"

  # High availability — 2 replicas
  replicas: 2

applicationSet:
  replicas: 2
  resources:
    requests:
      cpu:    "100m"
      memory: "128Mi"
    limits:
      cpu:    "500m"
      memory: "256Mi"

repoServer:
  replicas: 2
  resources:
    requests:
      cpu:    "100m"
      memory: "256Mi"
    limits:
      cpu:    "1000m"
      memory: "512Mi"

redis:
  resources:
    requests:
      cpu:    "100m"
      memory: "64Mi"
    limits:
      cpu:    "200m"
      memory: "128Mi"

controller:
  resources:
    requests:
      cpu:    "250m"
      memory: "512Mi"
    limits:
      cpu:    "1000m"
      memory: "1Gi"

# Enable Prometheus metrics scraping
metrics:
  enabled: true
  serviceMonitor:
    enabled: true
    namespace: monitoring

# Notifications controller (for Slack/email alerts on sync)
notifications:
  enabled: true
  resources:
    requests:
      cpu:    "100m"
      memory: "64Mi"
    limits:
      cpu:    "200m"
      memory: "128Mi"
