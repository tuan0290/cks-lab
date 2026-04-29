# Solution: Lab 5.6 - CI/CD Pipeline Security

## Overview

This solution demonstrates how to secure a CI/CD pipeline by implementing least-privilege RBAC for the deployer service account and integrating image scanning as a deployment gate.

## Step-by-Step Solution

### Step 1: Set up the environment

```bash
./setup.sh
```

### Step 2: Create the CI/CD service account with least-privilege RBAC

```bash
# Create the service account
kubectl create serviceaccount cicd-deployer -n lab-5-6

# Create a Role with minimal permissions
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: cicd-deployer-role
  namespace: lab-5-6
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "create", "update", "patch"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list", "create", "update"]
EOF

# Bind the role to the service account
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: cicd-deployer-binding
  namespace: lab-5-6
subjects:
- kind: ServiceAccount
  name: cicd-deployer
  namespace: lab-5-6
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: cicd-deployer-role
EOF
```

**Why least-privilege matters:**
- The CI/CD service account should ONLY be able to deploy to its designated namespace
- It should NOT have cluster-admin or wildcard permissions
- Compromised CI/CD credentials should have minimal blast radius

### Step 3: Create the pipeline configuration

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: pipeline-config
  namespace: lab-5-6
data:
  scan-severity-threshold: "CRITICAL"
  block-on-critical: "true"
  block-on-high: "false"
  allowed-registries: "docker.io,gcr.io,registry.k8s.io"
  scan-tool: "trivy"
EOF
```

### Step 4: Create the image scanner Job

```bash
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: image-scanner
  namespace: lab-5-6
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: scanner
        image: aquasec/trivy:latest
        command:
        - trivy
        - image
        - --severity
        - CRITICAL,HIGH
        - --exit-code
        - "0"
        - --format
        - json
        - --output
        - /tmp/scan-results.json
        - nginx:1.25
        volumeMounts:
        - name: results
          mountPath: /tmp
      volumes:
      - name: results
        emptyDir: {}
EOF
```

### Step 5: Deploy the application with scan annotations

```bash
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pipeline-app
  namespace: lab-5-6
  annotations:
    security.scan/tool: "trivy"
    security.scan/status: "passed"
    security.scan/severity-threshold: "CRITICAL"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: pipeline-app
  template:
    metadata:
      labels:
        app: pipeline-app
    spec:
      serviceAccountName: cicd-deployer
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

### Step 6: Verify the solution

```bash
./verify.sh
```

## Running Trivy Locally

If trivy is installed, you can scan images directly:

```bash
# Scan for CRITICAL vulnerabilities only
trivy image --severity CRITICAL nginx:1.25

# Scan and fail if CRITICAL vulnerabilities found
trivy image --severity CRITICAL --exit-code 1 nginx:1.25

# Scan with JSON output
trivy image --format json --output scan-results.json nginx:1.25

# Scan filesystem
trivy fs --severity HIGH,CRITICAL /path/to/project
```

## CI/CD Security Best Practices

### 1. Least-Privilege Service Accounts
```yaml
# BAD - too permissive
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]

# GOOD - minimal permissions
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "create", "update", "patch"]
```

### 2. Image Scanning Gates
```bash
# In your CI/CD pipeline script:
trivy image --severity CRITICAL --exit-code 1 $IMAGE_NAME
if [ $? -ne 0 ]; then
  echo "CRITICAL vulnerabilities found. Blocking deployment."
  exit 1
fi
kubectl apply -f deployment.yaml
```

### 3. Signed Images Only
```bash
# Verify image signature before deployment
cosign verify --key cosign.pub $IMAGE_NAME
```

### 4. Immutable Tags
```yaml
# BAD - mutable tag
image: myapp:latest

# GOOD - immutable digest
image: myapp@sha256:abc123...
```

## CKS Exam Tips

1. **RBAC for CI/CD**: Know how to create minimal Roles and RoleBindings
2. **Trivy commands**: `trivy image`, `--severity`, `--exit-code`
3. **Annotations**: Use annotations to track security scan status
4. **Service account scoping**: Namespace-scoped vs cluster-scoped permissions

## Cleanup

```bash
./cleanup.sh
```
