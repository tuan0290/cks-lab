#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Lab Setup: Ingress TLS Configuration ===${NC}"
echo ""

check_prerequisites() {
    echo "Checking prerequisites..."
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}Error: kubectl not found${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ kubectl found${NC}"

    if ! kubectl cluster-info &> /dev/null; then
        echo -e "${RED}Error: Cannot connect to Kubernetes cluster${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Cluster connectivity verified${NC}"

    if ! command -v openssl &> /dev/null; then
        echo -e "${YELLOW}Warning: openssl not found - you will need it to generate TLS certificates${NC}"
    else
        echo -e "${GREEN}✓ openssl found${NC}"
    fi
}

create_resources() {
    echo ""
    echo "Creating lab resources..."
    kubectl create namespace lab-1-5 --dry-run=client -o yaml | kubectl apply -f -
    echo -e "${GREEN}✓ Namespace lab-1-5 created${NC}"
}

check_prerequisites
create_resources

echo ""
echo -e "${GREEN}✓ Lab setup complete${NC}"
echo "Namespace created:"
kubectl get namespace lab-1-5
