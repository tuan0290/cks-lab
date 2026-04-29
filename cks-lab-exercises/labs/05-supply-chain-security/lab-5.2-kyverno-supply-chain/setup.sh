#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}=== Lab Setup: Kyverno Policy — Supply Chain Security ===${NC}"
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

    # Create namespace
    kubectl create namespace lab-5-2 --dry-run=client -o yaml | kubectl apply -f - > /dev/null 2>&1
    echo -e "${GREEN}✓ Namespace lab-5-2 ready${NC}"

    # Create Kubernetes resources
    # Create Unknown
    cat <<EOF | kubectl apply -f - > /dev/null 2>&1
# Kyverno ClusterPolicy: Chỉ cho phép image từ registry được phép
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: check-image-registry
  annotations:
    policies.kyverno.io/title: Check Image Registry
    policies.kyverno.io/category: Supply Chain Security
    policies.kyverno.io/severity: medium
spec:
  validationFailureAction: enforce
  background: true
  rules:
  - name: verify-registry
    match:
      any:
      - resources:
          kinds:
          - Pod
    validate:
      message: "Images must only be pulled from approved registries"
      pattern:
        spec:
          containers:
          - image: "myregistry.io/* | gcr.io/myproject/*"
---
# Kyverno Policy: Xác thực chữ ký image (Cosign)
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-image-signature
  annotations:
    policies.kyverno.io/title: Verify Image Signature
    policies.kyverno.io/severity: high
spec:
  validationFailureAction: enforce
  rules:
  - name: verify-signature
    match:
      any:
      - resources:
          kinds:
          - Pod
    verifyImages:
    - imageReferences:
      - "myregistry.io/*"
      key: |-
        -----BEGIN PUBLIC KEY-----
        MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE...
        -----END PUBLIC KEY-----
EOF
    echo -e "${GREEN}✓ Unknown created${NC}"

    echo ""
}

# Main execution
check_prerequisites
create_resources

echo ""
echo -e "${GREEN}✓ Lab setup complete${NC}"
echo "Resources created in namespace: lab-5-2"
kubectl get all -n lab-5-2 2>/dev/null || true
