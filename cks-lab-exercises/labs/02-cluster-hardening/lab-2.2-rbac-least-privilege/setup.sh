#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}=== Lab Setup: RBAC - Nguyên tắc Tối Thiểu Đặc Quyền ===${NC}"
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
    kubectl create namespace lab-2-2 --dry-run=client -o yaml | kubectl apply -f - > /dev/null 2>&1
    echo -e "${GREEN}✓ Namespace lab-2-2 ready${NC}"

    # Create Kubernetes resources
    # Create Unknown
    cat <<EOF | kubectl apply -f - > /dev/null 2>&1
# Tạo ServiceAccount với quyền tối thiểu (chỉ đọc deployment)
apiVersion: v1
kind: ServiceAccount
metadata:
  name: deployment-reader
  namespace: production
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: deployment-reader-role
  namespace: production
rules:
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: deployment-reader-binding
  namespace: production
subjects:
- kind: ServiceAccount
  name: deployment-reader
  namespace: production
roleRef:
  kind: Role
  name: deployment-reader-role
  apiGroup: rbac.authorization.k8s.io
---
# Pod sử dụng SA với quyền tối thiểu
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
  namespace: production
spec:
  serviceAccountName: deployment-reader
  automountServiceAccountToken: true  # hoặc false nếu không cần
EOF
    echo -e "${GREEN}✓ Unknown created${NC}"

    # Execute setup commands
    # automountServiceAccountToken: true  # hoặc false nếu không cần
    kubectl auth can-i get secrets --all-namespaces > /dev/null 2>&1 || true

    echo ""
}

# Main execution
check_prerequisites
create_resources

echo ""
echo -e "${GREEN}✓ Lab setup complete${NC}"
echo "Resources created in namespace: lab-2-2"
kubectl get all -n lab-2-2 2>/dev/null || true
