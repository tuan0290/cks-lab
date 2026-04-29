# Lab 5.6: CI/CD Pipeline Security

## Metadata
- **Domain**: 5 - Supply Chain Security
- **Difficulty**: Hard
- **Estimated Time**: 25 minutes
- **Exam Weight**: 20%

## Learning Objectives
- Understand security risks in CI/CD pipelines
- Configure Kubernetes resources to simulate a secure CI/CD pipeline
- Implement image scanning as a gate in the deployment process
- Use Trivy to scan images before deployment
- Apply least-privilege RBAC for CI/CD service accounts

## Prerequisites
- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- trivy installed (`https://aquasecurity.github.io/trivy/`)
- Basic understanding of CI/CD concepts

## Scenario

Your organization uses Kubernetes for deployments triggered by a CI/CD pipeline. The security team has found that images are being deployed without vulnerability scanning, and the CI/CD service account has excessive permissions. You need to:
1. Create a restricted CI/CD service account with least-privilege RBAC
2. Simulate a pipeline that scans images with Trivy before deployment
3. Configure a policy that blocks deployment of images with CRITICAL vulnerabilities
4. Demonstrate the scanning gate by testing with both clean and vulnerable images

## Requirements

1. Create a namespace `cicd-pipeline` for CI/CD operations
2. Create a ServiceAccount `cicd-deployer` with least-privilege RBAC (only deploy to `lab-5-6` namespace)
3. Create a ConfigMap `pipeline-config` with scanning thresholds (CRITICAL severity blocks deployment)
4. Run a Trivy scan on `nginx:1.25` image and save results to a ConfigMap
5. Create a Job `image-scanner` that simulates the scanning step in a pipeline
6. Deploy an application only after the scan passes (no CRITICAL vulnerabilities)

## Instructions

### Step 1: Set up the lab environment

```bash
./setup.sh
```

### Step 2: Create the CI/CD service account with least-privilege RBAC

```bash
# Create the service account
kubectl create serviceaccount cicd-deployer -n lab-5-6 --dry-run=client -o yaml | kubectl apply -f -

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
  kind: Role
  apiRef: rbac.authorization.k8s.io
  name: cicd-deployer-role
EOF
```

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

### Step 4: Run Trivy scan and create a Job to simulate the pipeline

```bash
# Scan the image locally (if trivy is available)
trivy image --severity CRITICAL --exit-code 1 nginx:1.25 || echo "Vulnerabilities found"

# Create a Job that simulates the scanning step
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

### Step 5: Deploy the application after scan approval

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
          readOnlyRootFilesystem: false
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

### Step 6: Verify your solution

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

- **Least-privilege RBAC**: CI/CD service accounts should only have permissions needed for deployment
- **Image scanning gates**: Scan images before deployment and block on critical vulnerabilities
- **Pipeline annotations**: Track security scan status in deployment metadata
- **Trivy severity levels**: UNKNOWN, LOW, MEDIUM, HIGH, CRITICAL

## Additional Resources

- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [Kubernetes RBAC](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [CKS Exam Curriculum](https://github.com/cncf/curriculum)
