#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Lab Setup: Falco Custom Rules - Privileged Container Detection ===${NC}"
echo ""

# Check prerequisites
check_prerequisites() {
    echo "Checking prerequisites..."
    echo ""

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
    echo -e "${GREEN}✓ Connected to Kubernetes cluster${NC}"

    # Check Falco
    if kubectl get daemonset -n falco falco &> /dev/null 2>&1; then
        echo -e "${GREEN}✓ Falco DaemonSet found${NC}"
    else
        echo -e "${YELLOW}Warning: Falco DaemonSet not found. Some checks may fail.${NC}"
        echo "Install Falco: https://falco.org/docs/getting-started/installation/"
    fi

    echo ""
}

# Create resources
create_resources() {
    echo "Creating lab resources..."
    echo ""

    # Create namespace
    kubectl create namespace lab-6-4 --dry-run=client -o yaml | kubectl apply -f - > /dev/null 2>&1
    echo -e "${GREEN}✓ Namespace lab-6-4 ready${NC}"

    # Create a privileged test pod (will trigger Falco rule)
    kubectl apply -f - > /dev/null 2>&1 <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: privileged-test
  namespace: lab-6-4
  labels:
    app: privileged-test
    security-test: "true"
spec:
  containers:
  - name: privileged-container
    image: busybox:1.35
    command: ["sleep", "3600"]
    securityContext:
      privileged: true
  restartPolicy: Never
EOF
    echo -e "${GREEN}✓ Privileged test pod created${NC}"

    # Create a non-privileged pod for comparison
    kubectl apply -f - > /dev/null 2>&1 <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: normal-pod
  namespace: lab-6-4
  labels:
    app: normal-pod
spec:
  containers:
  - name: normal-container
    image: busybox:1.35
    command: ["sleep", "3600"]
    securityContext:
      privileged: false
      runAsNonRoot: true
      runAsUser: 1000
  restartPolicy: Never
EOF
    echo -e "${GREEN}✓ Normal (non-privileged) pod created${NC}"

    # Create falco namespace for ConfigMap
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
kubectl get pods -n lab-6-4 2>/dev/null || true
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Create falco-privileged-rules.yaml with the detection rules"
echo "2. Deploy as ConfigMap: kubectl create configmap falco-privileged-rules --from-file=falco-privileged-rules.yaml -n falco"
echo "3. Restart Falco: kubectl rollout restart daemonset/falco -n falco"
echo "4. Check Falco logs for alerts about the privileged-test pod"
