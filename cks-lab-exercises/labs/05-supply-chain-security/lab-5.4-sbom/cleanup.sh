#!/bin/bash
# Lab 5.4 – SBOM (Software Bill of Materials)
# Script dọn dẹp môi trường lab

echo "=========================================="
echo " Lab 5.4 – Dọn dẹp môi trường"
echo "=========================================="
echo ""

# --- Xóa thư mục kết quả ---

echo "Xóa thư mục /tmp/sbom-results/..."

if [ -d "/tmp/sbom-results" ]; then
  rm -rf /tmp/sbom-results
  echo "[OK] Thư mục /tmp/sbom-results/ đã được xóa."
else
  echo "[SKIP] Thư mục /tmp/sbom-results/ không tồn tại."
fi

echo ""
echo "=========================================="
echo " Dọn dẹp hoàn tất!"
echo "=========================================="
echo ""
echo "Cluster đã được reset về trạng thái ban đầu."
echo "Bạn có thể chạy lại setup.sh để bắt đầu lại bài lab."
echo ""
