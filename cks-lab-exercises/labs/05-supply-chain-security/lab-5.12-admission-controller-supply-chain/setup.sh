#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Lab Setup: Admission Controllers for Supply Chain Enforcement ===${NC}"
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

    # Check if Kyverno is installed
    if kubectl get crd clusterpolicies.kyverno.io &> /dev/null; then
        echo -e "${GREEN}✓ Kyverno CRDs found${NC}"
    else
        echo -e "${YELLOW}Warning: Kyverno CRDs not found${NC}"
        echo "Install Kyverno: kubectl create -f https://github.com/kyverno/kyverno/releases/latest/download/install.yaml"
        echo "Some lab tasks require Kyverno for policy enforcement"
    fi

    echo ""
}

create_resources() {
    echo "Creating lab resources..."
    echo ""

    # Create namespace
    kubectl create namespace lab-5-12 --dry-run=client -o yaml | kubectl apply -f - > /dev/null 2>&1
    echo -e "${GREEN}✓ Namespace lab-5-12 ready${NC}"

    # Create a non-compliant deployment to demonstrate the problem
    kubectl apply -f - > /dev/null 2>&1 <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: non-compliant-app
  namespace: lab-5-12
  labels:
    security.supply-chain/compliant: "false"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: non-compliant-app
  template:
    metadata:
      labels:
        app: non-compliant-app
    spec:
      containers:
      - name: app
        image: nginx:latest
        resources:
          limits:
            cpu: "100m"
            memory: "64Mi"
EOF
    echo -e "${GREEN}✓ Reference non-compliant deployment created${NC}"

    # Create lab instructions
    kubectl apply -f - > /dev/null 2>&1 <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: lab-instructions
  namespace: lab-5-12
data:
  task: |
    Your task is to:
    1. Create ConfigMap 'supply-chain-config' with enforcement settings
    2. Create ClusterPolicy 'supply-chain-validate' with multiple validation rules
    3. Create ClusterPolicy 'supply-chain-mutate' with mutation rules
    4. Create Deployment 'compliant-app' that passes all supply chain checks
  admission-controller-types: |
    Validating Admission Webhook: Validates and can reject resources
    Mutating Admission Webhook: Modifies resources before storage
    Order: Mutating runs BEFORE Validating
EOF
    echo -e "${GREEN}✓ Lab instructions ConfigMap created${NC}"

    echo ""
}

check_prerequisites
create_resources

echo ""
echo -e "${GREEN}✓ Lab setup complete${NC}"
echo "Resources created in namespace: lab-5-12"
echo ""
echo -e "${YELLOW}Your task:${NC}"
echo "1. Create ConfigMap 'supply-chain-config'"
echo "2. Create ClusterPolicy 'supply-chain-validate' with validation rules"
echo "3. Create ClusterPolicy 'supply-chain-mutate' with mutation rules"
echo "4. Create Deployment 'compliant-app' passing all checks"
echo ""
kubectl get all -n lab-5-12 2>/dev/null || true
