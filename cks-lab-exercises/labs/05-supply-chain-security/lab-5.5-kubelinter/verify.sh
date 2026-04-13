#!/bin/bash
# Lab 5.5 – KubeLinter Static Analysis
# Script kiểm tra kết quả bài lab

PASS=0
FAIL=0
FAILED=0

FIXED_FILE="/tmp/kubelinter-lab/fixed-deployment.yaml"

echo "=========================================="
echo " Lab 5.5 – Kiểm tra kết quả"
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

# --- Tiêu chí (a): kube-linter đã được cài đặt ---

echo "Kiểm tra tiêu chí (a): kube-linter đã được cài đặt"

if command -v kube-linter &>/dev/null; then
  pass "kube-linter đã được cài đặt"
else
  fail "kube-linter chưa được cài đặt" \
       "Cài đặt: curl -sSL https://github.com/stackrox/kube-linter/releases/latest/download/kube-linter-linux.tar.gz | tar xz && sudo mv kube-linter /usr/local/bin/"
fi

echo ""

# --- Tiêu chí (b): fixed-deployment.yaml tồn tại ---

echo "Kiểm tra tiêu chí (b): $FIXED_FILE tồn tại"

if [ -f "$FIXED_FILE" ]; then
  pass "File $FIXED_FILE tồn tại"
else
  fail "File $FIXED_FILE không tìm thấy" \
       "Tạo file: nano $FIXED_FILE (xem README.md để biết nội dung cần thiết)"
fi

echo ""

# --- Tiêu chí (c): kube-linter lint không báo lỗi run-as-non-root ---

echo "Kiểm tra tiêu chí (c): kube-linter lint không báo lỗi 'run-as-non-root'"

if ! command -v kube-linter &>/dev/null; then
  fail "Không thể kiểm tra: kube-linter chưa được cài đặt" ""
elif [ ! -f "$FIXED_FILE" ]; then
  fail "Không thể kiểm tra: $FIXED_FILE không tồn tại" ""
else
  LINT_OUTPUT=$(kube-linter lint "$FIXED_FILE" 2>&1 || true)
  if echo "$LINT_OUTPUT" | grep -q "run-as-non-root"; then
    fail "kube-linter vẫn báo lỗi 'run-as-non-root'" \
         "Thêm vào securityContext: runAsNonRoot: true và runAsUser: 1000 (hoặc UID khác != 0)"
  else
    pass "kube-linter lint không báo lỗi 'run-as-non-root'"
  fi
fi

echo ""

# --- Tiêu chí (d): kube-linter lint không báo lỗi read-only-root-filesystem ---

echo "Kiểm tra tiêu chí (d): kube-linter lint không báo lỗi 'read-only-root-filesystem'"

if ! command -v kube-linter &>/dev/null; then
  fail "Không thể kiểm tra: kube-linter chưa được cài đặt" ""
elif [ ! -f "$FIXED_FILE" ]; then
  fail "Không thể kiểm tra: $FIXED_FILE không tồn tại" ""
else
  LINT_OUTPUT=$(kube-linter lint "$FIXED_FILE" 2>&1 || true)
  if echo "$LINT_OUTPUT" | grep -qE "read-only-root-filesystem|no-read-only-root-fs"; then
    fail "kube-linter vẫn báo lỗi 'read-only-root-filesystem'" \
         "Thêm vào securityContext: readOnlyRootFilesystem: true"
  else
    pass "kube-linter lint không báo lỗi 'read-only-root-filesystem'"
  fi
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
  echo "Chúc mừng! Bạn đã hoàn thành Lab 5.5."
  echo "Tiếp theo: Đọc phần 'Giải thích' trong README.md"
  echo "Dọn dẹp: bash cleanup.sh"
  exit 0
fi
