#!/bin/bash
# Lab 1.5 – Authentication với Certificate và ServiceAccount

PASS=0
FAIL=0
FAILED=0

echo "=========================================="
echo " Lab 1.5 – Kiểm tra kết quả"
echo "=========================================="
echo ""

pass() { echo "[PASS] $1"; PASS=$((PASS + 1)); }
fail() {
  echo "[FAIL] $1"
  [ -n "$2" ] && echo "       Gợi ý: $2"
  FAIL=$((FAIL + 1)); FAILED=1
}

if ! command -v kubectl &>/dev/null; then
  echo "[ERROR] kubectl không tìm thấy."; exit 1
fi

# --- Tiêu chí 1: Certificate dev-user tồn tại và hợp lệ ---

echo "Kiểm tra tiêu chí 1: Certificate dev-user tồn tại với CN=dev-user"

CERT_FILE="/tmp/user-cert-lab/dev-user.crt"

if [ ! -f "$CERT_FILE" ]; then
  fail "File $CERT_FILE không tồn tại" \
       "Chạy các bước 1-4 trong README.md để tạo và lấy certificate"
else
  CN=$(openssl x509 -in "$CERT_FILE" -noout -subject 2>/dev/null | grep -oP 'CN\s*=\s*\K[^,/]+' | tr -d ' ')
  if [ "$CN" = "dev-user" ]; then
    EXPIRY=$(openssl x509 -in "$CERT_FILE" -noout -enddate 2>/dev/null | cut -d= -f2)
    pass "Certificate tồn tại với CN=dev-user (hết hạn: ${EXPIRY})"
  else
    fail "Certificate tồn tại nhưng CN không đúng (hiện tại: '${CN}', mong đợi: 'dev-user')" \
         "Tạo lại CSR với -subj '/CN=dev-user/O=developers'"
  fi
fi

echo ""

# --- Tiêu chí 2: RoleBinding dev-user-pod-reader tồn tại ---

echo "Kiểm tra tiêu chí 2: RoleBinding 'dev-user-pod-reader' tồn tại trong namespace 'dev-ns'"

if kubectl get rolebinding dev-user-pod-reader -n dev-ns &>/dev/null; then
  SUBJECT=$(kubectl get rolebinding dev-user-pod-reader -n dev-ns \
    -o jsonpath='{.subjects[0].name}' 2>/dev/null)
  ROLE=$(kubectl get rolebinding dev-user-pod-reader -n dev-ns \
    -o jsonpath='{.roleRef.name}' 2>/dev/null)
  pass "RoleBinding 'dev-user-pod-reader' tồn tại (subject: ${SUBJECT}, role: ${ROLE})"
else
  fail "RoleBinding 'dev-user-pod-reader' không tìm thấy trong namespace 'dev-ns'" \
       "Tạo RoleBinding theo Bước 6 trong README.md"
fi

echo ""

# --- Tiêu chí 3: ServiceAccount restricted-sa có automount disabled ---

echo "Kiểm tra tiêu chí 3: ServiceAccount 'restricted-sa' có automountServiceAccountToken: false"

if ! kubectl get serviceaccount restricted-sa -n dev-ns &>/dev/null; then
  fail "ServiceAccount 'restricted-sa' không tìm thấy trong namespace 'dev-ns'" \
       "Tạo ServiceAccount theo Bước 8 trong README.md"
else
  AUTOMOUNT=$(kubectl get serviceaccount restricted-sa -n dev-ns \
    -o jsonpath='{.automountServiceAccountToken}' 2>/dev/null)
  if [ "$AUTOMOUNT" = "false" ]; then
    pass "ServiceAccount 'restricted-sa' có automountServiceAccountToken: false"
  else
    fail "ServiceAccount 'restricted-sa' có automountServiceAccountToken: ${AUTOMOUNT:-true (mặc định)}" \
         "kubectl patch serviceaccount restricted-sa -n dev-ns -p '{\"automountServiceAccountToken\": false}'"
  fi
fi

echo ""

TOTAL=$((PASS + FAIL))
echo "=========================================="
echo " Kết quả: ${PASS}/${TOTAL} tiêu chí đạt"
echo "=========================================="

if [ "$FAILED" -eq 1 ]; then
  echo ""; echo "Một số tiêu chí chưa đạt. Xem gợi ý ở trên và thử lại."
  exit 1
else
  echo ""; echo "Chúc mừng! Bạn đã hoàn thành Lab 1.5."
  echo "Dọn dẹp: bash cleanup.sh"
  exit 0
fi
