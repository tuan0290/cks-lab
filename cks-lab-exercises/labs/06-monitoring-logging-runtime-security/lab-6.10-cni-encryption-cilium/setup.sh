#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}=== Lab Setup: CNI Network Encryption (Cilium IPsec) ===${NC}"
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

    # Check trivy
    if ! command -v trivy &> /dev/null; then
        echo -e "${YELLOW}Warning: trivy not found${NC}"
        echo "Install trivy: https://aquasecurity.github.io/trivy/latest/getting-started/installation/"
        echo "This lab requires this tool to complete"
        exit 1
    fi
    echo -e "${GREEN}✓ trivy found${NC}"

    # Check falco
    if ! command -v falco &> /dev/null; then
        echo -e "${YELLOW}Warning: falco not found${NC}"
        echo "Install falco: https://falco.org/docs/getting-started/installation/"
        echo "This lab requires this tool to complete"
        exit 1
    fi
    echo -e "${GREEN}✓ falco found${NC}"

    # Check syft
    if ! command -v syft &> /dev/null; then
        echo -e "${YELLOW}Warning: syft not found${NC}"
        echo "Install syft: https://github.com/anchore/syft#installation"
        echo "This lab requires this tool to complete"
        exit 1
    fi
    echo -e "${GREEN}✓ syft found${NC}"

    # Check cosign
    if ! command -v cosign &> /dev/null; then
        echo -e "${YELLOW}Warning: cosign not found${NC}"
        echo "Install cosign: https://docs.sigstore.dev/cosign/installation/"
        echo "This lab requires this tool to complete"
        exit 1
    fi
    echo -e "${GREEN}✓ cosign found${NC}"

    echo ""
}

# Create resources
create_resources() {
    echo "Creating lab resources..."
    echo ""

    # Create namespace
    kubectl create namespace lab-6-10 --dry-run=client -o yaml | kubectl apply -f - > /dev/null 2>&1
    echo -e "${GREEN}✓ Namespace lab-6-10 ready${NC}"

    # Create Kubernetes resources
    # Create ConfigMap
    cat <<EOF | kubectl apply -f - > /dev/null 2>&1
# Cilium ConfigMap — Bật IPsec encryption
apiVersion: v1
kind: ConfigMap
metadata:
  name: cilium-config
  namespace: kube-system
data:
  enable-ipsec: "true"
  ipsec-key-file: "/etc/cilium/ipsec/keys"
  encryption: "ipsec"
  encryption-node-encryption: "true"   # Encrypt cả Pod-to-Pod
  tls-ca-cert: "/var/lib/cilium/tls/ca.crt"
  tls-client-cert: "/var/lib/cilium/tls/client.crt"
  tls-client-key: "/var/lib/cilium/tls/client.key"
EOF
    echo -e "${GREEN}✓ ConfigMap created${NC}"

    # Execute setup commands
    # ---
    □ Cấu hình NetworkPolicy (deny all + allow specific) > /dev/null 2>&1 || true

    # ---
    □ Mã hóa etcd với EncryptionConfiguration > /dev/null 2>&1 || true

    # ---
    □ Cấu hình containerd/CRI-O đúng cách > /dev/null 2>&1 || true

    echo ""
}

# Main execution
check_prerequisites
create_resources

echo ""
echo -e "${GREEN}✓ Lab setup complete${NC}"
echo "Resources created in namespace: lab-6-10"
kubectl get all -n lab-6-10 2>/dev/null || true
