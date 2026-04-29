#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}=== Lab Setup: Base Image Minimization ===${NC}"
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

    # Create namespace (idempotent)
    kubectl create namespace lab-5-5 --dry-run=client -o yaml | kubectl apply -f - > /dev/null 2>&1
    echo -e "${GREEN}✓ Namespace lab-5-5 ready${NC}"

    # Create a reference deployment with a full OS image (to demonstrate the problem)
    kubectl apply -f - > /dev/null 2>&1 <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: full-image-app
  namespace: lab-5-5
  labels:
    app: full-image-app
    scenario: before-minimization
spec:
  replicas: 1
  selector:
    matchLabels:
      app: full-image-app
  template:
    metadata:
      labels:
        app: full-image-app
    spec:
      containers:
      - name: app
        image: nginx:1.25
        ports:
        - containerPort: 80
        resources:
          limits:
            cpu: "100m"
            memory: "64Mi"
EOF
    echo -e "${GREEN}✓ Reference deployment (full-image-app) created${NC}"

    # Create a ConfigMap with instructions
    kubectl apply -f - > /dev/null 2>&1 <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: lab-instructions
  namespace: lab-5-5
data:
  task: |
    Your task is to:
    1. Create a deployment 'distroless-app' using gcr.io/distroless/static-debian12:nonroot
    2. Configure it with runAsNonRoot: true, readOnlyRootFilesystem: true
    3. Drop ALL capabilities
    4. Create a ConfigMap 'multistage-dockerfile' with a multi-stage Dockerfile
    5. Create a pod 'minimal-alpine-pod' using alpine:3.19 with security hardening
EOF
    echo -e "${GREEN}✓ Lab instructions ConfigMap created${NC}"

    echo ""
}

# Main execution
check_prerequisites
create_resources

echo ""
echo -e "${GREEN}✓ Lab setup complete${NC}"
echo "Resources created in namespace: lab-5-5"
echo ""
echo -e "${YELLOW}Your task:${NC}"
echo "1. Create a deployment 'distroless-app' using gcr.io/distroless/static-debian12:nonroot"
echo "2. Configure security context: runAsNonRoot=true, readOnlyRootFilesystem=true, drop ALL caps"
echo "3. Create ConfigMap 'multistage-dockerfile' with a multi-stage Dockerfile"
echo "4. Create pod 'minimal-alpine-pod' using alpine:3.19 with security hardening"
echo ""
kubectl get all -n lab-5-5 2>/dev/null || true
