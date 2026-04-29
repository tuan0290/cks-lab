#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Lab Setup: Kubernetes Incident Response ===${NC}"
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
        echo -e "${YELLOW}Warning: jq not found. Some analysis steps will be limited.${NC}"
    else
        echo -e "${GREEN}✓ jq found${NC}"
    fi

    echo ""
}

create_resources() {
    echo "Creating lab resources..."
    echo ""

    # Create namespace
    kubectl create namespace lab-6-11 --dry-run=client -o yaml | kubectl apply -f - > /dev/null 2>&1
    echo -e "${GREEN}✓ Namespace lab-6-11 ready${NC}"

    # Create a ServiceAccount with elevated permissions (simulating misconfiguration)
    kubectl apply -f - > /dev/null 2>&1 <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: compromised-sa
  namespace: lab-6-11
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: overprivileged-role
  namespace: lab-6-11
rules:
- apiGroups: [""]
  resources: ["pods", "secrets", "configmaps", "serviceaccounts"]
  verbs: ["get", "list", "watch", "create", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: compromised-binding
  namespace: lab-6-11
subjects:
- kind: ServiceAccount
  name: compromised-sa
  namespace: lab-6-11
roleRef:
  kind: Role
  name: overprivileged-role
  apiGroup: rbac.authorization.k8s.io
EOF
    echo -e "${GREEN}✓ Compromised ServiceAccount and RBAC created${NC}"

    # Create the "suspicious" pod (simulates a compromised container)
    kubectl apply -f - > /dev/null 2>&1 <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: suspicious-pod
  namespace: lab-6-11
  labels:
    app: webapp
    status: compromised
spec:
  serviceAccountName: compromised-sa
  containers:
  - name: suspicious
    image: busybox:1.35
    command:
    - /bin/sh
    - -c
    - |
      echo "Starting suspicious activity simulation..."
      # Simulate reconnaissance
      cat /var/run/secrets/kubernetes.io/serviceaccount/token > /tmp/token.txt
      ls /etc/ > /tmp/recon.txt
      # Keep running
      sleep 3600
  restartPolicy: Never
EOF
    echo -e "${GREEN}✓ Suspicious pod created (simulating compromised container)${NC}"

    # Create a legitimate pod for comparison
    kubectl apply -f - > /dev/null 2>&1 <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: legitimate-pod
  namespace: lab-6-11
  labels:
    app: webapp
    status: clean
spec:
  containers:
  - name: app
    image: nginx:1.25
    ports:
    - containerPort: 80
  restartPolicy: Never
EOF
    echo -e "${GREEN}✓ Legitimate pod created${NC}"

    # Create falco namespace
    kubectl create namespace falco --dry-run=client -o yaml | kubectl apply -f - > /dev/null 2>&1
    echo -e "${GREEN}✓ Falco namespace ready${NC}"

    echo ""
}

wait_for_pods() {
    echo "Waiting for pods to be ready..."
    kubectl wait --for=condition=Ready pod/suspicious-pod -n lab-6-11 --timeout=60s > /dev/null 2>&1 || \
        echo -e "${YELLOW}Warning: suspicious-pod not ready yet${NC}"
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
kubectl get pods,sa,rolebindings -n lab-6-11 2>/dev/null || true
echo ""
echo -e "${YELLOW}Incident Scenario:${NC}"
echo "The 'suspicious-pod' is exhibiting suspicious behavior:"
echo "  - It has access to the Kubernetes API via a compromised ServiceAccount"
echo "  - It is reading sensitive files and storing them in /tmp"
echo "  - It has overprivileged RBAC permissions"
echo ""
echo "Your task: Follow the incident response procedure in README.md"
