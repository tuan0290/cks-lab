#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Lab Setup: Cosign Verification with Kyverno verifyImages ===${NC}"
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

    if ! command -v cosign &> /dev/null; then
        echo -e "${YELLOW}Warning: cosign not found${NC}"
        echo "Install cosign: https://docs.sigstore.dev/cosign/installation/"
        echo "Some lab tasks require cosign for image signing"
    else
        echo -e "${GREEN}✓ cosign found${NC}"
    fi

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
    kubectl create namespace lab-5-7 --dry-run=client -o yaml | kubectl apply -f - > /dev/null 2>&1
    echo -e "${GREEN}✓ Namespace lab-5-7 ready${NC}"

    # Create a placeholder public key ConfigMap (students will replace with real key)
    kubectl apply -f - > /dev/null 2>&1 <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: cosign-key-placeholder
  namespace: lab-5-7
data:
  note: |
    Run 'cosign generate-key-pair' to generate a real key pair.
    Then create the cosign-public-key ConfigMap with the generated cosign.pub file.
    Example: kubectl create configmap cosign-public-key --from-file=cosign.pub=./cosign.pub -n lab-5-7
EOF
    echo -e "${GREEN}✓ Key placeholder ConfigMap created${NC}"

    # Create lab instructions
    kubectl apply -f - > /dev/null 2>&1 <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: lab-instructions
  namespace: lab-5-7
data:
  task: |
    Your task is to:
    1. Generate a Cosign key pair with 'cosign generate-key-pair'
    2. Create ConfigMap 'cosign-public-key' from the generated cosign.pub
    3. Create ClusterPolicy 'verify-image-signatures' with verifyImages rule
    4. Create ClusterPolicy 'audit-image-signatures' in Audit mode
    5. Create Deployment 'verified-app' with cosign verification annotations
EOF
    echo -e "${GREEN}✓ Lab instructions ConfigMap created${NC}"

    echo ""
}

check_prerequisites
create_resources

echo ""
echo -e "${GREEN}✓ Lab setup complete${NC}"
echo "Resources created in namespace: lab-5-7"
echo ""
echo -e "${YELLOW}Your task:${NC}"
echo "1. Generate Cosign key pair: cosign generate-key-pair"
echo "2. Create ConfigMap 'cosign-public-key' from cosign.pub"
echo "3. Create ClusterPolicy 'verify-image-signatures' with verifyImages"
echo "4. Create ClusterPolicy 'audit-image-signatures' in Audit mode"
echo "5. Create Deployment 'verified-app' with security annotations"
echo ""
kubectl get all -n lab-5-7 2>/dev/null || true
