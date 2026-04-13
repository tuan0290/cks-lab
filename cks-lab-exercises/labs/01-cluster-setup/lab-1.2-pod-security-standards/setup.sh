#!/bin/bash
# Lab 1.2 – Pod Security Standards (PSS)
# Script khởi tạo môi trường lab

set -e

echo "=========================================="
echo " Lab 1.2 – Pod Security Standards (PSS)"
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

# --- Tạo namespace pss-lab (KHÔNG có PSS labels — học viên sẽ tự thêm) ---

echo ""
echo "Tạo namespace pss-lab (chưa có PSS labels)..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: pss-lab
  labels:
    lab: "1.2"
    purpose: pss-lab
EOF

echo "[OK] Namespace 'pss-lab' đã được tạo (chưa có PSS enforcement)."

# --- Tạo namespace pss-baseline với PSS baseline (để so sánh) ---

echo ""
echo "Tạo namespace pss-baseline với PSS level baseline..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: pss-baseline
  labels:
    lab: "1.2"
    purpose: pss-comparison
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/enforce-version: latest
EOF

echo "[OK] Namespace 'pss-baseline' đã được tạo với PSS enforce=baseline."

# --- Tóm tắt ---

echo ""
echo "=========================================="
echo " Môi trường đã sẵn sàng!"
echo "=========================================="
echo ""
echo "Tài nguyên đã tạo:"
echo "  Namespace: pss-lab      (chưa có PSS labels — bạn sẽ tự thêm)"
echo "  Namespace: pss-baseline (PSS enforce=baseline — để so sánh)"
echo ""
echo "Bước tiếp theo:"
echo "  1. Đọc README.md để hiểu yêu cầu bài lab"
echo "  2. Gắn nhãn PSS restricted lên namespace pss-lab:"
echo "     kubectl label namespace pss-lab \\"
echo "       pod-security.kubernetes.io/enforce=restricted \\"
echo "       pod-security.kubernetes.io/enforce-version=latest"
echo "  3. Thử deploy pod vi phạm và xác nhận bị từ chối"
echo "  4. Chạy verify.sh để kiểm tra kết quả:"
echo "     bash verify.sh"
echo ""
echo "Dọn dẹp sau khi hoàn thành:"
echo "  bash cleanup.sh"
echo ""
