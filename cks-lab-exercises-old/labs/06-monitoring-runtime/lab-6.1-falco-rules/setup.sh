#!/bin/bash
# Lab 6.1 – Falco Rules
# Script khởi tạo môi trường lab

set -e

echo "=========================================="
echo " Lab 6.1 – Falco Rules"
echo " Đang khởi tạo môi trường..."
echo "=========================================="

# --- Kiểm tra prerequisites ---

if ! command -v kubectl &>/dev/null; then
  echo "[ERROR] kubectl không tìm thấy. Vui lòng cài đặt kubectl trước."
  exit 1
fi

if ! kubectl cluster-info &>/dev/null; then
  echo "[ERROR] Không thể kết nối đến Kubernetes cluster."
  echo "        Kiểm tra kubeconfig: kubectl cluster-info"
  exit 1
fi

echo "[OK] kubectl và cluster kết nối thành công."

# Kiểm tra Falco
FALCO_FOUND=0
if command -v falco &>/dev/null; then
  echo "[OK] falco binary tìm thấy: $(falco --version 2>/dev/null | head -1)"
  FALCO_FOUND=1
elif systemctl list-units --type=service 2>/dev/null | grep -q falco; then
  echo "[OK] Falco systemd service tìm thấy."
  FALCO_FOUND=1
elif kubectl get daemonset falco -n falco &>/dev/null 2>&1; then
  echo "[OK] Falco DaemonSet tìm thấy trong namespace 'falco'."
  FALCO_FOUND=1
fi

if [ "$FALCO_FOUND" -eq 0 ]; then
  echo "[WARN] Falco không tìm thấy."
  echo "       Cài đặt Falco:"
  echo "         Helm: helm install falco falcosecurity/falco --namespace falco --create-namespace"
  echo "         Tài liệu: https://falco.org/docs/getting-started/installation/"
  echo ""
  echo "[INFO] Tiếp tục tạo môi trường lab..."
fi

# --- Tạo namespace falco-lab ---

echo ""
echo "Tạo namespace falco-lab..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: falco-lab
  labels:
    lab: "6.1"
    purpose: falco-rules
EOF

echo "[OK] Namespace 'falco-lab' đã được tạo."

# --- Tạo test pod ---

echo ""
echo "Tạo test pod trong namespace falco-lab..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
  namespace: falco-lab
  labels:
    app: test-pod
    lab: "6.1"
spec:
  containers:
  - name: app
    image: nginx:1.25-alpine
    command: ["sleep", "3600"]
EOF

echo "[OK] Pod 'test-pod' đã được tạo."

# Chờ pod sẵn sàng
echo "Chờ pod 'test-pod' khởi động..."
kubectl wait --for=condition=Ready pod/test-pod -n falco-lab --timeout=60s 2>/dev/null || \
  echo "[WARN] Pod chưa Ready sau 60s. Kiểm tra: kubectl get pod test-pod -n falco-lab"

# --- Tạo custom Falco rule file tại /tmp/custom-rules.yaml ---

echo ""
echo "Tạo custom Falco rule file tại /tmp/custom-rules.yaml..."

cat > /tmp/custom-rules.yaml <<'EOF'
# Custom Falco Rules – Lab 6.1
# Phát hiện shell spawn trong container

- rule: Detect Shell Spawned in Container
  desc: Phát hiện khi shell được spawn trong container (dấu hiệu tấn công tiềm năng)
  condition: >
    spawned_process and container
    and proc.name in (shell_binaries)
  output: >
    Shell spawned in container
    (user=%user.name user_loginuid=%user.loginuid
    container_id=%container.id container_name=%container.name
    image=%container.image.repository:%container.image.tag
    shell=%proc.name parent=%proc.pname
    cmdline=%proc.cmdline
    k8s_ns=%k8s.ns.name k8s_pod=%k8s.pod.name)
  priority: WARNING
  tags: [container, shell, mitre_execution, cks_lab]

- list: shell_binaries
  items: [bash, sh, zsh, ksh, fish, tcsh, csh, dash]

- rule: Detect Interactive Shell in Container
  desc: Phát hiện shell tương tác (có terminal) trong container
  condition: >
    spawned_process and container
    and proc.name in (shell_binaries)
    and proc.tty != 0
  output: >
    Interactive shell spawned in container
    (user=%user.name
    container_id=%container.id container_name=%container.name
    image=%container.image.repository:%container.image.tag
    shell=%proc.name parent=%proc.pname
    terminal=%proc.tty
    k8s_ns=%k8s.ns.name k8s_pod=%k8s.pod.name)
  priority: CRITICAL
  tags: [container, shell, interactive, mitre_execution, cks_lab]
EOF

echo "[OK] File /tmp/custom-rules.yaml đã được tạo."

echo ""
echo "=========================================="
echo " Môi trường đã sẵn sàng!"
echo "=========================================="
echo ""
echo "Tài nguyên đã tạo:"
echo "  Namespace: falco-lab"
echo "  Pod:       test-pod (nginx:1.25-alpine)"
echo "  File:      /tmp/custom-rules.yaml (custom Falco rules)"
echo ""
echo "NHIỆM VỤ:"
echo "  1. Xem custom rule file:"
echo "       cat /tmp/custom-rules.yaml"
echo ""
echo "  2. Load custom rule vào Falco:"
echo "     Nếu Falco là systemd service:"
echo "       sudo cp /tmp/custom-rules.yaml /etc/falco/rules.d/custom-rules.yaml"
echo "       sudo systemctl restart falco"
echo "     Nếu Falco là DaemonSet:"
echo "       kubectl create configmap falco-custom-rules \\"
echo "         --from-file=custom-rules.yaml=/tmp/custom-rules.yaml \\"
echo "         -n falco --dry-run=client -o yaml | kubectl apply -f -"
echo "       kubectl rollout restart daemonset/falco -n falco"
echo ""
echo "  3. Kích hoạt rule bằng kubectl exec:"
echo "       kubectl exec -it test-pod -n falco-lab -- /bin/sh"
echo ""
echo "  4. Kiểm tra Falco alert:"
echo "       sudo journalctl -u falco -f | grep shell"
echo "     Hoặc:"
echo "       kubectl logs -n falco -l app=falco --tail=50 | grep shell"
echo ""
echo "  5. Chạy verify.sh để kiểm tra kết quả:"
echo "       bash verify.sh"
echo ""
echo "Dọn dẹp sau khi hoàn thành:"
echo "  bash cleanup.sh"
echo ""
