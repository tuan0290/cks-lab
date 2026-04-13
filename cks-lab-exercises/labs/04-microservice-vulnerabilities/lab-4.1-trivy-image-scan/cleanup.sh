#!/bin/bash
# Lab 4.1 – Trivy Image Scan
# Script dọn dẹp môi trường lab

echo "=========================================="
echo " Lab 4.1 – Dọn dẹp môi trường"
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

# --- Xóa namespace trivy-lab ---

echo "Xóa namespace trivy-lab (bao gồm tất cả tài nguyên bên trong)..."

if kubectl get namespace trivy-lab &>/dev/null; then
  kubectl delete namespace trivy-lab --ignore-not-found=true
  echo "[OK] Namespace 'trivy-lab' đã được xóa."
else
  echo "[SKIP] Namespace 'trivy-lab' không tồn tại."
fi

# --- Xóa file tạm ---

if [ -f /tmp/nginx-scan.json ]; then
  rm -f /tmp/nginx-scan.json
  echo "[OK] File /tmp/nginx-scan.json đã được xóa."
fi

echo ""
echo "=========================================="
echo " Dọn dẹp hoàn tất!"
echo "=========================================="
echo ""
echo "Cluster đã được reset về trạng thái ban đầu."
echo "Bạn có thể chạy lại setup.sh để bắt đầu lại bài lab."
echo ""
