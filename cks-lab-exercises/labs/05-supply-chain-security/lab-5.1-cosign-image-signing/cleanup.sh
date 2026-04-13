#!/bin/bash
# Lab 5.1 – cosign Image Signing
# Script dọn dẹp môi trường lab

echo "=========================================="
echo " Lab 5.1 – Dọn dẹp môi trường"
echo "=========================================="
echo ""

if ! command -v kubectl &>/dev/null; then
  echo "[ERROR] kubectl không tìm thấy."
  exit 1
fi

if ! kubectl cluster-info &>/dev/null; then
  echo "[ERROR] Không thể kết nối đến cluster."
  exit 1
fi

# --- Xóa namespace cosign-lab ---

echo "Xóa namespace cosign-lab..."

if kubectl get namespace cosign-lab &>/dev/null; then
  kubectl delete namespace cosign-lab --ignore-not-found=true
  echo "[OK] Namespace 'cosign-lab' đã được xóa."
else
  echo "[SKIP] Namespace 'cosign-lab' không tồn tại."
fi

# --- Xóa thư mục /tmp/cosign-lab ---

if [ -d /tmp/cosign-lab ]; then
  rm -rf /tmp/cosign-lab
  echo "[OK] Thư mục /tmp/cosign-lab đã được xóa."
else
  echo "[SKIP] Thư mục /tmp/cosign-lab không tồn tại."
fi

echo ""
echo "=========================================="
echo " Dọn dẹp hoàn tất!"
echo "=========================================="
echo ""
echo "Cluster đã được reset về trạng thái ban đầu."
echo "Bạn có thể chạy lại setup.sh để bắt đầu lại bài lab."
echo ""
