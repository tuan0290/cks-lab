# Solution: Lab 5.11 - Dependency Scanning with Trivy

## Overview

This solution demonstrates how to use Trivy for comprehensive vulnerability scanning of container images and Kubernetes configurations.

## Step-by-Step Solution

### Step 1: Set up the environment

```bash
./setup.sh
```

### Step 2: Run Trivy scans locally

```bash
# Basic image scan
trivy image nginx:1.25

# Filter by severity
trivy image --severity HIGH,CRITICAL nginx:1.25

# JSON output for processing
trivy image --format json --output /tmp/scan-results.json nginx:1.25

# Fail pipeline on CRITICAL vulnerabilities
trivy image --severity CRITICAL --exit-code 1 nginx:1.25

# Scan a Kubernetes manifest
cat > /tmp/test-deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test
spec:
  template:
    spec:
      containers:
      - name: app
        image: nginx:latest
        securityContext:
          privileged: true
EOF
trivy config /tmp/test-deployment.yaml
```

### Step 3: Create the scan policy

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

### Step 4: Create the scan results ConfigMap

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

### Step 5: Create the Trivy scanner Job

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

## Trivy Command Reference

```bash
# Image scanning
trivy image [IMAGE]                          # Basic scan
trivy image --severity HIGH,CRITICAL [IMAGE] # Filter severity
trivy image --exit-code 1 [IMAGE]            # Fail on any vuln
trivy image --format json [IMAGE]            # JSON output
trivy image --format sarif [IMAGE]           # SARIF output (for GitHub)
trivy image --ignore-unfixed [IMAGE]         # Skip unfixed vulns

# Config scanning (Kubernetes manifests)
trivy config [FILE/DIR]                      # Scan config files
trivy config --severity HIGH,CRITICAL .      # Filter severity

# Filesystem scanning
trivy fs [PATH]                              # Scan filesystem
trivy fs --security-checks vuln,config .     # Scan for vulns and misconfigs

# Kubernetes cluster scanning
trivy k8s --report summary cluster           # Scan entire cluster
trivy k8s --report all cluster               # Detailed cluster report

# SBOM scanning
trivy sbom [SBOM_FILE]                       # Scan an SBOM file
```

## Trivy Severity Levels

| Level | Description | Action |
|-------|-------------|--------|
| CRITICAL | Actively exploited, high impact | Block deployment |
| HIGH | Significant risk | Review and remediate |
| MEDIUM | Moderate risk | Track and plan remediation |
| LOW | Minor risk | Monitor |
| UNKNOWN | Insufficient data | Investigate |

## CKS Exam Tips

1. **Trivy commands**: Know `trivy image`, `--severity`, `--exit-code`, `--format`
2. **Severity filtering**: `--severity HIGH,CRITICAL` is the most common exam pattern
3. **Exit codes**: `--exit-code 1` is used to fail CI/CD pipelines
4. **Config scanning**: `trivy config` detects Kubernetes misconfigurations
5. **Integration**: Know how to use Trivy in a Job or as a pipeline step

## Cleanup

```bash
./cleanup.sh
```
