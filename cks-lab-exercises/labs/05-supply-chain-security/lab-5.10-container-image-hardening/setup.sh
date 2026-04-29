#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Lab Setup: Container Image Hardening ===${NC}"
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
        echo -e "${YELLOW}Warning: trivy not found (optional for this lab)${NC}"
        echo "Install trivy: https://aquasecurity.github.io/trivy/latest/getting-started/installation/"
    else
        echo -e "${GREEN}✓ trivy found${NC}"
    fi

    echo ""
}

create_resources() {
    echo "Creating lab resources..."
    echo ""

    # Create namespace with baseline PSS (setup creates it without restricted to allow initial resources)
    kubectl apply -f - > /dev/null 2>&1 <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: lab-5-10
  labels:
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/warn-version: latest
EOF
    echo -e "${GREEN}✓ Namespace lab-5-10 ready (with PSS warn mode)${NC}"

    # Create a reference unhardened deployment to demonstrate the problem
    kubectl apply -f - > /dev/null 2>&1 <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: unhardened-app
  namespace: lab-5-10
  labels:
    security.hardened: "false"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: unhardened-app
  template:
    metadata:
      labels:
        app: unhardened-app
    spec:
      containers:
      - name: app
        image: nginx:1.25
        resources:
          limits:
            cpu: "100m"
            memory: "64Mi"
EOF
    echo -e "${GREEN}✓ Reference unhardened deployment created${NC}"

    # Create lab instructions
    kubectl apply -f - > /dev/null 2>&1 <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: lab-instructions
  namespace: lab-5-10
data:
  task: |
    Your task is to:
    1. Update namespace lab-5-10 with restricted PSS enforcement labels
    2. Create ConfigMap 'hardening-checklist' with security requirements
    3. Create Deployment 'hardened-app' with all security hardening applied
    4. Create ClusterPolicy 'enforce-container-hardening' with validation rules
EOF
    echo -e "${GREEN}✓ Lab instructions ConfigMap created${NC}"

    echo ""
}

check_prerequisites
create_resources

echo ""
echo -e "${GREEN}✓ Lab setup complete${NC}"
echo "Resources created in namespace: lab-5-10"
echo ""
echo -e "${YELLOW}Your task:${NC}"
echo "1. Add restricted PSS labels to namespace lab-5-10"
echo "2. Create ConfigMap 'hardening-checklist'"
echo "3. Create Deployment 'hardened-app' with full security hardening"
echo "4. Create ClusterPolicy 'enforce-container-hardening'"
echo ""
kubectl get all -n lab-5-10 2>/dev/null || true
