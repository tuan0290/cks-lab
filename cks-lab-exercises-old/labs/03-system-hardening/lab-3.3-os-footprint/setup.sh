#!/bin/bash
# Lab 3.3 – Minimize OS Footprint
# Script khởi tạo môi trường lab

set -e

echo "=========================================="
echo " Lab 3.3 – Minimize OS Footprint"
echo " Đang khởi tạo môi trường..."
echo "=========================================="

# --- Kiểm tra quyền root ---

if [ "$EUID" -ne 0 ]; then
  echo "[WARN] Script này nên chạy với quyền root để cài package và tạo service."
  echo "       Một số bước có thể thất bại nếu không có quyền root."
  echo "       Khuyến nghị: sudo bash setup.sh"
  echo ""
fi

# --- Kiểm tra package manager ---

if ! command -v dpkg &>/dev/null && ! command -v rpm &>/dev/null; then
  echo "[ERROR] Không tìm thấy dpkg hoặc rpm."
  echo "        Lab này yêu cầu Debian/Ubuntu hoặc RHEL/CentOS."
  exit 1
fi

if command -v dpkg &>/dev/null; then
  PKG_MANAGER="apt"
  echo "[OK] Phát hiện hệ thống Debian/Ubuntu (dpkg)."
else
  PKG_MANAGER="yum"
  echo "[OK] Phát hiện hệ thống RHEL/CentOS (rpm)."
fi

# --- Cài đặt package không cần thiết để học viên thực hành ---

echo ""
echo "Cài đặt package không cần thiết (telnet, nmap, netcat-openbsd)..."

if [ "$PKG_MANAGER" = "apt" ]; then
  # Cập nhật package list nếu cần
  if [ "$EUID" -eq 0 ]; then
    apt-get update -qq 2>/dev/null || true

    # Cài telnet nếu chưa có
    if ! dpkg -l telnet 2>/dev/null | grep -q "^ii"; then
      apt-get install -y telnet 2>/dev/null || echo "[WARN] Không thể cài telnet."
    else
      echo "[SKIP] telnet đã được cài đặt."
    fi

    # Cài nmap nếu chưa có
    if ! dpkg -l nmap 2>/dev/null | grep -q "^ii"; then
      apt-get install -y nmap 2>/dev/null || echo "[WARN] Không thể cài nmap."
    else
      echo "[SKIP] nmap đã được cài đặt."
    fi

    # Cài netcat-openbsd nếu chưa có
    if ! dpkg -l netcat-openbsd 2>/dev/null | grep -q "^ii"; then
      apt-get install -y netcat-openbsd 2>/dev/null || echo "[WARN] Không thể cài netcat-openbsd."
    else
      echo "[SKIP] netcat-openbsd đã được cài đặt."
    fi
  else
    echo "[SKIP] Bỏ qua cài package (cần quyền root)."
  fi
else
  if [ "$EUID" -eq 0 ]; then
    # RHEL/CentOS
    if ! rpm -q telnet &>/dev/null; then
      yum install -y telnet 2>/dev/null || echo "[WARN] Không thể cài telnet."
    else
      echo "[SKIP] telnet đã được cài đặt."
    fi

    if ! rpm -q nmap &>/dev/null; then
      yum install -y nmap 2>/dev/null || echo "[WARN] Không thể cài nmap."
    else
      echo "[SKIP] nmap đã được cài đặt."
    fi

    if ! rpm -q nc &>/dev/null; then
      yum install -y nc 2>/dev/null || echo "[WARN] Không thể cài nc."
    else
      echo "[SKIP] nc đã được cài đặt."
    fi
  else
    echo "[SKIP] Bỏ qua cài package (cần quyền root)."
  fi
fi

echo "[OK] Bước cài package hoàn tất."

# --- Tạo dummy systemd service để học viên thực hành disable ---

echo ""
echo "Tạo dummy service 'lab-dummy.service'..."

DUMMY_SERVICE_FILE="/etc/systemd/system/lab-dummy.service"

if [ "$EUID" -eq 0 ]; then
  if [ ! -f "$DUMMY_SERVICE_FILE" ]; then
    cat > "$DUMMY_SERVICE_FILE" <<'EOF'
[Unit]
Description=Lab Dummy Service (CKS Lab 3.3 - Minimize OS Footprint)
After=network.target

[Service]
Type=simple
ExecStart=/bin/sleep infinity
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable lab-dummy.service 2>/dev/null || true
    systemctl start lab-dummy.service 2>/dev/null || true
    echo "[OK] lab-dummy.service đã được tạo và bật."
  else
    echo "[SKIP] lab-dummy.service đã tồn tại."
    # Đảm bảo service đang enabled và running
    systemctl enable lab-dummy.service 2>/dev/null || true
    systemctl start lab-dummy.service 2>/dev/null || true
  fi
else
  echo "[SKIP] Bỏ qua tạo systemd service (cần quyền root)."
fi

# --- Hướng dẫn ---

echo ""
echo "=========================================="
echo " Môi trường đã sẵn sàng!"
echo "=========================================="
echo ""
echo "Tài nguyên đã tạo:"
echo "  Package cài thêm: telnet, nmap, netcat-openbsd"
echo "  Dummy service:    lab-dummy.service (enabled + running)"
echo ""
echo "BƯỚC TIẾP THEO — Thực hiện bài lab:"
echo ""
echo "  1. Liệt kê package không cần thiết:"
echo "     dpkg --list | grep -E 'telnet|nmap|netcat' | tee /tmp/unnecessary-packages.txt"
echo ""
echo "  2. Disable dummy service:"
echo "     sudo systemctl disable --now lab-dummy.service"
echo ""
echo "  3. Kiểm tra port đang mở:"
echo "     ss -tlnp | tee /tmp/open-ports.txt"
echo ""
echo "  4. Chạy verify script:"
echo "     bash verify.sh"
echo ""
echo "Dọn dẹp sau khi hoàn thành:"
echo "  sudo bash cleanup.sh"
echo ""
