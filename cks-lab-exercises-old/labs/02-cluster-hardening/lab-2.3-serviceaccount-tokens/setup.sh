#!/bin/bash
# Lab 2.3 – ServiceAccount Token Automount
# Script khởi tạo môi trường lab

set -e

echo "=========================================="
echo " Lab 2.3 – ServiceAccount Token Automount"
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

# --- Tạo namespace token-lab ---

echo ""
echo "Tạo namespace token-lab..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: token-lab
  labels:
    lab: "2.3"
    purpose: serviceaccount-tokens
EOF

echo "[OK] Namespace 'token-lab' đã được tạo."

# --- Tạo ServiceAccount web-sa với automount mặc định (true) ---

echo ""
echo "Tạo ServiceAccount web-sa (automount mặc định: true)..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: web-sa
  namespace: token-lab
  labels:
    lab: "2.3"
automountServiceAccountToken: true
EOF

echo "[OK] ServiceAccount 'web-sa' đã được tạo với automountServiceAccountToken: true."

# --- Tạo pod web-app sử dụng web-sa (token được mount mặc định) ---

echo ""
echo "Tạo pod web-app (token được mount mặc định)..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: web-app
  namespace: token-lab
  labels:
    lab: "2.3"
    app: web-app
spec:
  serviceAccountName: web-sa
  containers:
  - name: web-app
    image: nginx:alpine
    ports:
    - containerPort: 80
EOF

echo "[OK] Pod 'web-app' đã được tạo."

# --- Chờ pod Running ---

echo ""
echo "Chờ pod web-app sẵn sàng..."

kubectl wait --for=condition=Ready pod/web-app -n token-lab --timeout=90s 2>/dev/null \
  && echo "[OK] Pod 'web-app' đang chạy." \
  || echo "[WARN] Pod chưa Ready sau 90s — tiếp tục. Kiểm tra: kubectl get pod web-app -n token-lab"

# --- Tóm tắt ---

echo ""
echo "=========================================="
echo " Môi trường đã sẵn sàng!"
echo "=========================================="
echo ""
echo "Tài nguyên đã tạo:"
echo "  Namespace:      token-lab"
echo "  ServiceAccount: web-sa (automountServiceAccountToken: true)"
echo "  Pod:            web-app (dùng web-sa, token đang được mount)"
echo ""
echo "Kiểm tra trạng thái ban đầu:"
echo "  kubectl get serviceaccount web-sa -n token-lab -o yaml"
echo "  kubectl get pod web-app -n token-lab -o yaml"
echo "  kubectl exec web-app -n token-lab -- ls /var/run/secrets/kubernetes.io/serviceaccount/"
echo ""
echo "Nhiệm vụ của bạn:"
echo "  1. Vô hiệu hóa automount token trên ServiceAccount web-sa:"
echo "     kubectl patch serviceaccount web-sa -n token-lab \\"
echo "       -p '{\"automountServiceAccountToken\": false}'"
echo ""
echo "  2. Xóa và tạo lại pod web-app với automountServiceAccountToken: false"
echo "     (Pod spec là immutable — phải xóa và tạo lại)"
echo ""
echo "  3. Xác minh token không còn trong pod:"
echo "     kubectl exec web-app -n token-lab -- \\"
echo "       ls /var/run/secrets/kubernetes.io/serviceaccount/ 2>&1"
echo ""
echo "Kiểm tra kết quả:"
echo "  bash verify.sh"
echo ""
echo "Dọn dẹp sau khi hoàn thành:"
echo "  bash cleanup.sh"
echo ""
