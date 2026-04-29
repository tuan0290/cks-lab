#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}=== Lab Setup: Cấu hình Audit Log ===${NC}"
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
    kubectl create namespace lab-2-3 --dry-run=client -o yaml | kubectl apply -f - > /dev/null 2>&1
    echo -e "${GREEN}✓ Namespace lab-2-3 ready${NC}"

    # Create Kubernetes resources
    # Create Policy
    cat <<EOF | kubectl apply -f - > /dev/null 2>&1
# /etc/kubernetes/audit-policy.yaml
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
  - RequestReceived
rules:
  # Ghi log đầy đủ khi tạo/sửa/xóa Secret
  - level: RequestResponse
    verbs: ["create", "update", "delete", "patch"]
    resources:
    - group: ""
      resources: ["secrets"]

  # Ghi metadata khi đọc Secret
  - level: Request
    verbs: ["get", "list"]
    resources:
    - group: ""
      resources: ["secrets"]

  # Ghi log đầy đủ cho Deployment/StatefulSet
  - level: RequestResponse
    verbs: ["create", "update", "delete", "patch"]
    resources:
    - group: "apps"
      resources: ["deployments", "statefulsets", "daemonsets"]
    - group: "batch"
      resources: ["jobs", "cronjobs"]

  # Metadata cho tất cả resource còn lại
  - level: Metadata
    verbs: ["*"]
    resources:
    - group: ""
      resources: ["*"]
    omitStages:
    - RequestReceived

  # Không ghi log node get/list events (giảm noise)
  - level: None
    userGroups: ["system:nodes"]
    verbs: ["get", "list"]
    resources:
    - group: ""
      resources: ["events", "nodes"]

  # Ghi log anonymous requests
  - level: Request
    userGroups: ["system:unauthenticated"]
    resources:
    - group: ""
      resources: ["*"]
EOF
    echo -e "${GREEN}✓ Policy created${NC}"

    # Execute setup commands
    # resources: ["*"]
    --audit-log-path=/var/log/kubernetes/audit.log > /dev/null 2>&1 || true

    # resources: ["*"]
    --audit-policy-file=/etc/kubernetes/audit-policy.yaml > /dev/null 2>&1 || true

    # resources: ["*"]
    --audit-log-maxage=30 > /dev/null 2>&1 || true

    echo ""
}

# Main execution
check_prerequisites
create_resources

echo ""
echo -e "${GREEN}✓ Lab setup complete${NC}"
echo "Resources created in namespace: lab-2-3"
kubectl get all -n lab-2-3 2>/dev/null || true
