#!/bin/bash
# Lab 3.2 – Seccomp
# Script dọn dẹp môi trường lab

echo "=========================================="
echo " Lab 3.2 – Dọn dẹp môi trường"
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

# --- Xóa namespace seccomp-lab (bao gồm tất cả tài nguyên bên trong) ---

echo "Xóa namespace seccomp-lab (bao gồm tất cả tài nguyên bên trong)..."

if kubectl get namespace seccomp-lab &>/dev/null; then
  kubectl delete namespace seccomp-lab --ignore-not-found=true
  echo "[OK] Namespace 'seccomp-lab' đã được xóa."
else
  echo "[SKIP] Namespace 'seccomp-lab' không tồn tại."
fi

# --- Xóa Seccomp profile file tại /tmp/deny-write.json ---

echo ""
echo "Xóa Seccomp profile file /tmp/deny-write.json (nếu tồn tại)..."

if [ -f /tmp/deny-write.json ]; then
  rm -f /tmp/deny-write.json
  echo "[OK] File /tmp/deny-write.json đã được xóa."
else
  echo "[SKIP] File /tmp/deny-write.json không tồn tại."
fi

# --- Hướng dẫn xóa profile trên node ---

echo ""
echo "=========================================="
echo " Dọn dẹp hoàn tất!"
echo "=========================================="
echo ""
echo "Cluster đã được reset về trạng thái ban đầu."
echo ""
echo "Lưu ý: Seccomp profile 'deny-write.json' vẫn còn trên node worker."
echo "Để xóa profile trên node, SSH vào node và chạy:"
echo ""
echo "  ssh <user>@<node-ip> 'sudo rm -f /var/lib/kubelet/seccomp/profiles/deny-write.json'"
echo ""
echo "Bạn có thể chạy lại setup.sh để bắt đầu lại bài lab."
echo ""
