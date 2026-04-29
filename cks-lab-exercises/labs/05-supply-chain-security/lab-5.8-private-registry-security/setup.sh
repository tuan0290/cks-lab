#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Lab Setup: Private Registry Security ===${NC}"
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

    echo ""
}

create_resources() {
    echo "Creating lab resources..."
    echo ""

    # Create namespace
    kubectl create namespace lab-5-8 --dry-run=client -o yaml | kubectl apply -f - > /dev/null 2>&1
    echo -e "${GREEN}✓ Namespace lab-5-8 ready${NC}"

    # Create lab instructions
    kubectl apply -f - > /dev/null 2>&1 <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: lab-instructions
  namespace: lab-5-8
data:
  task: |
    Your task is to:
    1. Create imagePullSecret 'registry-credentials' for registry.example.com
    2. Patch default ServiceAccount to use registry-credentials
    3. Create ClusterPolicy 'restrict-image-registries' to limit image sources
    4. Create Deployment 'private-registry-app' with imagePullSecrets
    5. Create ServiceAccount 'app-service-account' with imagePullSecrets
EOF
    echo -e "${GREEN}✓ Lab instructions ConfigMap created${NC}"

    echo ""
}

check_prerequisites
create_resources

echo ""
echo -e "${GREEN}✓ Lab setup complete${NC}"
echo "Resources created in namespace: lab-5-8"
echo ""
echo -e "${YELLOW}Your task:${NC}"
echo "1. Create imagePullSecret 'registry-credentials' for registry.example.com"
echo "2. Patch default ServiceAccount with imagePullSecrets"
echo "3. Create ClusterPolicy 'restrict-image-registries'"
echo "4. Create Deployment 'private-registry-app' with imagePullSecrets"
echo "5. Create ServiceAccount 'app-service-account' with imagePullSecrets"
echo ""
kubectl get all -n lab-5-8 2>/dev/null || true
