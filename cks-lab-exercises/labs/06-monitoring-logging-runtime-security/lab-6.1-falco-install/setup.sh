#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}=== Lab Setup: Cài đặt Falco ===${NC}"
echo ""

# Check prerequisites
check_prerequisites() {
    echo "Checking prerequisites..."
    echo ""

    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}Error: kubectl not found${NC}"
        echo "Install kubectl: https://kubernetes.io/docs/tasks/tools/"
        exit 1
    fi
    echo -e "${GREEN}✓ kubectl found${NC}"

    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        echo -e "${RED}Error: Cannot connect to Kubernetes cluster${NC}"
        echo "Make sure your kubeconfig is configured correctly"
        exit 1
    fi
    echo -e "${GREEN}✓ Connected to Kubernetes cluster${NC}"

    # Check falco
    if ! command -v falco &> /dev/null; then
        echo -e "${YELLOW}Warning: falco not found${NC}"
        echo "Install falco: https://falco.org/docs/getting-started/installation/"
        echo "This lab requires this tool to complete"
        exit 1
    fi
    echo -e "${GREEN}✓ falco found${NC}"

    echo ""
}

# Create resources
create_resources() {
    echo "Creating lab resources..."
    echo ""

    # Create namespace
    kubectl create namespace lab-6-1 --dry-run=client -o yaml | kubectl apply -f - > /dev/null 2>&1
    echo -e "${GREEN}✓ Namespace lab-6-1 ready${NC}"

    # Execute setup commands
    # Execute command
    helm repo add falcosecurity https://falcosecurity.github.io/charts > /dev/null 2>&1 || true

    # Execute command
    helm repo update > /dev/null 2>&1 || true

    # Execute command
    helm install falco falcosecurity/falco \ > /dev/null 2>&1 || true

    echo ""
}

# Main execution
check_prerequisites
create_resources

echo ""
echo -e "${GREEN}✓ Lab setup complete${NC}"
echo "Resources created in namespace: lab-6-1"
kubectl get all -n lab-6-1 2>/dev/null || true
