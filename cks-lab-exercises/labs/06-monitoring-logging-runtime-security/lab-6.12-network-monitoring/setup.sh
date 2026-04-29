#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Lab Setup: Network Traffic Monitoring and Anomaly Detection ===${NC}"
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

    # Check Falco
    if kubectl get daemonset -n falco falco &> /dev/null 2>&1; then
        echo -e "${GREEN}✓ Falco DaemonSet found${NC}"
    else
        echo -e "${YELLOW}Warning: Falco DaemonSet not found. Detection checks may fail.${NC}"
    fi

    echo ""
}

create_resources() {
    echo "Creating lab resources..."
    echo ""

    # Create namespace with label for NetworkPolicy
    kubectl create namespace lab-6-12 --dry-run=client -o yaml | kubectl apply -f - > /dev/null 2>&1
    kubectl label namespace lab-6-12 kubernetes.io/metadata.name=lab-6-12 --overwrite > /dev/null 2>&1
    echo -e "${GREEN}✓ Namespace lab-6-12 ready${NC}"

    # Create network test pod
    kubectl apply -f - > /dev/null 2>&1 <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: network-test
  namespace: lab-6-12
  labels:
    app: network-test
spec:
  containers:
  - name: test
    image: busybox:1.35
    command: ["sleep", "3600"]
  restartPolicy: Never
EOF
    echo -e "${GREEN}✓ Network test pod created${NC}"

    # Create an internal service for testing
    kubectl apply -f - > /dev/null 2>&1 <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: internal-server
  namespace: lab-6-12
  labels:
    app: internal-server
spec:
  containers:
  - name: server
    image: nginx:1.25
    ports:
    - containerPort: 80
  restartPolicy: Never
---
apiVersion: v1
kind: Service
metadata:
  name: internal-svc
  namespace: lab-6-12
spec:
  selector:
    app: internal-server
  ports:
  - port: 80
    targetPort: 80
EOF
    echo -e "${GREEN}✓ Internal server and service created${NC}"

    # Create falco namespace
    kubectl create namespace falco --dry-run=client -o yaml | kubectl apply -f - > /dev/null 2>&1
    echo -e "${GREEN}✓ Falco namespace ready${NC}"

    echo ""
}

wait_for_pods() {
    echo "Waiting for pods to be ready..."
    kubectl wait --for=condition=Ready pod/network-test -n lab-6-12 --timeout=60s > /dev/null 2>&1 || \
        echo -e "${YELLOW}Warning: network-test pod not ready yet${NC}"
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
kubectl get pods,svc -n lab-6-12 2>/dev/null || true
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Create falco-network-monitoring-rules.yaml with detection rules"
echo "2. Deploy as ConfigMap in falco namespace"
echo "3. Test network connections to trigger alerts"
echo "4. Implement NetworkPolicies to restrict traffic"
echo "5. Analyze Falco logs for network anomalies"
