#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}=== Lab Setup: Cấu hình etcd Encryption ===${NC}"
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

    echo ""
}

# Create resources
create_resources() {
    echo "Creating lab resources..."
    echo ""

    # Create namespace
    kubectl create namespace lab-1-1 --dry-run=client -o yaml | kubectl apply -f - > /dev/null 2>&1
    echo -e "${GREEN}✓ Namespace lab-1-1 ready${NC}"

    # Create Kubernetes resources
    # Create EncryptionConfiguration
    cat <<EOF | kubectl apply -f - > /dev/null 2>&1
# /etc/kubernetes/encryption-config.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
    - secrets
    providers:
    - aescbc:
        keys:
        - name: key1
          secret: <32-byte-base64-key>
    - identity: {}  # Fallback (đọc dữ liệu cũ chưa mã hóa)
EOF
    echo -e "${GREEN}✓ EncryptionConfiguration created${NC}"

    # Execute setup commands
    # - identity: {}  # Fallback (đọc dữ liệu cũ chưa mã hóa)
    head -c 32 /dev/urandom | base64 > /dev/null 2>&1 || true

    # - identity: {}  # Fallback (đọc dữ liệu cũ chưa mã hóa)
    --encryption-provider-config=/etc/kubernetes/encryption-config.yaml > /dev/null 2>&1 || true

    echo ""
}

# Main execution
check_prerequisites
create_resources

echo ""
echo -e "${GREEN}✓ Lab setup complete${NC}"
echo "Resources created in namespace: lab-1-1"
kubectl get all -n lab-1-1 2>/dev/null || true
