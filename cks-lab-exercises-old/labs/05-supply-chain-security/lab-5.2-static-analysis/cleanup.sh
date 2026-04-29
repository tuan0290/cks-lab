#!/bin/bash
# Lab 5.2 – Static Analysis
# Script dọn dẹp môi trường lab

echo "=========================================="
echo " Lab 5.2 – Dọn dẹp môi trường"
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

# --- Xóa namespace static-lab ---

echo "Xóa namespace static-lab..."

if kubectl get namespace static-lab &>/dev/null; then
  kubectl delete namespace static-lab --ignore-not-found=true
  echo "[OK] Namespace 'static-lab' đã được xóa."
else
  echo "[SKIP] Namespace 'static-lab' không tồn tại."
fi

# --- Xóa file tạm ---

for f in /tmp/insecure-manifest.yaml /tmp/fixed-manifest.yaml; do
  if [ -f "$f" ]; then
    rm -f "$f"
    echo "[OK] File $f đã được xóa."
  else
    echo "[SKIP] File $f không tồn tại."
  fi
done

echo ""
echo "=========================================="
echo " Dọn dẹp hoàn tất!"
echo "=========================================="
echo ""
echo "Cluster đã được reset về trạng thái ban đầu."
echo "Bạn có thể chạy lại setup.sh để bắt đầu lại bài lab."
echo ""
