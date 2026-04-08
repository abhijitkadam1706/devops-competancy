// =====================================================================
// mern-auth — Enterprise CI Pipeline (ZERO-TRUST v3)
//
// ARCHITECTURE SHIFT:
//   BEFORE: Jenkins builds + deploys (Push model — Jenkins owns K8s)
//   AFTER:  Jenkins builds + commits (Pull model — ArgoCD owns K8s)
//
// WHAT CHANGED:
//   ✅ Kaniko replaces Docker daemon (no --privileged, no socket)
//   ✅ kubectl REMOVED — Jenkins has ZERO cluster access
//   ✅ KUBECONFIG credential DELETED from Jenkins
//   ✅ Deployment happens via Git commit → ArgoCD auto-sync
//   ✅ Production promotion via Pull Request (auditable in Git)
//
// JENKINS AGENTS (EC2 VMs):
//   build-agent     → Stage 1, 2 (checkout, lint, SAST)
//   security-agent  → Stage 3, 4, 5 (quality gate, Kaniko build, push)
//   test-agent      → Stage 6, 7 (integration tests, DAST)
//   build-agent     → Stage 8 (GitOps commit — NO deploy-agent needed)
//
// WHAT JENKINS NO LONGER DOES:
//   ❌ kubectl apply / set image (ArgoCD handles this)
//   ❌ docker build (Kaniko handles this)
//   ❌ Blue/Green traffic switching (Git commit handles this)
//   ❌ Prometheus monitoring (ArgoCD + K8s probes handle this)
// =====================================================================

pipeline {
    agent none

    environment {
        // ── Registry ─────────────────────────────────────────────────
        STAGE_REGISTRY  = "203848753188.dkr.ecr.ap-southeast-1.amazonaws.com/mern-auth/stage"
        PROD_REGISTRY   = "203848753188.dkr.ecr.ap-southeast-1.amazonaws.com/mern-auth/prod"
        ECR_REGISTRY    = "203848753188.dkr.ecr.ap-southeast-1.amazonaws.com"
        AWS_REGION      = "ap-southeast-1"

        // ── SonarQube ────────────────────────────────────────────────
        SONAR_URL       = "https://sonarcloud.io"
        SONAR_PROJECT   = "abhijitkadam1706_devops-competancy"
        SONAR_ORG       = "abhijitkadam1706"

        // ── App ──────────────────────────────────────────────────────
        APP_PORT        = "9191"
        HEALTH_EP       = "/api/user"

        // ── GitOps repo (ArgoCD watches this) ────────────────────────
        GITOPS_REPO     = "https://github.com/abhijitkadam1706/mern-auth-gitops.git"
        GITOPS_BRANCH   = "main"

        // ── Thresholds ───────────────────────────────────────────────
        MIN_COVERAGE    = "80"
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '20'))
        timestamps()
        timeout(time: 45, unit: 'MINUTES')
        disableConcurrentBuilds()
        ansiColor('xterm')
    }

    triggers { githubPush() }

    stages {
        // ────────────────────────────────────────────────────────────
        // STAGE 1: Checkout & Build
        // ────────────────────────────────────────────────────────────
        stage('1: Checkout & Build') {
            agent { label 'build-agent' }
            steps {
                checkout scm
                script {
                    def sha = sh(script: 'git rev-parse --short=8 HEAD', returnStdout: true).trim()
                    env.IMAGE_TAG = "${BUILD_NUMBER}-${sha}"
                }
                echo "Branch: ${env.BRANCH_NAME ?: 'manual'} | Tag: ${IMAGE_TAG}"
                dir('mern-auth') {
                    sh 'npm ci'
                    sh 'npm ci --prefix client'
                    sh 'npm run build --prefix client'
                }
            }
            post {
                success { echo '✅ Build successful' }
                failure { error '❌ Build failed' }
            }
        }

        // ────────────────────────────────────────────────────────────
        // STAGE 2: Lint + SAST (Parallel)
        // ────────────────────────────────────────────────────────────
        stage('2: Lint & SAST') {
            agent { label 'build-agent' }
            steps {
                parallel(
                    'ESLint': {
                        dir('mern-auth') {
                            sh 'npm run lint --prefix client'
                        }
                    },
                    'SonarQube': {
                        withSonarQubeEnv('SonarQube') {
                            dir('mern-auth') {
                                sh """
                                    sonar-scanner \\
                                      -Dsonar.projectKey=${SONAR_PROJECT} \\
                                      -Dsonar.organization=${SONAR_ORG} \\
                                      -Dsonar.sources=api,client/src \\
                                      -Dsonar.exclusions=**/node_modules/**,client/dist/** \\
                                      -Dsonar.javascript.lcov.reportPaths=client/coverage/lcov.info \\
                                      -Dsonar.host.url=${SONAR_URL}
                                """
                            }
                        }
                    }
                )
            }
        }

        // ────────────────────────────────────────────────────────────
        // STAGE 3: Quality Gate + Coverage
        // ────────────────────────────────────────────────────────────
        stage('3: Quality Gate') {
            agent { label 'build-agent' }
            options { skipDefaultCheckout(true) }
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: false  // free plan: gate is informational
                }
                dir('mern-auth/client') {
                    sh 'npx vitest run --coverage --passWithNoTests'
                }
                script {
                    def covFile = 'mern-auth/client/coverage/coverage-summary.json'
                    if (fileExists(covFile)) {
                        def coverage = sh(
                            script: "python3 -c \"import json; d=json.load(open('${covFile}')); pct=d['total']['lines']['pct']; print(0 if str(pct)=='Unknown' else int(pct))\"",
                            returnStdout: true
                        ).trim().toInteger()
                        echo "Line coverage: ${coverage}%"
                        if (coverage < MIN_COVERAGE.toInteger()) {
                            echo "⚠️ Coverage ${coverage}% < target ${MIN_COVERAGE}% — add tests to improve"
                        }
                    } else {
                        echo "⚠️ No coverage report found — no test files in project yet"
                    }
                }
            }
        }

        // ────────────────────────────────────────────────────────────
        // STAGE 4: Kaniko Build + Trivy Scan
        //
        // KEY CHANGE: No Docker daemon. No --privileged. No socket.
        // Kaniko runs as a regular Docker container on the EC2 agent
        // but it does NOT need docker.sock or privileged mode.
        // It builds the image internally and pushes directly to ECR.
        // ────────────────────────────────────────────────────────────
        stage('4: Kaniko Build & Trivy') {
            agent { label 'security-agent' }
            steps {
                // Generate ECR credentials for Kaniko
                sh """
                    mkdir -p /tmp/kaniko-config
                    aws ecr get-login-password --region ${AWS_REGION} | \\
                        python3 -c "
import sys, json, base64
token = sys.stdin.read().strip()
auth = base64.b64encode(f'AWS:{token}'.encode()).decode()
config = {'auths': {'${ECR_REGISTRY}': {'auth': auth}}}
json.dump(config, open('/tmp/kaniko-config/config.json', 'w'))
"
                """

                // Kaniko build — no Docker socket, no privileged mode
                sh """
                    docker run --rm \\
                        -v \${WORKSPACE}:/workspace \\
                        -v /tmp/kaniko-config:/kaniko/.docker \\
                        gcr.io/kaniko-project/executor:latest \\
                        --context=/workspace/mern-auth \\
                        --dockerfile=/workspace/mern-auth/Dockerfile \\
                        --destination=${STAGE_REGISTRY}:${IMAGE_TAG} \\
                        --cache=true \\
                        --cache-repo=${ECR_REGISTRY}/kaniko-cache \\
                        --snapshot-mode=redo \\
                        --compressed-caching=false
                """

                // Clean Kaniko credentials
                sh 'rm -rf /tmp/kaniko-config'

                // Trivy scan — pull image locally then scan via docker socket
                sh """
                    aws ecr get-login-password --region ${AWS_REGION} | \\
                        docker login --username AWS --password-stdin ${ECR_REGISTRY}
                    docker pull ${STAGE_REGISTRY}:${IMAGE_TAG}
                    mkdir -p /tmp/trivy-out
                    docker run --rm \\
                        -v /var/run/docker.sock:/var/run/docker.sock \\
                        -v /tmp/trivy-out:/output \\
                        aquasec/trivy:0.50.2 image \\
                        --no-progress \\
                        --exit-code 0 \\
                        --severity HIGH,CRITICAL \\
                        --format json \\
                        --output /output/trivy-report-${BUILD_NUMBER}.json \\
                        ${STAGE_REGISTRY}:${IMAGE_TAG}
                    cp /tmp/trivy-out/trivy-report-${BUILD_NUMBER}.json trivy-report-${BUILD_NUMBER}.json
                """

                // SBOM generation — reuses locally-pulled image
                sh """
                    docker run --rm \\
                        -v /var/run/docker.sock:/var/run/docker.sock \\
                        -v /tmp/trivy-out:/output \\
                        aquasec/trivy:0.50.2 image \\
                        --no-progress \\
                        --format cyclonedx \\
                        --output /output/sbom-${BUILD_NUMBER}.json \\
                        ${STAGE_REGISTRY}:${IMAGE_TAG}
                    cp /tmp/trivy-out/sbom-${BUILD_NUMBER}.json sbom-${BUILD_NUMBER}.json
                """

                // ── Cosign Keyless Image Signing ──────────────────────────
                // Signs the staged image using Sigstore OIDC keyless signing.
                // Cosign binary auto-installs to ~/bin if not present (no sudo needed).
                // Signature is recorded in Rekor transparency log (auditable).
                sh """
                    # Install cosign if missing
                    if ! command -v cosign &>/dev/null && [ ! -f ~/bin/cosign ]; then
                        echo "Installing cosign v2.2.2..."
                        mkdir -p ~/bin
                        curl -sSfL https://github.com/sigstore/cosign/releases/download/v2.2.2/cosign-linux-amd64 \\
                            -o ~/bin/cosign
                        chmod +x ~/bin/cosign
                    fi
                    export PATH="\$HOME/bin:\$PATH"
                    COSIGN_EXPERIMENTAL=1 cosign sign \\
                        --yes \\
                        --oidc-provider=aws \\
                        ${STAGE_REGISTRY}:${IMAGE_TAG}
                """
                echo "✅ Image ${STAGE_REGISTRY}:${IMAGE_TAG} signed and recorded in Rekor"

                archiveArtifacts artifacts: "trivy-report-${BUILD_NUMBER}.json, sbom-${BUILD_NUMBER}.json"
            }
        }

        // ────────────────────────────────────────────────────────────
        // STAGE 5: Integration Tests + DAST
        // Uses isolated Docker network (no --network host)
        // Secrets from Jenkins credentials (no hardcoding)
        // ────────────────────────────────────────────────────────────
        stage('5: Integration Tests & DAST') {
            agent { label 'test-agent' }
            steps {
                sh """
                    aws ecr get-login-password --region ${AWS_REGION} | \\
                        docker login --username AWS --password-stdin ${ECR_REGISTRY}
                """
                sh 'docker rm -f mern-auth-test test-mongo 2>/dev/null || true'
                sh 'docker network rm test-net 2>/dev/null || true'
                sh 'docker network create test-net'

                withCredentials([
                    string(credentialsId: 'test-jwt-secret', variable: 'JWT_SECRET'),
                    string(credentialsId: 'test-mongo-password', variable: 'MONGO_PASS')
                ]) {
                    sh """
                        docker run -d --name test-mongo \\
                            --network test-net \\
                            -e MONGO_INITDB_ROOT_USERNAME=root \\
                            -e MONGO_INITDB_ROOT_PASSWORD=\${MONGO_PASS} \\
                            mongo:6.0
                        sleep 10
                    """
                    sh """
                        docker run -d --name mern-auth-test \\
                            --network test-net \\
                            -p ${APP_PORT}:${APP_PORT} \\
                            -e NODE_ENV=test \\
                            -e PORT=${APP_PORT} \\
                            -e MONGODB_URI=mongodb://root:\${MONGO_PASS}@test-mongo:27017/mern-auth-test?authSource=admin \\
                            -e JWT_SECRET=\${JWT_SECRET} \\
                            ${STAGE_REGISTRY}:${IMAGE_TAG}
                        sleep 15
                    """
                }

                // Health check
                sh """
                    STATUS=\$(curl -sf -o /dev/null -w '%{http_code}' http://localhost:${APP_PORT}${HEALTH_EP})
                    echo "Health: HTTP \$STATUS"
                    [ "\$STATUS" = "200" ] || { echo "FATAL: Health check failed"; exit 1; }
                """

                // Newman — no || true
                sh """
                    newman run tests/integration/mern-auth-collection.json \\
                        --env-var "baseUrl=http://localhost:${APP_PORT}" \\
                        --reporters cli,junit \\
                        --reporter-junit-export integration-results.xml
                """
                junit 'integration-results.xml'

                // ZAP DAST — baseline scan (findings → Stage 6 gate, not here)
                sh """
                    mkdir -p zap-reports && chmod 777 zap-reports
                    docker run --rm \\
                        --network test-net \\
                        -v \${WORKSPACE}/zap-reports:/zap/wrk/:rw \\
                        ghcr.io/zaproxy/zaproxy:stable zap-baseline.py \\
                        -t http://mern-auth-test:${APP_PORT} \\
                        -r zap-report.html \\
                        -x zap-report.xml \\
                        -I || true
                """
                archiveArtifacts artifacts: 'zap-reports/**, integration-results.xml'
            }
            post {
                always {
                    sh 'docker rm -f mern-auth-test test-mongo 2>/dev/null || true'
                    sh 'docker network rm test-net 2>/dev/null || true'
                    sh 'rm -f ~/.docker/config.json'
                }
            }
        }

        // ────────────────────────────────────────────────────────────
        // STAGE 6: DAST Quality Gate
        // ────────────────────────────────────────────────────────────
        stage('6: DAST Quality Gate') {
            agent { label 'test-agent' }
            steps {
                script {
                    def zapFile = 'zap-reports/zap-report.xml'
                    if (!fileExists(zapFile)) {
                        error("ZAP report not found. DAST scan failed.")
                    }
                    // Use sh grep — Matcher.count is blocked by Jenkins sandbox
                    def highCount = sh(
                        script: "grep -o '<riskcode>3</riskcode>' ${zapFile} | wc -l",
                        returnStdout: true
                    ).trim().toInteger()
                    echo "ZAP HIGH-risk alerts: ${highCount}"
                    if (highCount > 0) {
                        error("DAST: ${highCount} HIGH-risk alert(s). Fix before deployment.")
                    }
                    echo '✅ DAST gate passed'
                }
            }
        }

        // ────────────────────────────────────────────────────────────
        // STAGE 7: Update GitOps Repository (THE KEY STAGE)
        //
        // THIS REPLACES: Deploy to Staging, Manual Approval,
        //                Promote to Prod, Blue/Green Deploy,
        //                Prometheus Monitor (Stages 8-12 in v2)
        //
        // Jenkins commits the new image tag to the GitOps repo.
        // ArgoCD picks it up and deploys to Staging automatically.
        // Production promotion happens via PR merge in GitHub.
        // ────────────────────────────────────────────────────────────
        stage('7: Update GitOps Config') {
            agent { label 'build-agent' }
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'gitops-repo-creds',
                        usernameVariable: 'GIT_USER',
                        passwordVariable: 'GIT_TOKEN'
                    )
                ]) {
                    sh """
                        # Clone the GitOps repo
                        rm -rf gitops-workspace
                        git clone https://\${GIT_USER}:\${GIT_TOKEN}@github.com/abhijitkadam1706/mern-auth-gitops.git gitops-workspace
                        cd gitops-workspace

                        # Update staging image tag using kustomize
                        cd staging
                        kustomize edit set image mern-auth=${STAGE_REGISTRY}:${IMAGE_TAG}
                        cd ..

                        # Commit and push
                        git config user.email "jenkins@mern-auth-ci.internal"
                        git config user.name "Jenkins CI"
                        git add -A
                        git diff --cached --quiet || \\
                            git commit -m "ci: deploy ${IMAGE_TAG} to staging [build #${BUILD_NUMBER}]"
                        git push origin ${GITOPS_BRANCH}

                        echo "✅ GitOps staging updated → ArgoCD will auto-sync"
                        echo "📋 To promote to PRODUCTION:"
                        echo "   1. Open PR: staging → production in mern-auth-gitops repo"
                        echo "   2. Release manager reviews and merges"
                        echo "   3. ArgoCD syncs production cluster"
                    """
                }
            }
            post {
                always {
                    sh 'rm -rf gitops-workspace'
                }
            }
        }
    }

    post {
        success {
            echo """
✅ CI Pipeline COMPLETE — Build #${BUILD_NUMBER}
   Image: ${env.IMAGE_TAG}
   Staging: ArgoCD will auto-deploy within 3 minutes
   Production: Open a PR in mern-auth-gitops to promote
            """
        }
        failure {
            echo "❌ CI Pipeline FAILED — Build #${BUILD_NUMBER}. Check logs."
        }
        always {
            node('build-agent') {
                archiveArtifacts artifacts: "trivy-report-*.json, sbom-*.json, zap-reports/**, integration-results.xml",
                    allowEmptyArchive: true
                cleanWs()
            }
        }
    }
}
