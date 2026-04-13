#!/bin/bash
# Lab 1.3 – Ingress TLS
# Script kiểm tra kết quả bài lab

PASS=0
FAIL=0
FAILED=0

echo "=========================================="
echo " Lab 1.3 – Kiểm tra kết quả"
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

# --- Tiêu chí 1: Secret tls-secret tồn tại và có type kubernetes.io/tls ---

echo "Kiểm tra tiêu chí 1: Secret 'tls-secret' tồn tại trong namespace 'tls-lab' với type kubernetes.io/tls"

SECRET_TYPE=$(kubectl get secret tls-secret -n tls-lab -o jsonpath='{.type}' 2>/dev/null)

if [ "$SECRET_TYPE" = "kubernetes.io/tls" ]; then
  pass "Secret 'tls-secret' tồn tại trong namespace 'tls-lab' với type 'kubernetes.io/tls'"
elif [ -z "$SECRET_TYPE" ]; then
  fail "Secret 'tls-secret' không tìm thấy trong namespace 'tls-lab'" \
       "kubectl create secret tls tls-secret --cert=tls.crt --key=tls.key -n tls-lab"
else
  fail "Secret 'tls-secret' tồn tại nhưng type sai: '${SECRET_TYPE}' (cần 'kubernetes.io/tls')" \
       "Xóa và tạo lại: kubectl delete secret tls-secret -n tls-lab && kubectl create secret tls tls-secret --cert=tls.crt --key=tls.key -n tls-lab"
fi

echo ""

# --- Tiêu chí 2: Ingress tls-ingress tồn tại trong namespace tls-lab ---

echo "Kiểm tra tiêu chí 2: Ingress 'tls-ingress' tồn tại trong namespace 'tls-lab'"

if kubectl get ingress tls-ingress -n tls-lab &>/dev/null; then
  pass "Ingress 'tls-ingress' tồn tại trong namespace 'tls-lab'"
else
  fail "Ingress 'tls-ingress' không tìm thấy trong namespace 'tls-lab'" \
       "Tạo Ingress với TLS section — xem README.md Bước 4"
fi

echo ""

# --- Tiêu chí 3: Ingress có cấu hình TLS (spec.tls không rỗng) ---

echo "Kiểm tra tiêu chí 3: Ingress 'tls-ingress' có cấu hình TLS (spec.tls không rỗng)"

TLS_CONFIG=$(kubectl get ingress tls-ingress -n tls-lab -o jsonpath='{.spec.tls}' 2>/dev/null)

if [ -n "$TLS_CONFIG" ] && [ "$TLS_CONFIG" != "null" ] && [ "$TLS_CONFIG" != "[]" ]; then
  pass "Ingress 'tls-ingress' có cấu hình TLS trong spec.tls"
else
  fail "Ingress 'tls-ingress' không có cấu hình TLS (spec.tls rỗng hoặc không tồn tại)" \
       "Thêm phần spec.tls vào Ingress — xem README.md Bước 4"
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
  echo "Chúc mừng! Bạn đã hoàn thành Lab 1.3."
  echo "Tiếp theo: Đọc phần 'Giải thích' trong README.md"
  echo "Dọn dẹp: bash cleanup.sh"
  exit 0
fi
