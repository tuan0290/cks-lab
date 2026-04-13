#!/bin/bash
# Lab 1.4 – CIS Benchmark với kube-bench
# Script dọn dẹp môi trường lab

echo "=========================================="
echo " Lab 1.4 – Dọn dẹp môi trường"
echo "=========================================="
echo ""

if ! command -v kubectl &>/dev/null; then
  echo "[ERROR] kubectl không tìm thấy."
  exit 1
fi

# --- Xóa file kết quả kube-bench tạm thời ---

echo "Xóa file kết quả tạm thời..."

for f in /tmp/kube-bench-master.txt /tmp/kube-bench-etcd.txt /tmp/kube-bench-node.txt; do
  if [ -f "$f" ]; then
    rm -f "$f"
    echo "[OK] Đã xóa $f"
  fi
done

echo ""
echo "Lưu ý quan trọng:"
echo "  Bài lab này yêu cầu sửa /etc/kubernetes/manifests/kube-apiserver.yaml."
echo "  Các thay đổi (--profiling=false, --anonymous-auth=false) là cấu hình"
echo "  bảo mật tốt và KHÔNG nên hoàn tác."
echo ""
echo "  Nếu muốn khôi phục cấu hình gốc (không khuyến nghị):"
echo "  sudo cp /tmp/kube-apiserver.yaml.bak /etc/kubernetes/manifests/kube-apiserver.yaml"
echo ""
echo "=========================================="
echo " Dọn dẹp hoàn tất!"
echo "=========================================="
echo ""
