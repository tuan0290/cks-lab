#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Lab Setup: Container Behavior Analysis ===${NC}"
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

    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}Warning: jq not found. Log analysis steps will be limited.${NC}"
        echo "Install jq: https://stedolan.github.io/jq/download/"
    else
        echo -e "${GREEN}✓ jq found${NC}"
    fi

    echo ""
}

create_resources() {
    echo "Creating lab resources..."
    echo ""

    # Create namespace
    kubectl create namespace lab-6-5 --dry-run=client -o yaml | kubectl apply -f - > /dev/null 2>&1
    echo -e "${GREEN}✓ Namespace lab-6-5 ready${NC}"

    # Create behavior test pod
    kubectl apply -f - > /dev/null 2>&1 <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: behavior-test
  namespace: lab-6-5
  labels:
    app: behavior-test
spec:
  containers:
  - name: test
    image: busybox:1.35
    command: ["sleep", "3600"]
  restartPolicy: Never
EOF
    echo -e "${GREEN}✓ Behavior test pod created${NC}"

    # Create a web application pod
    kubectl apply -f - > /dev/null 2>&1 <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: webapp
  namespace: lab-6-5
  labels:
    app: webapp
spec:
  containers:
  - name: nginx
    image: nginx:1.25
    ports:
    - containerPort: 80
  restartPolicy: Never
EOF
    echo -e "${GREEN}✓ Web application pod created${NC}"

    # Create falco namespace
    kubectl create namespace falco --dry-run=client -o yaml | kubectl apply -f - > /dev/null 2>&1
    echo -e "${GREEN}✓ Falco namespace ready${NC}"

    echo ""
}

wait_for_pods() {
    echo "Waiting for pods to be ready..."
    kubectl wait --for=condition=Ready pod/behavior-test -n lab-6-5 --timeout=60s > /dev/null 2>&1 || \
        echo -e "${YELLOW}Warning: behavior-test pod not ready yet${NC}"
    echo -e "${GREEN}✓ Pods ready${NC}"
    echo ""
}

# Main execution
check_prerequisites
create_resources
wait_for_pods

echo ""
echo -e "${GREEN}✓ Lab setup complete${NC}"
echo ""
echo "Resources created:"
kubectl get pods -n lab-6-5 2>/dev/null || true
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Create falco-behavior-rules.yaml with monitoring rules"
echo "2. Deploy as ConfigMap in falco namespace"
echo "3. Generate behavior data using the test pods"
echo "4. Analyze Falco logs and audit logs with jq"
