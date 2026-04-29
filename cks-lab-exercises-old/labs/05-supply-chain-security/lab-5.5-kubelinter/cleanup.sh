#!/bin/bash
# Lab 5.5 – KubeLinter Static Analysis
# Script dọn dẹp môi trường lab

echo "=========================================="
echo " Lab 5.5 – Dọn dẹp môi trường"
echo "=========================================="
echo ""

# --- Xóa thư mục lab ---

if [ -d /tmp/kubelinter-lab ]; then
  rm -rf /tmp/kubelinter-lab
  echo "[OK] Thư mục /tmp/kubelinter-lab/ đã được xóa."
else
  echo "[SKIP] Thư mục /tmp/kubelinter-lab/ không tồn tại."
fi

echo ""
echo "=========================================="
echo " Dọn dẹp hoàn tất!"
echo "=========================================="
echo ""
echo "Bạn có thể chạy lại setup.sh để bắt đầu lại bài lab."
echo ""
