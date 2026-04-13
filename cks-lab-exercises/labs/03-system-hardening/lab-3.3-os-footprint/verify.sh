#!/bin/bash
# Lab 3.3 – Minimize OS Footprint
# Script kiểm tra kết quả bài lab

PASS=0
FAIL=0
FAILED=0

echo "=========================================="
echo " Lab 3.3 – Kiểm tra kết quả"
echo "=========================================="
echo ""

# --- Hàm tiện ích ---

pass() {
  echo "[PASS] $1"
  PASS=$((PASS + 1))
}

fail() {
  echo "[FAIL] $1"
  if [ -n "$2" ]; then
    echo "       Gợi ý: $2"
  fi
  FAIL=$((FAIL + 1))
  FAILED=1
}

# --- Tiêu chí 1: File /tmp/unnecessary-packages.txt tồn tại và không rỗng ---

echo "Kiểm tra tiêu chí 1: File /tmp/unnecessary-packages.txt tồn tại và không rỗng"

if [ -f /tmp/unnecessary-packages.txt ]; then
  if [ -s /tmp/unnecessary-packages.txt ]; then
    LINE_COUNT=$(wc -l < /tmp/unnecessary-packages.txt)
    pass "File /tmp/unnecessary-packages.txt tồn tại và có ${LINE_COUNT} dòng"
  else
    fail "File /tmp/unnecessary-packages.txt tồn tại nhưng rỗng" \
         "Chạy: dpkg --list | grep -E 'telnet|nmap|netcat' > /tmp/unnecessary-packages.txt"
  fi
else
  fail "File /tmp/unnecessary-packages.txt không tồn tại" \
       "Chạy: dpkg --list | grep -E 'telnet|nmap|netcat' | tee /tmp/unnecessary-packages.txt"
fi

echo ""

# --- Tiêu chí 2: Ít nhất 1 service đã được disable ---

echo "Kiểm tra tiêu chí 2: Ít nhất 1 service đã được disable"

SERVICE_DISABLED=0

# Kiểm tra lab-dummy.service trước (service được tạo bởi setup.sh)
if systemctl is-enabled lab-dummy.service &>/dev/null 2>&1; then
  STATUS=$(systemctl is-enabled lab-dummy.service 2>/dev/null)
  if [ "$STATUS" = "disabled" ]; then
    pass "lab-dummy.service đã được disable (systemctl is-enabled → disabled)"
    SERVICE_DISABLED=1
  fi
fi

# Nếu lab-dummy chưa disabled, kiểm tra các service phổ biến khác
if [ "$SERVICE_DISABLED" -eq 0 ]; then
  for SVC in snapd bluetooth avahi-daemon cups rpcbind; do
    if systemctl list-unit-files "${SVC}.service" &>/dev/null 2>&1 | grep -q "${SVC}"; then
      STATUS=$(systemctl is-enabled "${SVC}.service" 2>/dev/null || echo "not-found")
      if [ "$STATUS" = "disabled" ]; then
        pass "${SVC}.service đã được disable"
        SERVICE_DISABLED=1
        break
      fi
    fi
  done
fi

if [ "$SERVICE_DISABLED" -eq 0 ]; then
  fail "Không tìm thấy service nào đã được disable" \
       "Chạy: sudo systemctl disable --now lab-dummy.service"
fi

echo ""

# --- Tiêu chí 3: File /tmp/open-ports.txt tồn tại ---

echo "Kiểm tra tiêu chí 3: File /tmp/open-ports.txt tồn tại"

if [ -f /tmp/open-ports.txt ]; then
  pass "File /tmp/open-ports.txt tồn tại"
else
  fail "File /tmp/open-ports.txt không tồn tại" \
       "Chạy: ss -tlnp | tee /tmp/open-ports.txt"
fi

echo ""

# --- Tóm tắt ---

TOTAL=$((PASS + FAIL))
echo "=========================================="
echo " Kết quả: ${PASS}/${TOTAL} tiêu chí đạt"
echo "=========================================="

if [ "$FAILED" -eq 1 ]; then
  echo ""
  echo "Một số tiêu chí chưa đạt. Xem gợi ý ở trên và thử lại."
  echo "Tham khảo: README.md hoặc solution/solution.md"
  exit 1
else
  echo ""
  echo "Chúc mừng! Bạn đã hoàn thành Lab 3.3."
  echo "Tiếp theo: Đọc phần 'Giải thích' trong README.md"
  echo "Dọn dẹp: sudo bash cleanup.sh"
  exit 0
fi
