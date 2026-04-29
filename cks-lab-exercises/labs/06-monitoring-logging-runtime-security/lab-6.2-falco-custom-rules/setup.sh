#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}=== Lab Setup: Viết Falco Rules ===${NC}"
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

    # Check falco
    if ! command -v falco &> /dev/null; then
        echo -e "${YELLOW}Warning: falco not found${NC}"
        echo "Install falco: https://falco.org/docs/getting-started/installation/"
        echo "This lab requires this tool to complete"
        exit 1
    fi
    echo -e "${GREEN}✓ falco found${NC}"

    echo ""
}

# Create resources
create_resources() {
    echo "Creating lab resources..."
    echo ""

    # Create namespace
    kubectl create namespace lab-6-2 --dry-run=client -o yaml | kubectl apply -f - > /dev/null 2>&1
    echo -e "${GREEN}✓ Namespace lab-6-2 ready${NC}"

    # Create Kubernetes resources
    # Create Unknown
    cat <<EOF | kubectl apply -f - > /dev/null 2>&1
# falco-custom-rules.yaml

# Rule 1: Phát hiện shell container (backdoor)
- rule: Detect Shell Container
  desc: Detect creation of a shell container (potential backdoor)
  condition: >
    shell_containers and not known_shell_containers
  output: >
    Shell container created (user=%user.name container=%container.name
    shell=%container.shell image=%container.image)
  priority: WARNING
  tags: [container, shell]

- macro: shell_containers
  condition: >
    container.entrypoint in (/bin/sh, /bin/bash, /bin/zsh, /bin/fish)

- macro: known_shell_containers
  condition: >
    container.image.repository in (docker.io/library/alpine,
    docker.io/library/ubuntu)

---
# Rule 2: Phát hiện truy cập file nhạy cảm
- rule: Detect Sensitive File Access
  desc: Detect access to sensitive files like /etc/shadow
  condition: >
    open_read and fd.name in (/etc/shadow, /etc/passwd, /etc/sudoers)
    and not proc.aname in (sshd, login, systemd-logind)
  output: >
    Sensitive file access (user=%user.name command=%proc.cmdline file=%fd.name)
  priority: WARNING
  tags: [filesystem, security]

---
# Rule 3: Phát hiện Privileged Container
- rule: Detect Privileged Container
  desc: Detect privileged container startup
  condition: >
    container.privileged=true and not known_privileged_containers
  output: >
    Privileged container started (user=%user.name container=%container.name
    image=%container.image)
  priority: WARNING
  tags: [container, privilege]

---
# Rule 4: Phát hiện kubectl exec đáng ngờ
- rule: Suspicious kubectl exec
  desc: Multiple kubectl exec to different pods in short time
  condition: >
    spawned_process and proc.name="kubectl"
    and proc.args contains "exec"
    and proc.args contains "-it"
  output: >
    Suspicious kubectl exec detected (user=%user.name pod=%k8s.pod.name
    namespace=%k8s.pod.namespace command=%proc.cmdline)
  priority: WARNING
  tags: [kubernetes, exec]

---
# Rule 5: Phát hiện sửa đổi K8s Secret/ConfigMap
- rule: Detect Kubernetes Secret Modification
  desc: Detect modification to K8s secrets
  condition: >
    kubectl.modify and kubectl.resource in (secret, configmap)
  output: >
    Kubernetes secret/configmap modified (user=%user.name
    command=%kubectl.command resource=%kubectl.resource)
  priority: WARNING
  tags: [kubernetes, audit]
EOF
    echo -e "${GREEN}✓ Unknown created${NC}"

    # tags: [kubernetes, audit]
    cat <<EOF | kubectl apply -f - > /dev/null 2>&1
# Deploy custom Falco rules bằng ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: falco-custom-rules
  namespace: falco
data:
  custom-rules.yaml: |
    # Paste nội dung rules ở trên vào đây
EOF
    echo -e "${GREEN}✓ ConfigMap created${NC}"

    echo ""
}

# Main execution
check_prerequisites
create_resources

echo ""
echo -e "${GREEN}✓ Lab setup complete${NC}"
echo "Resources created in namespace: lab-6-2"
kubectl get all -n lab-6-2 2>/dev/null || true
