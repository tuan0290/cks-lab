#!/bin/bash
# Lab 5.1 – cosign Image Signing
# Script khởi tạo môi trường lab

set -e

echo "=========================================="
echo " Lab 5.1 – cosign Image Signing"
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

if ! command -v cosign &>/dev/null; then
  echo "[ERROR] cosign không tìm thấy."
  echo "        Cài đặt cosign:"
  echo "          curl -O -L https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64"
  echo "          sudo mv cosign-linux-amd64 /usr/local/bin/cosign"
  echo "          sudo chmod +x /usr/local/bin/cosign"
  echo "        Tài liệu: https://docs.sigstore.dev/cosign/system_config/installation/"
  exit 1
fi

echo "[OK] cosign đã được cài đặt: $(cosign version 2>/dev/null | head -1)"

# --- Tạo namespace cosign-lab ---

echo ""
echo "Tạo namespace cosign-lab..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: cosign-lab
  labels:
    lab: "5.1"
    purpose: cosign-image-signing
EOF

echo "[OK] Namespace 'cosign-lab' đã được tạo."

# --- Tạo thư mục làm việc ---

echo ""
echo "Tạo thư mục làm việc /tmp/cosign-lab..."
mkdir -p /tmp/cosign-lab
echo "[OK] Thư mục /tmp/cosign-lab đã sẵn sàng."

echo ""
echo "=========================================="
echo " Môi trường đã sẵn sàng!"
echo "=========================================="
echo ""
echo "Tài nguyên đã tạo:"
echo "  Namespace:  cosign-lab"
echo "  Thư mục:    /tmp/cosign-lab"
echo ""
echo "NHIỆM VỤ:"
echo "  1. Tạo cosign key pair:"
echo "       cd /tmp/cosign-lab"
echo "       cosign generate-key-pair"
echo ""
echo "  2. Ký image nginx:1.25-alpine:"
echo "       COSIGN_PASSWORD=\"\" cosign sign --key /tmp/cosign-lab/cosign.key nginx:1.25-alpine"
echo ""
echo "  3. Xác minh chữ ký:"
echo "       cosign verify --key /tmp/cosign-lab/cosign.pub nginx:1.25-alpine"
echo ""
echo "  4. Chạy verify.sh để kiểm tra kết quả:"
echo "       bash verify.sh"
echo ""
echo "Dọn dẹp sau khi hoàn thành:"
echo "  bash cleanup.sh"
echo ""
