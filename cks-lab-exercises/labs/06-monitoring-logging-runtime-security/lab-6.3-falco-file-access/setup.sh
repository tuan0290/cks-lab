#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}=== Lab Setup: Falco Custom Rules - Sensitive File Access ===${NC}"
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

    # Check Falco (warn but don't exit - Falco may be installed differently)
    if ! command -v falco &> /dev/null; then
        echo -e "${YELLOW}Warning: falco binary not found in PATH${NC}"
        echo "Falco may be running as a DaemonSet. Checking..."
        if kubectl get daemonset -n falco falco &> /dev/null 2>&1; then
            echo -e "${GREEN}✓ Falco DaemonSet found${NC}"
        else
            echo -e "${YELLOW}Warning: Falco not detected. Install from: https://falco.org/docs/getting-started/installation/${NC}"
            echo "Continuing setup - some verification checks may fail without Falco"
        fi
    else
        echo -e "${GREEN}✓ falco found${NC}"
    fi

    echo ""
}

# Create resources
create_resources() {
    echo "Creating lab resources..."
    echo ""

    # Create namespace
    kubectl create namespace lab-6-3 --dry-run=client -o yaml | kubectl apply -f - > /dev/null 2>&1
    echo -e "${GREEN}✓ Namespace lab-6-3 ready${NC}"

    # Create a test pod that will be used to simulate file access
    kubectl apply -f - > /dev/null 2>&1 <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: file-access-test
  namespace: lab-6-3
  labels:
    app: file-access-test
spec:
  containers:
  - name: test-container
    image: busybox:1.35
    command: ["sleep", "3600"]
    securityContext:
      runAsNonRoot: false
      runAsUser: 0
  restartPolicy: Always
EOF
    echo -e "${GREEN}✓ Test pod file-access-test created${NC}"

    # Create a legitimate pod that should NOT trigger alerts
    kubectl apply -f - > /dev/null 2>&1 <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: legitimate-app
  namespace: lab-6-3
  labels:
    app: legitimate-app
spec:
  containers:
  - name: app
    image: nginx:1.25
    ports:
    - containerPort: 80
  restartPolicy: Always
EOF
    echo -e "${GREEN}✓ Legitimate app pod created${NC}"

    # Create the falco namespace if it doesn't exist (for ConfigMap deployment)
    kubectl create namespace falco --dry-run=client -o yaml | kubectl apply -f - > /dev/null 2>&1
    echo -e "${GREEN}✓ Falco namespace ready${NC}"

    echo ""
}

# Wait for pods to be ready
wait_for_pods() {
    echo "Waiting for pods to be ready..."
    kubectl wait --for=condition=Ready pod/file-access-test -n lab-6-3 --timeout=60s > /dev/null 2>&1 || \
        echo -e "${YELLOW}Warning: file-access-test pod not ready yet${NC}"
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
kubectl get all -n lab-6-3 2>/dev/null || true
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Create the Falco custom rules file (see README.md)"
echo "2. Deploy rules as a ConfigMap in the falco namespace"
echo "3. Restart Falco to load the new rules"
echo "4. Test by accessing sensitive files from the test pod"
