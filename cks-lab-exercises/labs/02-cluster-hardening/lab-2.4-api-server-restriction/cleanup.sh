#!/bin/bash
# Lab 2.4 – Restrict API Server Access
# Script dọn dẹp môi trường lab

echo "=========================================="
echo " Lab 2.4 – Dọn dẹp môi trường"
echo "=========================================="
echo ""

# --- Xóa file kết quả kiểm tra ---

echo "Xóa file kết quả kiểm tra..."

if [ -f "/tmp/api-server-check.txt" ]; then
  rm -f /tmp/api-server-check.txt
  echo "[OK] Đã xóa /tmp/api-server-check.txt"
else
  echo "[SKIP] /tmp/api-server-check.txt không tồn tại."
fi

echo ""
echo "Lưu ý quan trọng:"
echo "  Bài lab này yêu cầu sửa /etc/kubernetes/manifests/kube-apiserver.yaml."
echo "  Các thay đổi bảo mật (--anonymous-auth=false, NodeRestriction) là"
echo "  best practice và KHÔNG nên hoàn tác trong môi trường production."
echo ""
echo "  Nếu muốn khôi phục cấu hình gốc (chỉ dùng cho lab):"
echo "  sudo cp /tmp/kube-apiserver.yaml.bak /etc/kubernetes/manifests/kube-apiserver.yaml"
echo ""
echo "=========================================="
echo " Dọn dẹp hoàn tất!"
echo "=========================================="
echo ""
