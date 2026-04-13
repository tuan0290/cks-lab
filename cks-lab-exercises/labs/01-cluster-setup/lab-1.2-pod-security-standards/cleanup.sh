#!/bin/bash
# Lab 1.2 – Pod Security Standards (PSS)
# Script dọn dẹp môi trường lab

echo "=========================================="
echo " Lab 1.2 – Dọn dẹp môi trường"
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

echo "Xóa namespaces (bao gồm tất cả tài nguyên bên trong)..."

for NS in pss-lab pss-baseline; do
  if kubectl get namespace "$NS" &>/dev/null; then
    kubectl delete namespace "$NS" --ignore-not-found=true
    echo "[OK] Namespace '$NS' đã được xóa."
  else
    echo "[SKIP] Namespace '$NS' không tồn tại."
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
