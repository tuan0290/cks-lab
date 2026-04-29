#!/bin/bash
# Lab 6.1 – Falco Rules
# Script dọn dẹp môi trường lab

echo "=========================================="
echo " Lab 6.1 – Dọn dẹp môi trường"
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

# --- Xóa namespace falco-lab ---

echo "Xóa namespace falco-lab..."

if kubectl get namespace falco-lab &>/dev/null; then
  kubectl delete namespace falco-lab --ignore-not-found=true
  echo "[OK] Namespace 'falco-lab' đã được xóa."
else
  echo "[SKIP] Namespace 'falco-lab' không tồn tại."
fi

# --- Xóa file tạm ---

if [ -f /tmp/custom-rules.yaml ]; then
  rm -f /tmp/custom-rules.yaml
  echo "[OK] File /tmp/custom-rules.yaml đã được xóa."
else
  echo "[SKIP] File /tmp/custom-rules.yaml không tồn tại."
fi

# --- Thông báo về custom rule đã copy ---

if [ -f /etc/falco/rules.d/custom-rules.yaml ]; then
  echo ""
  echo "[INFO] File /etc/falco/rules.d/custom-rules.yaml vẫn còn."
  echo "       Để xóa: sudo rm /etc/falco/rules.d/custom-rules.yaml && sudo systemctl restart falco"
fi

echo ""
echo "=========================================="
echo " Dọn dẹp hoàn tất!"
echo "=========================================="
echo ""
echo "Cluster đã được reset về trạng thái ban đầu."
echo "Bạn có thể chạy lại setup.sh để bắt đầu lại bài lab."
echo ""
