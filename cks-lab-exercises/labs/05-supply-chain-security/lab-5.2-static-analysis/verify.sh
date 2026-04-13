#!/bin/bash
# Lab 5.2 – Static Analysis
# Script kiểm tra kết quả bài lab

PASS=0
FAIL=0
FAILED=0

echo "=========================================="
echo " Lab 5.2 – Kiểm tra kết quả"
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

# --- Tiêu chí 1: File /tmp/fixed-manifest.yaml tồn tại ---

echo "Kiểm tra tiêu chí 1: File /tmp/fixed-manifest.yaml tồn tại"

if [ -f /tmp/fixed-manifest.yaml ]; then
  pass "File /tmp/fixed-manifest.yaml tồn tại"
else
  fail "File /tmp/fixed-manifest.yaml không tìm thấy" \
       "Tạo manifest đã sửa: cp /tmp/insecure-manifest.yaml /tmp/fixed-manifest.yaml && nano /tmp/fixed-manifest.yaml"
fi

echo ""

# --- Tiêu chí 2: fixed-manifest.yaml không chứa privileged: true ---

echo "Kiểm tra tiêu chí 2: /tmp/fixed-manifest.yaml không chứa 'privileged: true'"

if [ ! -f /tmp/fixed-manifest.yaml ]; then
  fail "Không thể kiểm tra: /tmp/fixed-manifest.yaml không tồn tại" ""
elif grep -q "privileged:\s*true" /tmp/fixed-manifest.yaml; then
  fail "File /tmp/fixed-manifest.yaml vẫn chứa 'privileged: true'" \
       "Sửa securityContext: đặt 'privileged: false' hoặc xóa dòng đó"
else
  pass "File /tmp/fixed-manifest.yaml không chứa 'privileged: true'"
fi

echo ""

# --- Tiêu chí 3: fixed-manifest.yaml không chứa hostPID: true ---

echo "Kiểm tra tiêu chí 3: /tmp/fixed-manifest.yaml không chứa 'hostPID: true'"

if [ ! -f /tmp/fixed-manifest.yaml ]; then
  fail "Không thể kiểm tra: /tmp/fixed-manifest.yaml không tồn tại" ""
elif grep -q "hostPID:\s*true" /tmp/fixed-manifest.yaml; then
  fail "File /tmp/fixed-manifest.yaml vẫn chứa 'hostPID: true'" \
       "Sửa spec: đặt 'hostPID: false' hoặc xóa dòng đó"
else
  pass "File /tmp/fixed-manifest.yaml không chứa 'hostPID: true'"
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
  echo "Chúc mừng! Bạn đã hoàn thành Lab 5.2."
  echo "Tiếp theo: Đọc phần 'Giải thích' trong README.md"
  echo "Dọn dẹp: bash cleanup.sh"
  exit 0
fi
