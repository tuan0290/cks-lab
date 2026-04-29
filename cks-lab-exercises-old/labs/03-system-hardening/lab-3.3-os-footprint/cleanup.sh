#!/bin/bash
# Lab 3.3 – Minimize OS Footprint
# Script dọn dẹp môi trường lab

echo "=========================================="
echo " Lab 3.3 – Dọn dẹp môi trường"
echo "=========================================="
echo ""

# --- Xóa file output ---

echo "Xóa file output /tmp/unnecessary-packages.txt..."
if [ -f /tmp/unnecessary-packages.txt ]; then
  rm -f /tmp/unnecessary-packages.txt
  echo "[OK] File /tmp/unnecessary-packages.txt đã được xóa."
else
  echo "[SKIP] File /tmp/unnecessary-packages.txt không tồn tại."
fi

echo ""
echo "Xóa file output /tmp/open-ports.txt..."
if [ -f /tmp/open-ports.txt ]; then
  rm -f /tmp/open-ports.txt
  echo "[OK] File /tmp/open-ports.txt đã được xóa."
else
  echo "[SKIP] File /tmp/open-ports.txt không tồn tại."
fi

# --- Re-enable và xóa lab-dummy.service ---

echo ""
echo "Dọn dẹp lab-dummy.service..."

DUMMY_SERVICE_FILE="/etc/systemd/system/lab-dummy.service"

if [ -f "$DUMMY_SERVICE_FILE" ]; then
  if [ "$EUID" -eq 0 ]; then
    # Dừng service nếu đang chạy
    systemctl stop lab-dummy.service 2>/dev/null || true
    # Disable service
    systemctl disable lab-dummy.service 2>/dev/null || true
    # Xóa file service
    rm -f "$DUMMY_SERVICE_FILE"
    systemctl daemon-reload
    echo "[OK] lab-dummy.service đã được dừng, disable và xóa."
  else
    echo "[WARN] Cần quyền root để xóa lab-dummy.service."
    echo "       Chạy: sudo bash cleanup.sh"
  fi
else
  echo "[SKIP] lab-dummy.service không tồn tại."
fi

# --- Tóm tắt ---

echo ""
echo "=========================================="
echo " Dọn dẹp hoàn tất!"
echo "=========================================="
echo ""
echo "Các tài nguyên đã được dọn dẹp:"
echo "  - /tmp/unnecessary-packages.txt"
echo "  - /tmp/open-ports.txt"
echo "  - lab-dummy.service"
echo ""
echo "Bạn có thể chạy lại sudo bash setup.sh để bắt đầu lại bài lab."
echo ""
