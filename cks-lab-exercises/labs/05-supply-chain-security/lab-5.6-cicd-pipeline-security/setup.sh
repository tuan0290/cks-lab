#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Lab Setup: CI/CD Pipeline Security ===${NC}"
echo ""

check_prerequisites() {
    echo "Checking prerequisites..."
    echo ""

    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}Error: kubectl not found${NC}"
        echo "Install kubectl: https://kubernetes.io/docs/tasks/tools/"
        exit 1
    fi
    echo -e "${GREEN}✓ kubectl found${NC}"

    if ! kubectl cluster-info &> /dev/null; then
        echo -e "${RED}Error: Cannot connect to Kubernetes cluster${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Connected to Kubernetes cluster${NC}"

    if ! command -v trivy &> /dev/null; then
        echo -e "${YELLOW}Warning: trivy not found${NC}"
        echo "Install trivy: https://aquasecurity.github.io/trivy/latest/getting-started/installation/"
        echo "Some lab tasks require trivy for image scanning"
    else
        echo -e "${GREEN}✓ trivy found${NC}"
    fi

    echo ""
}

create_resources() {
    echo "Creating lab resources..."
    echo ""

    # Create namespace
    kubectl create namespace lab-5-6 --dry-run=client -o yaml | kubectl apply -f - > /dev/null 2>&1
    echo -e "${GREEN}✓ Namespace lab-5-6 ready${NC}"

    # Create a vulnerable deployment to demonstrate the problem
    kubectl apply -f - > /dev/null 2>&1 <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: unscanned-app
  namespace: lab-5-6
  labels:
    security.scan/status: "not-scanned"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: unscanned-app
  template:
    metadata:
      labels:
        app: unscanned-app
    spec:
      containers:
      - name: app
        image: nginx:1.25
        resources:
          limits:
            cpu: "100m"
            memory: "64Mi"
EOF
    echo -e "${GREEN}✓ Reference unscanned deployment created${NC}"

    # Create lab instructions
    kubectl apply -f - > /dev/null 2>&1 <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: lab-instructions
  namespace: lab-5-6
data:
  task: |
    Your task is to:
    1. Create ServiceAccount 'cicd-deployer' with least-privilege RBAC
    2. Create Role 'cicd-deployer-role' with minimal deployment permissions
    3. Create RoleBinding 'cicd-deployer-binding'
    4. Create ConfigMap 'pipeline-config' with scan thresholds
    5. Create Job 'image-scanner' that runs trivy scan
    6. Create Deployment 'pipeline-app' with scan annotations
EOF
    echo -e "${GREEN}✓ Lab instructions ConfigMap created${NC}"

    echo ""
}

check_prerequisites
create_resources

echo ""
echo -e "${GREEN}✓ Lab setup complete${NC}"
echo "Resources created in namespace: lab-5-6"
echo ""
echo -e "${YELLOW}Your task:${NC}"
echo "1. Create ServiceAccount 'cicd-deployer' with least-privilege RBAC"
echo "2. Create ConfigMap 'pipeline-config' with scanning thresholds"
echo "3. Create Job 'image-scanner' that simulates pipeline scanning"
echo "4. Deploy 'pipeline-app' with scan status annotations"
echo ""
kubectl get all -n lab-5-6 2>/dev/null || true
