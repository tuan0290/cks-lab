#!/bin/bash
# Lab 1.1 – NetworkPolicy Default Deny
# Script dọn dẹp môi trường lab

echo "=========================================="
echo " Lab 1.1 – Dọn dẹp môi trường"
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

for NS in lab-network frontend-ns backend-ns; do
  if kubectl get namespace "$NS" &>/dev/null; then
    kubectl delete namespace "$NS" --ignore-not-found=true
    echo "[OK] Namespace '$NS' đã được xóa."
  else
    echo "[SKIP] Namespace '$NS' không tồn tại."
  fi
done

echo ""
echo "Xóa pod trong default namespace..."

kubectl delete pod default-curl-pod -n default --ignore-not-found=true
echo "[OK] default-curl-pod đã được xóa."

echo ""
echo "=========================================="
echo " Dọn dẹp hoàn tất!"
echo "=========================================="
echo ""
echo "Cluster đã được reset về trạng thái ban đầu."
echo "Bạn có thể chạy lại setup.sh để bắt đầu lại bài lab."
echo ""
