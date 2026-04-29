#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Lab Setup: Threat Detection - Attack Simulation and Response ===${NC}"
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
        echo -e "${YELLOW}Warning: jq not found. Audit log analysis steps will be limited.${NC}"
        echo "Install jq: https://stedolan.github.io/jq/download/"
    else
        echo -e "${GREEN}✓ jq found${NC}"
    fi

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

    # Create namespace
    kubectl create namespace lab-6-8 --dry-run=client -o yaml | kubectl apply -f - > /dev/null 2>&1
    echo -e "${GREEN}✓ Namespace lab-6-8 ready${NC}"

    # Create "attacker" pod (simulates a compromised container)
    kubectl apply -f - > /dev/null 2>&1 <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: attacker-pod
  namespace: lab-6-8
  labels:
    role: attacker
    app: threat-test
spec:
  containers:
  - name: attacker
    image: busybox:1.35
    command: ["sleep", "3600"]
    securityContext:
      runAsUser: 0
  restartPolicy: Never
EOF
    echo -e "${GREEN}✓ Attacker simulation pod created${NC}"

    # Create a "victim" application pod
    kubectl apply -f - > /dev/null 2>&1 <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: victim-app
  namespace: lab-6-8
  labels:
    role: victim
    app: threat-test
spec:
  containers:
  - name: app
    image: nginx:1.25
    ports:
    - containerPort: 80
  restartPolicy: Never
EOF
    echo -e "${GREEN}✓ Victim application pod created${NC}"

    # Create a monitoring pod
    kubectl apply -f - > /dev/null 2>&1 <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: monitor-pod
  namespace: lab-6-8
  labels:
    role: monitor
    app: threat-test
spec:
  containers:
  - name: monitor
    image: busybox:1.35
    command: ["sleep", "3600"]
  restartPolicy: Never
EOF
    echo -e "${GREEN}✓ Monitor pod created${NC}"

    # Create falco namespace for ConfigMap
    kubectl create namespace falco --dry-run=client -o yaml | kubectl apply -f - > /dev/null 2>&1
    echo -e "${GREEN}✓ Falco namespace ready${NC}"

    echo ""
}

wait_for_pods() {
    echo "Waiting for pods to be ready..."
    kubectl wait --for=condition=Ready pod/attacker-pod -n lab-6-8 --timeout=60s > /dev/null 2>&1 || \
        echo -e "${YELLOW}Warning: attacker-pod not ready yet${NC}"
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
kubectl get pods -n lab-6-8 2>/dev/null || true
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Create falco-threat-detection-rules.yaml with detection rules"
echo "2. Deploy as ConfigMap in falco namespace"
echo "3. Simulate attack scenarios using the attacker-pod"
echo "4. Analyze Falco logs and audit logs for detection"
echo "5. Implement incident response (network isolation)"
