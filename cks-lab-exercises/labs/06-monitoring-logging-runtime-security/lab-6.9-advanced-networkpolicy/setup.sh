#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Lab Setup: Advanced NetworkPolicy - Multi-Tier Application Isolation ===${NC}"
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
    kubectl create namespace lab-6-9 --dry-run=client -o yaml | kubectl apply -f - > /dev/null 2>&1
    echo -e "${GREEN}✓ Namespace lab-6-9 ready${NC}"

    # Create frontend deployment
    kubectl apply -f - > /dev/null 2>&1 <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: lab-6-9
spec:
  replicas: 1
  selector:
    matchLabels:
      tier: frontend
  template:
    metadata:
      labels:
        tier: frontend
        app: webapp
    spec:
      containers:
      - name: frontend
        image: nginx:1.25
        ports:
        - containerPort: 80
EOF
    echo -e "${GREEN}✓ Frontend deployment created${NC}"

    # Create backend deployment
    kubectl apply -f - > /dev/null 2>&1 <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: lab-6-9
spec:
  replicas: 1
  selector:
    matchLabels:
      tier: backend
  template:
    metadata:
      labels:
        tier: backend
        app: webapp
    spec:
      containers:
      - name: backend
        image: nginx:1.25
        ports:
        - containerPort: 8080
        command: ["nginx", "-g", "daemon off;"]
EOF
    echo -e "${GREEN}✓ Backend deployment created${NC}"

    # Create database deployment
    kubectl apply -f - > /dev/null 2>&1 <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database
  namespace: lab-6-9
spec:
  replicas: 1
  selector:
    matchLabels:
      tier: database
  template:
    metadata:
      labels:
        tier: database
        app: webapp
    spec:
      containers:
      - name: database
        image: busybox:1.35
        command: ["sleep", "3600"]
        ports:
        - containerPort: 5432
EOF
    echo -e "${GREEN}✓ Database deployment created${NC}"

    # Create services
    kubectl apply -f - > /dev/null 2>&1 <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: frontend-svc
  namespace: lab-6-9
spec:
  selector:
    tier: frontend
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: backend-svc
  namespace: lab-6-9
spec:
  selector:
    tier: backend
  ports:
  - port: 8080
    targetPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: database-svc
  namespace: lab-6-9
spec:
  selector:
    tier: database
  ports:
  - port: 5432
    targetPort: 5432
EOF
    echo -e "${GREEN}✓ Services created${NC}"

    echo ""
}

wait_for_pods() {
    echo "Waiting for pods to be ready..."
    kubectl wait --for=condition=Ready pods -l app=webapp -n lab-6-9 --timeout=90s > /dev/null 2>&1 || \
        echo -e "${YELLOW}Warning: Some pods may not be ready yet${NC}"
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
kubectl get pods,svc -n lab-6-9 2>/dev/null || true
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Apply default-deny-all NetworkPolicy"
echo "2. Add selective allow policies for each tier"
echo "3. Run ./verify.sh to check your configuration"
