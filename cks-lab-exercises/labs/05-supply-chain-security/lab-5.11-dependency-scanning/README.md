# Lab 5.11: Dependency Scanning with Trivy

## Metadata
- **Domain**: 5 - Supply Chain Security
- **Difficulty**: Medium
- **Estimated Time**: 20 minutes
- **Exam Weight**: 20%

## Learning Objectives
- Use Trivy to scan container images for vulnerabilities
- Scan Kubernetes manifests and configurations for misconfigurations
- Interpret Trivy scan results and understand severity levels
- Configure Trivy to scan running cluster workloads
- Create policies based on scan findings

## Prerequisites
- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- trivy installed (`https://aquasecurity.github.io/trivy/`)

## Scenario

Your security team requires all container images to be scanned for vulnerabilities before deployment, and all Kubernetes configurations to be checked for misconfigurations. You need to set up a scanning workflow using Trivy that covers both image vulnerabilities and Kubernetes configuration issues, and document the findings in a structured way.

## Requirements

1. Create a namespace `lab-5-11` for this lab
2. Run Trivy to scan a container image and save results to a ConfigMap `scan-results`
3. Create a Job `trivy-scanner` that performs image scanning in-cluster
4. Create a ConfigMap `scan-policy` defining acceptable vulnerability thresholds
5. Create a deployment `scanned-app` with scan result annotations
6. Demonstrate scanning a Kubernetes manifest for misconfigurations

## Instructions

### Step 1: Set up the lab environment

```bash
./setup.sh
```

### Step 2: Scan an image with Trivy (if trivy is installed locally)

```bash
# Basic image scan
trivy image nginx:1.25

# Scan with specific severity filter
trivy image --severity HIGH,CRITICAL nginx:1.25

# Scan with JSON output
trivy image --format json --output /tmp/scan-results.json nginx:1.25

# Scan and fail on CRITICAL vulnerabilities
trivy image --severity CRITICAL --exit-code 1 nginx:1.25 || echo "CRITICAL vulnerabilities found"

# Scan a Kubernetes manifest for misconfigurations
trivy config --severity HIGH,CRITICAL deployment.yaml
```

### Step 3: Create the scan policy ConfigMap

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: scan-policy
  namespace: lab-5-11
data:
  max-critical: "0"
  max-high: "5"
  max-medium: "20"
  scan-tool: "trivy"
  scan-frequency: "daily"
  block-on-critical: "true"
  block-on-high: "false"
  scan-targets: "image,config,filesystem"
EOF
```

### Step 4: Create a scan results ConfigMap

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: scan-results
  namespace: lab-5-11
  annotations:
    security.scan/tool: "trivy"
    security.scan/date: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    security.scan/image: "nginx:1.25"
data:
  summary: |
    Image: nginx:1.25
    Scan Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)
    Tool: Trivy
    Status: PASSED
    Critical: 0
    High: 2
    Medium: 8
    Low: 15
  policy-result: "PASSED - No CRITICAL vulnerabilities found"
EOF
```

### Step 5: Create a Trivy scanner Job

```bash
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: trivy-scanner
  namespace: lab-5-11
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: trivy
        image: aquasec/trivy:latest
        command:
        - trivy
        - image
        - --severity
        - HIGH,CRITICAL
        - --format
        - table
        - --exit-code
        - "0"
        - nginx:1.25
        resources:
          limits:
            cpu: "500m"
            memory: "256Mi"
EOF
```

### Step 6: Deploy the scanned application

```bash
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scanned-app
  namespace: lab-5-11
  annotations:
    security.scan/tool: "trivy"
    security.scan/status: "passed"
    security.scan/critical-count: "0"
    security.scan/high-count: "2"
    security.scan/date: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: scanned-app
  template:
    metadata:
      labels:
        app: scanned-app
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 101
      containers:
      - name: app
        image: nginx:1.25
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
            add:
            - NET_BIND_SERVICE
        ports:
        - containerPort: 80
        resources:
          limits:
            cpu: "100m"
            memory: "64Mi"
EOF
```

### Step 7: Verify your solution

```bash
./verify.sh
```

## Verification

```bash
./verify.sh
```

## Cleanup

```bash
./cleanup.sh
```

## Key Concepts

- **Trivy scan targets**: `image`, `filesystem`, `config`, `repo`, `sbom`
- **Severity levels**: UNKNOWN, LOW, MEDIUM, HIGH, CRITICAL
- **Exit codes**: `--exit-code 1` makes Trivy fail if vulnerabilities found (useful in CI/CD)
- **Trivy config scanning**: Detects Kubernetes misconfigurations (privileged containers, missing resource limits, etc.)
- **Trivy SBOM**: Can generate and scan SBOMs

## Additional Resources

- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [Trivy Kubernetes Scanning](https://aquasecurity.github.io/trivy/latest/docs/target/kubernetes/)
- [CVE Database](https://cve.mitre.org/)
- [CKS Exam Curriculum](https://github.com/cncf/curriculum)
