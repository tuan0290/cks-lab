#!/bin/bash
# Lab 4.4 – RuntimeClass Sandbox
# Script khởi tạo môi trường lab

set -e

echo "=========================================="
echo " Lab 4.4 – RuntimeClass Sandbox"
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

# --- Kiểm tra RuntimeClass API ---

if ! kubectl api-resources | grep -q "runtimeclasses"; then
  echo "[ERROR] RuntimeClass API không khả dụng trên cluster này."
  echo "        Yêu cầu Kubernetes >= 1.14 với RuntimeClass feature gate được bật."
  exit 1
fi

echo "[OK] RuntimeClass API khả dụng."

# --- Tạo namespace runtime-lab ---

echo ""
echo "Tạo namespace runtime-lab..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: runtime-lab
  labels:
    lab: "4.4"
    purpose: runtime-class
EOF

echo "[OK] Namespace 'runtime-lab' đã được tạo."

# --- Tạo RuntimeClass manifest tại /tmp/gvisor-runtimeclass.yaml ---

echo ""
echo "Tạo RuntimeClass manifest tại /tmp/gvisor-runtimeclass.yaml..."

cat > /tmp/gvisor-runtimeclass.yaml <<EOF
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc
EOF

echo "[OK] RuntimeClass manifest đã được tạo tại /tmp/gvisor-runtimeclass.yaml"

echo ""
echo "=========================================="
echo " Môi trường đã sẵn sàng!"
echo "=========================================="
echo ""
echo "Tài nguyên đã tạo:"
echo "  Namespace:        runtime-lab"
echo "  RuntimeClass:     /tmp/gvisor-runtimeclass.yaml (chưa apply)"
echo ""
echo "NHIỆM VỤ:"
echo "  1. Tạo RuntimeClass 'gvisor' với handler 'runsc':"
echo "       kubectl apply -f /tmp/gvisor-runtimeclass.yaml"
echo "       # Hoặc: kubectl apply -f - <<EOF"
echo "       # apiVersion: node.k8s.io/v1"
echo "       # kind: RuntimeClass"
echo "       # metadata:"
echo "       #   name: gvisor"
echo "       # handler: runsc"
echo "       # EOF"
echo ""
echo "  2. Tạo pod 'sandboxed-pod' trong namespace 'runtime-lab' với runtimeClassName: gvisor"
echo ""
echo "  3. Chạy verify.sh để kiểm tra kết quả:"
echo "       bash verify.sh"
echo ""
echo "Lưu ý: Nếu gVisor chưa được cài đặt trên node, pod sẽ ở trạng thái Pending."
echo "Bài lab tập trung vào cấu hình đúng RuntimeClass và pod spec."
echo ""
echo "Xem README.md để biết hướng dẫn chi tiết."
echo ""
echo "Dọn dẹp sau khi hoàn thành:"
echo "  bash cleanup.sh"
echo ""
