#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Lab Setup: Supply Chain Attestation with In-toto and SLSA ===${NC}"
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
        echo "Some lab tasks require cosign for attestation signing"
    else
        echo -e "${GREEN}✓ cosign found${NC}"
    fi

    echo ""
}

create_resources() {
    echo "Creating lab resources..."
    echo ""

    # Create namespace
    kubectl create namespace lab-5-9 --dry-run=client -o yaml | kubectl apply -f - > /dev/null 2>&1
    echo -e "${GREEN}✓ Namespace lab-5-9 ready${NC}"

    # Create lab instructions
    kubectl apply -f - > /dev/null 2>&1 <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: lab-instructions
  namespace: lab-5-9
data:
  task: |
    Your task is to:
    1. Generate a Cosign key pair with 'cosign generate-key-pair'
    2. Create ConfigMap 'slsa-policy-config' with SLSA settings
    3. Create ConfigMap 'intoto-attestation-example' with attestation structure
    4. Create ClusterPolicy 'verify-slsa-attestation' with attestation verification
    5. Create Deployment 'attested-app' with SLSA compliance annotations
  slsa-levels: |
    SLSA Level 1: Build process is documented
    SLSA Level 2: Build process is hosted and generates provenance
    SLSA Level 3: Build process is hardened and provenance is non-falsifiable
    SLSA Level 4: Two-party review of all changes
EOF
    echo -e "${GREEN}✓ Lab instructions ConfigMap created${NC}"

    echo ""
}

check_prerequisites
create_resources

echo ""
echo -e "${GREEN}✓ Lab setup complete${NC}"
echo "Resources created in namespace: lab-5-9"
echo ""
echo -e "${YELLOW}Your task:${NC}"
echo "1. Generate Cosign key pair: cosign generate-key-pair"
echo "2. Create ConfigMap 'slsa-policy-config' with SLSA settings"
echo "3. Create ConfigMap 'intoto-attestation-example' with attestation JSON"
echo "4. Create ClusterPolicy 'verify-slsa-attestation'"
echo "5. Create Deployment 'attested-app' with SLSA annotations"
echo ""
kubectl get all -n lab-5-9 2>/dev/null || true
