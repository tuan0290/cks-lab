#!/bin/bash
# Lab 6.4 – Behavioral Analytics với Falco
# Script dọn dẹp môi trường lab

echo "=========================================="
echo " Lab 6.4 – Dọn dẹp môi trường"
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

# --- Xóa namespace falco-behavioral-lab ---

echo "Xóa namespace falco-behavioral-lab..."

if kubectl get namespace falco-behavioral-lab &>/dev/null; then
  kubectl delete namespace falco-behavioral-lab --ignore-not-found=true
  echo "[OK] Namespace 'falco-behavioral-lab' đã được xóa."
else
  echo "[SKIP] Namespace 'falco-behavioral-lab' không tồn tại."
fi

# --- Xóa file tạm ---

if [ -f /tmp/falco-alerts.log ]; then
  rm -f /tmp/falco-alerts.log
  echo "[OK] File /tmp/falco-alerts.log đã được xóa."
else
  echo "[SKIP] File /tmp/falco-alerts.log không tồn tại."
fi

if [ -f /tmp/trigger-behaviors.sh ]; then
  rm -f /tmp/trigger-behaviors.sh
  echo "[OK] File /tmp/trigger-behaviors.sh đã được xóa."
else
  echo "[SKIP] File /tmp/trigger-behaviors.sh không tồn tại."
fi

# --- Thông báo về custom rule đã tạo ---

if ls /etc/falco/rules.d/*.yaml &>/dev/null 2>&1; then
  echo ""
  echo "[INFO] Các file rule tùy chỉnh vẫn còn trong /etc/falco/rules.d/:"
  ls /etc/falco/rules.d/*.yaml 2>/dev/null
  echo "       Để xóa: sudo rm /etc/falco/rules.d/behavioral-rules.yaml && sudo systemctl restart falco"
fi

echo ""
echo "=========================================="
echo " Dọn dẹp hoàn tất!"
echo "=========================================="
echo ""
echo "Cluster đã được reset về trạng thái ban đầu."
echo "Bạn có thể chạy lại setup.sh để bắt đầu lại bài lab."
echo ""
