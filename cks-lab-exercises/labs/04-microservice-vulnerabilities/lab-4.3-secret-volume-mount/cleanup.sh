#!/bin/bash
# Lab 4.3 – Secret Volume Mount
# Script dọn dẹp môi trường lab

echo "=========================================="
echo " Lab 4.3 – Dọn dẹp môi trường"
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

# --- Xóa namespace secret-lab ---

echo "Xóa namespace secret-lab (bao gồm tất cả tài nguyên bên trong)..."

if kubectl get namespace secret-lab &>/dev/null; then
  kubectl delete namespace secret-lab --ignore-not-found=true
  echo "[OK] Namespace 'secret-lab' đã được xóa."
else
  echo "[SKIP] Namespace 'secret-lab' không tồn tại."
fi

echo ""
echo "=========================================="
echo " Dọn dẹp hoàn tất!"
echo "=========================================="
echo ""
echo "Cluster đã được reset về trạng thái ban đầu."
echo "Bạn có thể chạy lại setup.sh để bắt đầu lại bài lab."
echo ""
