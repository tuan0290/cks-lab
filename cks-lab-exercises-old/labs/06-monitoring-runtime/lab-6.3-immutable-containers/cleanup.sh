#!/bin/bash
# Lab 6.3 – Immutable Containers
# Script dọn dẹp môi trường lab

echo "=========================================="
echo " Lab 6.3 – Dọn dẹp môi trường"
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

# --- Xóa namespace immutable-lab ---

echo "Xóa namespace immutable-lab (bao gồm tất cả tài nguyên bên trong)..."

if kubectl get namespace immutable-lab &>/dev/null; then
  kubectl delete namespace immutable-lab --ignore-not-found=true
  echo "[OK] Namespace 'immutable-lab' đã được xóa."
else
  echo "[SKIP] Namespace 'immutable-lab' không tồn tại."
fi

echo ""
echo "=========================================="
echo " Dọn dẹp hoàn tất!"
echo "=========================================="
echo ""
echo "Cluster đã được reset về trạng thái ban đầu."
echo "Bạn có thể chạy lại setup.sh để bắt đầu lại bài lab."
echo ""
