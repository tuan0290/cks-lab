#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Lab Setup: Dependency Scanning with Trivy ===${NC}"
echo ""

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

    if ! command -v trivy &> /dev/null; then
        echo -e "${YELLOW}Warning: trivy not found${NC}"
        echo "Install trivy: https://aquasecurity.github.io/trivy/latest/getting-started/installation/"
        echo "This lab requires trivy for image scanning tasks"
        echo ""
        echo "Quick install:"
        echo "  curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin"
    else
        echo -e "${GREEN}✓ trivy found ($(trivy --version | head -1))${NC}"
    fi

    echo ""
}

create_resources() {
    echo "Creating lab resources..."
    echo ""

    # Create namespace
    kubectl create namespace lab-5-11 --dry-run=client -o yaml | kubectl apply -f - > /dev/null 2>&1
    echo -e "${GREEN}✓ Namespace lab-5-11 ready${NC}"

    # Create lab instructions
    kubectl apply -f - > /dev/null 2>&1 <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: lab-instructions
  namespace: lab-5-11
data:
  task: |
    Your task is to:
    1. Run trivy image scan on nginx:1.25 (if trivy is available)
    2. Create ConfigMap 'scan-policy' with vulnerability thresholds
    3. Create ConfigMap 'scan-results' with scan findings
    4. Create Job 'trivy-scanner' that runs trivy in-cluster
    5. Create Deployment 'scanned-app' with scan annotations
  trivy-commands: |
    # Basic scan
    trivy image nginx:1.25

    # Severity filter
    trivy image --severity HIGH,CRITICAL nginx:1.25

    # JSON output
    trivy image --format json nginx:1.25

    # Fail on CRITICAL
    trivy image --severity CRITICAL --exit-code 1 nginx:1.25

    # Scan Kubernetes config
    trivy config deployment.yaml
EOF
    echo -e "${GREEN}✓ Lab instructions ConfigMap created${NC}"

    echo ""
}

check_prerequisites
create_resources

echo ""
echo -e "${GREEN}✓ Lab setup complete${NC}"
echo "Resources created in namespace: lab-5-11"
echo ""
echo -e "${YELLOW}Your task:${NC}"
echo "1. Run: trivy image --severity HIGH,CRITICAL nginx:1.25"
echo "2. Create ConfigMap 'scan-policy' with thresholds"
echo "3. Create ConfigMap 'scan-results' with findings"
echo "4. Create Job 'trivy-scanner'"
echo "5. Create Deployment 'scanned-app' with scan annotations"
echo ""
kubectl get all -n lab-5-11 2>/dev/null || true
