#!/bin/bash
# Lab 3.1 – AppArmor
# Script dọn dẹp môi trường lab

echo "=========================================="
echo " Lab 3.1 – Dọn dẹp môi trường"
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

# --- Xóa namespace apparmor-lab (bao gồm tất cả tài nguyên bên trong) ---

echo "Xóa namespace apparmor-lab (bao gồm tất cả tài nguyên bên trong)..."

if kubectl get namespace apparmor-lab &>/dev/null; then
  kubectl delete namespace apparmor-lab --ignore-not-found=true
  echo "[OK] Namespace 'apparmor-lab' đã được xóa."
else
  echo "[SKIP] Namespace 'apparmor-lab' không tồn tại."
fi

# --- Xóa AppArmor profile file tại /tmp/k8s-deny-write ---

echo ""
echo "Xóa AppArmor profile file /tmp/k8s-deny-write (nếu tồn tại)..."

if [ -f /tmp/k8s-deny-write ]; then
  rm -f /tmp/k8s-deny-write
  echo "[OK] File /tmp/k8s-deny-write đã được xóa."
else
  echo "[SKIP] File /tmp/k8s-deny-write không tồn tại."
fi

# --- Hướng dẫn unload profile trên node ---

echo ""
echo "=========================================="
echo " Dọn dẹp hoàn tất!"
echo "=========================================="
echo ""
echo "Cluster đã được reset về trạng thái ban đầu."
echo ""
echo "Lưu ý: AppArmor profile 'k8s-deny-write' vẫn còn được load trong kernel"
echo "trên node worker. Để unload profile, SSH vào node và chạy:"
echo ""
echo "  sudo apparmor_parser -R /tmp/k8s-deny-write"
echo ""
echo "Hoặc nếu file đã bị xóa, dùng tên profile trực tiếp:"
echo ""
echo "  sudo aa-remove-unknown"
echo ""
echo "Bạn có thể chạy lại setup.sh để bắt đầu lại bài lab."
echo ""
