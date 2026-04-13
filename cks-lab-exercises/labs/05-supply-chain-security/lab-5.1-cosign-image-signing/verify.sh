#!/bin/bash
# Lab 5.1 – cosign Image Signing
# Script kiểm tra kết quả bài lab

PASS=0
FAIL=0
FAILED=0

echo "=========================================="
echo " Lab 5.1 – Kiểm tra kết quả"
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

# --- Kiểm tra kubectl ---

if ! command -v kubectl &>/dev/null; then
  echo "[ERROR] kubectl không tìm thấy. Không thể chạy kiểm tra."
  exit 1
fi

if ! kubectl cluster-info &>/dev/null; then
  echo "[ERROR] Không thể kết nối đến cluster."
  exit 1
fi

# --- Tiêu chí 1: cosign key pair tồn tại trong /tmp/cosign-lab/ ---

echo "Kiểm tra tiêu chí 1: cosign key pair tồn tại trong /tmp/cosign-lab/"

if [ -f /tmp/cosign-lab/cosign.key ] && [ -f /tmp/cosign-lab/cosign.pub ]; then
  pass "File cosign.key và cosign.pub tồn tại trong /tmp/cosign-lab/"
else
  if [ ! -f /tmp/cosign-lab/cosign.key ]; then
    fail "File cosign.key không tìm thấy trong /tmp/cosign-lab/" \
         "cd /tmp/cosign-lab && cosign generate-key-pair"
  fi
  if [ ! -f /tmp/cosign-lab/cosign.pub ]; then
    fail "File cosign.pub không tìm thấy trong /tmp/cosign-lab/" \
         "cd /tmp/cosign-lab && cosign generate-key-pair"
  fi
fi

echo ""

# --- Tiêu chí 2: cosign có thể xác minh chữ ký của image ---

echo "Kiểm tra tiêu chí 2: cosign có thể xác minh chữ ký của nginx:1.25-alpine"

if ! command -v cosign &>/dev/null; then
  fail "cosign không tìm thấy" \
       "Cài đặt cosign: https://docs.sigstore.dev/cosign/system_config/installation/"
elif [ ! -f /tmp/cosign-lab/cosign.pub ]; then
  fail "Không thể xác minh: cosign.pub không tồn tại" \
       "Tạo key pair trước: cd /tmp/cosign-lab && cosign generate-key-pair"
else
  if COSIGN_PASSWORD="" cosign verify --key /tmp/cosign-lab/cosign.pub nginx:1.25-alpine &>/dev/null 2>&1; then
    pass "cosign xác minh chữ ký của nginx:1.25-alpine thành công"
  else
    fail "cosign không thể xác minh chữ ký của nginx:1.25-alpine" \
         "Ký image trước: COSIGN_PASSWORD=\"\" cosign sign --key /tmp/cosign-lab/cosign.key nginx:1.25-alpine"
  fi
fi

echo ""

# --- Tiêu chí 3: Namespace cosign-lab tồn tại ---

echo "Kiểm tra tiêu chí 3: Namespace 'cosign-lab' tồn tại trong cluster"

if kubectl get namespace cosign-lab &>/dev/null; then
  pass "Namespace 'cosign-lab' tồn tại trong cluster"
else
  fail "Namespace 'cosign-lab' không tìm thấy" \
       "Chạy setup.sh để tạo namespace: bash setup.sh"
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
  echo "Chúc mừng! Bạn đã hoàn thành Lab 5.1."
  echo "Tiếp theo: Đọc phần 'Giải thích' trong README.md"
  echo "Dọn dẹp: bash cleanup.sh"
  exit 0
fi
