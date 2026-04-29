#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Lab Setup: CIS Benchmark with kube-bench ===${NC}"
echo ""

check_prerequisites() {
    echo "Checking prerequisites..."
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
    echo -e "${GREEN}✓ Cluster connectivity verified${NC}"
}

create_resources() {
    echo ""
    echo "Creating lab resources..."

    kubectl create namespace lab-1-4 --dry-run=client -o yaml | kubectl apply -f -
    kubectl label namespace lab-1-4 security=cis-benchmark --overwrite

    echo -e "${GREEN}✓ Namespace lab-1-4 created with label security=cis-benchmark${NC}"
}

check_prerequisites
create_resources

echo ""
echo -e "${GREEN}✓ Lab setup complete${NC}"
echo "Resources created:"
kubectl get namespace lab-1-4 --show-labels
