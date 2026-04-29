#!/bin/bash
# Lab 2.3 – ServiceAccount Token Automount
# Script kiểm tra kết quả bài lab

PASS=0
FAIL=0
FAILED=0

echo "=========================================="
echo " Lab 2.3 – Kiểm tra kết quả"
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

# --- Tiêu chí 1: ServiceAccount web-sa có automountServiceAccountToken: false ---

echo "Kiểm tra tiêu chí 1: ServiceAccount 'web-sa' có automountServiceAccountToken: false"

if ! kubectl get serviceaccount web-sa -n token-lab &>/dev/null; then
  fail "ServiceAccount 'web-sa' không tồn tại trong namespace 'token-lab'" \
       "Chạy setup.sh để tạo môi trường: bash setup.sh"
else
  SA_AUTOMOUNT=$(kubectl get serviceaccount web-sa -n token-lab \
    -o jsonpath='{.automountServiceAccountToken}' 2>/dev/null)

  if [ "$SA_AUTOMOUNT" = "false" ]; then
    pass "ServiceAccount 'web-sa' có automountServiceAccountToken: false"
  else
    fail "ServiceAccount 'web-sa' có automountServiceAccountToken: ${SA_AUTOMOUNT:-true (mặc định)}" \
         "kubectl patch serviceaccount web-sa -n token-lab -p '{\"automountServiceAccountToken\": false}'"
  fi
fi

echo ""

# --- Tiêu chí 2: Pod web-app có automountServiceAccountToken: false ---

echo "Kiểm tra tiêu chí 2: Pod 'web-app' có automountServiceAccountToken: false"

if ! kubectl get pod web-app -n token-lab &>/dev/null; then
  fail "Pod 'web-app' không tồn tại trong namespace 'token-lab'" \
       "Tạo lại pod với automountServiceAccountToken: false"
else
  POD_AUTOMOUNT=$(kubectl get pod web-app -n token-lab \
    -o jsonpath='{.spec.automountServiceAccountToken}' 2>/dev/null)

  if [ "$POD_AUTOMOUNT" = "false" ]; then
    pass "Pod 'web-app' có automountServiceAccountToken: false"
  else
    fail "Pod 'web-app' có automountServiceAccountToken: ${POD_AUTOMOUNT:-true (mặc định)}" \
         "Xóa và tạo lại pod: kubectl delete pod web-app -n token-lab, sau đó tạo lại với automountServiceAccountToken: false"
  fi
fi

echo ""

# --- Tiêu chí 3: Token KHÔNG tồn tại trong pod ---

echo "Kiểm tra tiêu chí 3: Token KHÔNG tồn tại tại /var/run/secrets/kubernetes.io/serviceaccount/token"

if ! kubectl get pod web-app -n token-lab &>/dev/null; then
  fail "Pod 'web-app' không tồn tại — không thể kiểm tra token" \
       "Tạo lại pod với automountServiceAccountToken: false"
else
  POD_STATUS=$(kubectl get pod web-app -n token-lab \
    -o jsonpath='{.status.phase}' 2>/dev/null)

  if [ "$POD_STATUS" != "Running" ]; then
    fail "Pod 'web-app' chưa ở trạng thái Running (hiện tại: ${POD_STATUS:-Unknown})" \
         "Chờ pod Running: kubectl wait --for=condition=Ready pod/web-app -n token-lab --timeout=60s"
  else
    # Kiểm tra file token có tồn tại không
    TOKEN_CHECK=$(kubectl exec web-app -n token-lab -- \
      test -f /var/run/secrets/kubernetes.io/serviceaccount/token 2>/dev/null \
      && echo "EXISTS" || echo "NOT_EXISTS")

    if [ "$TOKEN_CHECK" = "NOT_EXISTS" ]; then
      pass "Token KHÔNG tồn tại tại /var/run/secrets/kubernetes.io/serviceaccount/token trong pod 'web-app'"
    else
      fail "Token VẪN tồn tại tại /var/run/secrets/kubernetes.io/serviceaccount/token trong pod 'web-app'" \
           "Đảm bảo cả SA và pod đều có automountServiceAccountToken: false, sau đó tạo lại pod"
    fi
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
  echo "Chúc mừng! Bạn đã hoàn thành Lab 2.3."
  echo "Tiếp theo: Đọc phần 'Giải thích' trong README.md"
  echo "Dọn dẹp: bash cleanup.sh"
  exit 0
fi
