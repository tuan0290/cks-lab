#!/bin/bash
# Lab 4.4 – RuntimeClass Sandbox
# Script dọn dẹp môi trường lab

echo "=========================================="
echo " Lab 4.4 – Dọn dẹp môi trường"
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

# --- Xóa namespace runtime-lab ---

echo "Xóa namespace runtime-lab (bao gồm tất cả tài nguyên bên trong)..."

if kubectl get namespace runtime-lab &>/dev/null; then
  kubectl delete namespace runtime-lab --ignore-not-found=true
  echo "[OK] Namespace 'runtime-lab' đã được xóa."
else
  echo "[SKIP] Namespace 'runtime-lab' không tồn tại."
fi

# --- Xóa RuntimeClass gvisor ---

echo ""
echo "Xóa RuntimeClass 'gvisor'..."

if kubectl get runtimeclass gvisor &>/dev/null; then
  kubectl delete runtimeclass gvisor --ignore-not-found=true
  echo "[OK] RuntimeClass 'gvisor' đã được xóa."
else
  echo "[SKIP] RuntimeClass 'gvisor' không tồn tại."
fi

# --- Xóa file tạm ---

if [ -f /tmp/gvisor-runtimeclass.yaml ]; then
  rm -f /tmp/gvisor-runtimeclass.yaml
  echo "[OK] File /tmp/gvisor-runtimeclass.yaml đã được xóa."
fi

echo ""
echo "=========================================="
echo " Dọn dẹp hoàn tất!"
echo "=========================================="
echo ""
echo "Cluster đã được reset về trạng thái ban đầu."
echo "Bạn có thể chạy lại setup.sh để bắt đầu lại bài lab."
echo ""
