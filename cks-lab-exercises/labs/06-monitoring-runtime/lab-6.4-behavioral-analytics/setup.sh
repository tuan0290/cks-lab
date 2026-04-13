#!/bin/bash
# Lab 6.4 – Behavioral Analytics với Falco
# Script khởi tạo môi trường lab

set -e

echo "=========================================="
echo " Lab 6.4 – Behavioral Analytics với Falco"
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

# Kiểm tra Falco (cảnh báo nhưng không exit)
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
  echo "[WARN] Falco chưa được cài đặt hoặc không tìm thấy."
  echo "       Xem hướng dẫn cài đặt trong README.md (Gợi ý 5)"
  echo "       Hoặc: helm install falco falcosecurity/falco --namespace falco --create-namespace"
  echo ""
  echo "[INFO] Tiếp tục tạo môi trường lab (namespace và pod test)..."
fi

# --- Tạo namespace falco-behavioral-lab ---

echo ""
echo "Tạo namespace falco-behavioral-lab..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: falco-behavioral-lab
  labels:
    lab: "6.4"
    purpose: behavioral-analytics
EOF

echo "[OK] Namespace 'falco-behavioral-lab' đã được tạo."

# --- Deploy pod attacker-sim ---

echo ""
echo "Deploy pod attacker-sim trong namespace falco-behavioral-lab..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: attacker-sim
  namespace: falco-behavioral-lab
  labels:
    app: attacker-sim
    lab: "6.4"
spec:
  containers:
  - name: attacker
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      allowPrivilegeEscalation: false
EOF

echo "[OK] Pod 'attacker-sim' đã được tạo."

# Chờ pod sẵn sàng
echo "Chờ pod 'attacker-sim' khởi động..."
kubectl wait --for=condition=Ready pod/attacker-sim -n falco-behavioral-lab --timeout=60s 2>/dev/null || \
  echo "[WARN] Pod chưa Ready sau 60s. Kiểm tra: kubectl get pod attacker-sim -n falco-behavioral-lab"

# --- Tạo script trigger-behaviors.sh ---

echo ""
echo "Tạo script /tmp/trigger-behaviors.sh..."

cat > /tmp/trigger-behaviors.sh <<'TRIGGER_EOF'
#!/bin/bash
# Script kích hoạt hành vi độc hại có kiểm soát – Lab 6.4
# Dùng để trigger Falco alerts sau khi đã cấu hình rules

echo "=========================================="
echo " Trigger Behaviors – Lab 6.4"
echo "=========================================="
echo ""

if ! command -v kubectl &>/dev/null; then
  echo "[ERROR] kubectl không tìm thấy."
  exit 1
fi

# Kiểm tra pod đang chạy
if ! kubectl get pod attacker-sim -n falco-behavioral-lab &>/dev/null; then
  echo "[ERROR] Pod 'attacker-sim' không tìm thấy trong namespace 'falco-behavioral-lab'."
  echo "        Chạy setup.sh trước: bash setup.sh"
  exit 1
fi

POD_STATUS=$(kubectl get pod attacker-sim -n falco-behavioral-lab -o jsonpath='{.status.phase}' 2>/dev/null)
if [ "$POD_STATUS" != "Running" ]; then
  echo "[ERROR] Pod 'attacker-sim' chưa Running (status: ${POD_STATUS})."
  echo "        Chờ pod sẵn sàng: kubectl wait --for=condition=Ready pod/attacker-sim -n falco-behavioral-lab"
  exit 1
fi

echo "[INFO] Bắt đầu trigger behaviors..."
echo ""

# Trigger 1: Đọc /etc/passwd (credential access)
echo "--- Trigger 1: Đọc /etc/passwd ---"
kubectl exec attacker-sim -n falco-behavioral-lab -- cat /etc/passwd > /dev/null 2>&1 && \
  echo "[OK] Đã trigger: đọc /etc/passwd" || \
  echo "[WARN] Không thể exec vào pod"

sleep 1

# Trigger 2: Đọc /etc/shadow (credential access - có thể fail nếu không có file)
echo "--- Trigger 2: Đọc /etc/shadow ---"
kubectl exec attacker-sim -n falco-behavioral-lab -- sh -c 'cat /etc/shadow 2>/dev/null || echo "shadow not found"' > /dev/null 2>&1 && \
  echo "[OK] Đã trigger: đọc /etc/shadow" || \
  echo "[WARN] Không thể exec vào pod"

sleep 1

# Trigger 3: Outbound network connection (egress)
echo "--- Trigger 3: Outbound network connection ---"
kubectl exec attacker-sim -n falco-behavioral-lab -- sh -c 'wget -q --timeout=3 http://1.1.1.1 -O /dev/null 2>/dev/null || nc -z -w 3 1.1.1.1 80 2>/dev/null || true' > /dev/null 2>&1 && \
  echo "[OK] Đã trigger: outbound network connection" || \
  echo "[WARN] Network trigger không thành công (có thể do network policy)"

echo ""
echo "=========================================="
echo " Behaviors đã được trigger!"
echo "=========================================="
echo ""
echo "Kiểm tra Falco alerts:"
echo "  cat /tmp/falco-alerts.log"
echo "  sudo journalctl -u falco --since '1 minute ago'"
echo "  kubectl logs -n falco -l app=falco --tail=50"
echo ""
TRIGGER_EOF

chmod +x /tmp/trigger-behaviors.sh
echo "[OK] Script /tmp/trigger-behaviors.sh đã được tạo."

echo ""
echo "=========================================="
echo " Môi trường đã sẵn sàng!"
echo "=========================================="
echo ""
echo "Tài nguyên đã tạo:"
echo "  Namespace: falco-behavioral-lab"
echo "  Pod:       attacker-sim (busybox:1.36)"
echo "  Script:    /tmp/trigger-behaviors.sh"
echo ""
echo "NHIỆM VỤ:"
echo "  1. Viết Falco rule phát hiện đọc /etc/shadow, /etc/passwd:"
echo "       sudo nano /etc/falco/rules.d/behavioral-rules.yaml"
echo ""
echo "  2. Viết Falco rule phát hiện outbound network connection"
echo "     (thêm vào cùng file behavioral-rules.yaml)"
echo ""
echo "  3. Cấu hình Falco output ghi ra /tmp/falco-alerts.log:"
echo "       sudo nano /etc/falco/falco.yaml"
echo "     Tìm section 'file_output' và set enabled: true"
echo ""
echo "  4. Restart Falco để load rule mới:"
echo "       sudo systemctl restart falco"
echo ""
echo "  5. Trigger behaviors:"
echo "       bash /tmp/trigger-behaviors.sh"
echo ""
echo "  6. Xác minh alert trong log:"
echo "       cat /tmp/falco-alerts.log"
echo ""
echo "  7. Chạy verify.sh để kiểm tra kết quả:"
echo "       bash verify.sh"
echo ""
echo "Dọn dẹp sau khi hoàn thành:"
echo "  bash cleanup.sh"
echo ""
