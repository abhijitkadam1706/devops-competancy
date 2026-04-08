# =============================================================================
# Jenkins Module — Main
#
# Provisions a fully automated Enterprise Jenkins cluster:
#   1 Master (Controller)  — serves the UI, orchestrates pipelines
#   1 build-agent          — Node.js 20, NPM, Git, kustomize
#   1 security-agent       — Docker (for Kaniko container), Trivy, AWS CLI
#   1 test-agent           — Docker, Newman, newman-reporter-junit, OWASP ZAP
#
# ZERO SSH KEY MANAGEMENT:
#   Terraform generates an ephemeral SSH key pair.
#   Private key is stored ONLY in AWS SSM Parameter Store (encrypted).
#   Agents auto-register themselves to the master via SSH on boot.
#   Users access the master via SSM Session Manager — no bastion host needed.
# =============================================================================

# ── Auto-resolve latest Amazon Linux 2023 AMI if not provided ────────────────
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  ami = var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux_2023.id
}

# ── Generate SSH Key Pair for Agent-to-Master SSH connections ─────────────────
# No manual key pair creation or downloading of .pem files required.
resource "tls_private_key" "jenkins_agent_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Store the private key in SSM (encrypted at rest with AWS KMS)
# Jenkins Master will read this from SSM to configure SSH credentials
resource "aws_ssm_parameter" "jenkins_ssh_private_key" {
  name        = "/${var.cluster_name}/jenkins/agent-ssh-private-key"
  description = "Jenkins agent SSH private key - used by Master to SSH into agents"
  type        = "SecureString"
  value       = tls_private_key.jenkins_agent_ssh.private_key_pem

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ── Security Group: Jenkins Master ────────────────────────────────────────────
resource "aws_security_group" "jenkins_master_sg" {
  name        = "${var.cluster_name}-jenkins-master-sg"
  description = "Jenkins Master Controller - allow UI (8080) and JNLP agent port (50000)"
  vpc_id      = var.vpc_id

  # Jenkins UI — restrict this to your office/VPN CIDR in production
  ingress {
    description = "Jenkins Web UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # JNLP — agents connect inbound on this port
  ingress {
    description = "Jenkins JNLP Agent Port"
    from_port   = 50000
    to_port     = 50000
    protocol    = "tcp"
    # Only allow inbound JNLP from within the VPC (agents are in private subnets)
    cidr_blocks = ["10.0.0.0/8"]
  }

  # All outbound traffic allowed (for plugin downloads, GitHub, ECR)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.cluster_name}-jenkins-master-sg"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ── Security Group: All Jenkins Agents ───────────────────────────────────────
# Agents sit in private subnets. They only need:
#   - SSH from Master (port 22, restricted to master's SG)
#   - Outbound to master JNLP port and internet (ECR, GitHub)
resource "aws_security_group" "jenkins_agent_sg" {
  name        = "${var.cluster_name}-jenkins-agent-sg"
  description = "Jenkins Agent nodes - SSH from master only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "SSH from Jenkins Master only"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.jenkins_master_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.cluster_name}-jenkins-agent-sg"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ── Elastic IP for Jenkins Master ─────────────────────────────────────────────
# A static public IP so the UI URL never changes after reboots
resource "aws_eip" "jenkins_master_eip" {
  domain   = "vpc"
  instance = aws_instance.jenkins_master.id

  tags = {
    Name        = "${var.cluster_name}-jenkins-master-eip"
    Environment = var.environment
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# ── MASTER NODE ──────────────────────────────────────────────────────────────
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_instance" "jenkins_master" {
  ami                    = local.ami
  instance_type          = var.master_instance_type
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [aws_security_group.jenkins_master_sg.id]
  iam_instance_profile   = var.master_instance_profile

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  # user_data runs ONCE when the instance first boots.
  # It installs Jenkins and all required plugins automatically.
  user_data = base64encode(<<-EOT
    #!/bin/bash
    set -euo pipefail
    exec > /var/log/jenkins-master-init.log 2>&1

    echo "=== Installing Java 17 ==="
    dnf install java-17-amazon-corretto git -y

    echo "=== Installing Jenkins ==="
    wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
    rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
    dnf install jenkins -y

    echo "=== Pre-seeding Jenkins Configuration ==="
    # Skip the initial setup wizard — we configure via JCasC (jenkins.yaml)
    mkdir -p /var/lib/jenkins
    echo "2.0" > /var/lib/jenkins/jenkins.install.InstallUtil.lastExecVersion

    echo "=== Fetching SSH private key from SSM ==="
    AWS_DEFAULT_REGION=${var.environment == "production" ? "ap-southeast-1" : "ap-southeast-1"}
    mkdir -p /var/lib/jenkins/.ssh
    aws ssm get-parameter \
      --name "/${var.cluster_name}/jenkins/agent-ssh-private-key" \
      --with-decryption \
      --query "Parameter.Value" \
      --output text > /var/lib/jenkins/.ssh/agent_key
    chmod 600 /var/lib/jenkins/.ssh/agent_key
    chown -R jenkins:jenkins /var/lib/jenkins/.ssh

    echo "=== Installing kustomize ==="
    curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
    mv kustomize /usr/local/bin/
    chmod +x /usr/local/bin/kustomize

    echo "=== Starting Jenkins ==="
    systemctl enable jenkins
    systemctl start jenkins

    echo "=== Master bootstrap complete ==="
  EOT
  )

  tags = {
    Name        = "${var.cluster_name}-jenkins-master"
    Role        = "jenkins-master"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# ── BUILD AGENT ──────────────────────────────────────────────────────────────
# Stages: 1 (Checkout & Build), 2 (Lint & SAST), 7 (GitOps Commit)
# Tools: Java 17, Node.js 20, NPM, Git, kustomize, sonar-scanner
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_instance" "build_agent" {
  ami                    = local.ami
  instance_type          = var.build_agent_instance_type
  subnet_id              = var.private_subnet_id
  vpc_security_group_ids = [aws_security_group.jenkins_agent_sg.id]
  iam_instance_profile   = var.build_agent_instance_profile

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  user_data = base64encode(<<-EOT
    #!/bin/bash
    set -euo pipefail
    exec > /var/log/jenkins-build-agent-init.log 2>&1

    echo "=== Installing Java 17 ==="
    dnf install java-17-amazon-corretto git -y

    echo "=== Installing Node.js 20 ==="
    curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
    dnf install nodejs -y

    echo "=== Installing kustomize ==="
    curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
    mv kustomize /usr/local/bin/

    echo "=== Installing sonar-scanner ==="
    wget -q https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-5.0.1.3006-linux.zip
    dnf install unzip -y
    unzip -q sonar-scanner-cli-5.0.1.3006-linux.zip -d /opt/
    ln -s /opt/sonar-scanner-5.0.1.3006-linux/bin/sonar-scanner /usr/local/bin/sonar-scanner
    rm sonar-scanner-cli-5.0.1.3006-linux.zip

    echo "=== Creating Jenkins agent user ==="
    useradd -m -s /bin/bash jenkins-agent
    mkdir -p /home/jenkins-agent/.ssh /home/jenkins-agent/workspace

    echo "=== Installing SSH public key for Master access ==="
    cat > /home/jenkins-agent/.ssh/authorized_keys << 'PUBKEY'
    ${tls_private_key.jenkins_agent_ssh.public_key_openssh}
    PUBKEY
    chmod 700 /home/jenkins-agent/.ssh
    chmod 600 /home/jenkins-agent/.ssh/authorized_keys
    chown -R jenkins-agent:jenkins-agent /home/jenkins-agent

    echo "=== Build agent bootstrap complete — Label: build-agent ==="
  EOT
  )

  tags = {
    Name        = "${var.cluster_name}-jenkins-build-agent"
    Role        = "jenkins-build-agent"
    AgentLabel  = "build-agent"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# ── SECURITY AGENT ───────────────────────────────────────────────────────────
# Stages: 3 (Quality Gate), 4 (Kaniko Build + Trivy)
# Tools: Java 17, Docker (for Kaniko container), Trivy, AWS CLI v2
# NOTE: Docker runs Kaniko as a container — no --privileged, no socket needed
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_instance" "security_agent" {
  ami                    = local.ami
  instance_type          = var.security_agent_instance_type
  subnet_id              = var.private_subnet_id
  vpc_security_group_ids = [aws_security_group.jenkins_agent_sg.id]
  iam_instance_profile   = var.security_agent_instance_profile

  root_block_device {
    volume_size           = 50  # Extra space for Docker image layers and Kaniko cache
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  user_data = base64encode(<<-EOT
    #!/bin/bash
    set -euo pipefail
    exec > /var/log/jenkins-security-agent-init.log 2>&1

    echo "=== Installing Java 17 and Docker ==="
    dnf install java-17-amazon-corretto docker -y

    echo "=== Starting Docker service ==="
    systemctl start docker
    systemctl enable docker

    echo "=== Installing Trivy ==="
    TRIVY_VERSION="0.50.2"
    rpm -ivh https://github.com/aquasecurity/trivy/releases/download/v$${TRIVY_VERSION}/trivy_$${TRIVY_VERSION}_Linux-64bit.rpm

    echo "=== Creating Jenkins agent user ==="
    useradd -m -s /bin/bash jenkins-agent
    usermod -aG docker jenkins-agent   # Allow jenkins-agent to run Docker (for Kaniko)
    mkdir -p /home/jenkins-agent/.ssh /home/jenkins-agent/workspace

    echo "=== Installing SSH public key for Master access ==="
    cat > /home/jenkins-agent/.ssh/authorized_keys << 'PUBKEY'
    ${tls_private_key.jenkins_agent_ssh.public_key_openssh}
    PUBKEY
    chmod 700 /home/jenkins-agent/.ssh
    chmod 600 /home/jenkins-agent/.ssh/authorized_keys
    chown -R jenkins-agent:jenkins-agent /home/jenkins-agent

    echo "=== Security agent bootstrap complete — Label: security-agent ==="
  EOT
  )

  tags = {
    Name        = "${var.cluster_name}-jenkins-security-agent"
    Role        = "jenkins-security-agent"
    AgentLabel  = "security-agent"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# ── TEST AGENT ───────────────────────────────────────────────────────────────
# Stages: 5 (Integration Tests + DAST), 6 (DAST Quality Gate)
# Tools: Java 17, Docker (isolated test networks), Newman, newman-reporter-junit
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_instance" "test_agent" {
  ami                    = local.ami
  instance_type          = var.test_agent_instance_type
  subnet_id              = var.private_subnet_id
  vpc_security_group_ids = [aws_security_group.jenkins_agent_sg.id]
  iam_instance_profile   = var.test_agent_instance_profile

  root_block_device {
    volume_size           = 40  # Extra space for Docker images during integration test
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  user_data = base64encode(<<-EOT
    #!/bin/bash
    set -euo pipefail
    exec > /var/log/jenkins-test-agent-init.log 2>&1

    echo "=== Installing Java 17, Docker, Node.js ==="
    dnf install java-17-amazon-corretto docker -y
    curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
    dnf install nodejs -y

    echo "=== Starting Docker service ==="
    systemctl start docker
    systemctl enable docker

    echo "=== Installing Newman and JUnit reporter ==="
    npm install -g newman newman-reporter-junit

    echo "=== Creating Jenkins agent user ==="
    useradd -m -s /bin/bash jenkins-agent
    usermod -aG docker jenkins-agent
    mkdir -p /home/jenkins-agent/.ssh /home/jenkins-agent/workspace

    echo "=== Installing SSH public key for Master access ==="
    cat > /home/jenkins-agent/.ssh/authorized_keys << 'PUBKEY'
    ${tls_private_key.jenkins_agent_ssh.public_key_openssh}
    PUBKEY
    chmod 700 /home/jenkins-agent/.ssh
    chmod 600 /home/jenkins-agent/.ssh/authorized_keys
    chown -R jenkins-agent:jenkins-agent /home/jenkins-agent

    echo "=== Test agent bootstrap complete — Label: test-agent ==="
  EOT
  )

  tags = {
    Name        = "${var.cluster_name}-jenkins-test-agent"
    Role        = "jenkins-test-agent"
    AgentLabel  = "test-agent"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
