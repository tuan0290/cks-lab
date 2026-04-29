#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Lab Setup: Runtime Immutability ===${NC}"
echo ""

check_prerequisites() {
    echo "Checking prerequisites..."
    echo ""

    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}Error: kubectl not found${NC}"
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
    kubectl create namespace lab-6-12 --dry-run=client -o yaml | kubectl apply -f - > /dev/null 2>&1
    echo -e "${GREEN}✓ Namespace lab-6-12 ready${NC}"

    # Create a mutable pod for comparison
    kubectl apply -f - > /dev/null 2>&1 <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: mutable-pod
  namespace: lab-6-12
  labels:
    app: mutable-app
spec:
  containers:
  - name: app
    image: busybox:1.35
    command: ["sleep", "3600"]
  restartPolicy: Never
EOF
    echo -e "${GREEN}✓ Mutable comparison pod created${NC}"

    # Create falco namespace
    kubectl create namespace falco --dry-run=client -o yaml | kubectl apply -f - > /dev/null 2>&1
    echo -e "${GREEN}✓ Falco namespace ready${NC}"

    echo ""
}

# Main execution
check_prerequisites
create_resources

echo ""
echo -e "${GREEN}✓ Lab setup complete${NC}"
echo ""
echo "Resources created:"
kubectl get pods -n lab-6-12 2>/dev/null || true
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Create the immutable-pod with readOnlyRootFilesystem: true"
echo "2. Test that writes to root filesystem are blocked"
echo "3. Test that writes to /tmp (emptyDir) succeed"
echo "4. Create the immutable-deployment"
echo "5. Deploy Falco rules for filesystem write detection"
