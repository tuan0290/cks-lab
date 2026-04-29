#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}=== Lab Setup: ResourceQuota & LimitRange ===${NC}"
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
    kubectl create namespace lab-4-3 --dry-run=client -o yaml | kubectl apply -f - > /dev/null 2>&1
    echo -e "${GREEN}✓ Namespace lab-4-3 ready${NC}"

    # Create Kubernetes resources
    # Create Unknown
    cat <<EOF | kubectl apply -f - > /dev/null 2>&1
# ResourceQuota — Giới hạn tổng tài nguyên namespace
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-resources
  namespace: production
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    persistentvolumeclaims: "4"
---
# LimitRange — Giới hạn mặc định cho từng Pod/Container
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: production
spec:
  limits:
  - default:          # Limit mặc định nếu không khai báo
      cpu: 500m
      memory: 512Mi
    defaultRequest:   # Request mặc định nếu không khai báo
      cpu: 100m
      memory: 128Mi
    max:              # Giới hạn tối đa
      cpu: "2"
      memory: 4Gi
    min:              # Giới hạn tối thiểu
      cpu: 50m
      memory: 64Mi
    type: Container
EOF
    echo -e "${GREEN}✓ Unknown created${NC}"

    echo ""
}

# Main execution
check_prerequisites
create_resources

echo ""
echo -e "${GREEN}✓ Lab setup complete${NC}"
echo "Resources created in namespace: lab-4-3"
kubectl get all -n lab-4-3 2>/dev/null || true
