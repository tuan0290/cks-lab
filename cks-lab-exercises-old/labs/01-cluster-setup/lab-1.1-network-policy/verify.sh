#!/bin/bash
# Lab 1.1 – NetworkPolicy Default Deny
# Script kiểm tra kết quả bài lab

PASS=0
FAIL=0
FAILED=0

echo "=========================================="
echo " Lab 1.1 – Kiểm tra kết quả"
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

# --- Tiêu chí 1: NetworkPolicy deny-all-ingress tồn tại trong lab-network ---

echo "Kiểm tra tiêu chí 1: NetworkPolicy deny-all-ingress trong namespace lab-network"

if kubectl get networkpolicy deny-all-ingress -n lab-network &>/dev/null; then
  # Kiểm tra policyTypes có chứa Ingress không
  POLICY_TYPES=$(kubectl get networkpolicy deny-all-ingress -n lab-network -o jsonpath='{.spec.policyTypes}' 2>/dev/null)
  if echo "$POLICY_TYPES" | grep -q "Ingress"; then
    pass "NetworkPolicy 'deny-all-ingress' tồn tại trong namespace 'lab-network' với policyType Ingress"
  else
    fail "NetworkPolicy 'deny-all-ingress' tồn tại nhưng thiếu policyType 'Ingress'" \
         "Thêm 'policyTypes: [Ingress]' vào spec của NetworkPolicy"
  fi
else
  fail "NetworkPolicy 'deny-all-ingress' không tìm thấy trong namespace 'lab-network'" \
       "kubectl apply -f deny-all-ingress.yaml (xem README.md Bước 2)"
fi

echo ""

# --- Tiêu chí 2: NetworkPolicy deny-all-egress tồn tại trong lab-network ---

echo "Kiểm tra tiêu chí 2: NetworkPolicy deny-all-egress trong namespace lab-network"

if kubectl get networkpolicy deny-all-egress -n lab-network &>/dev/null; then
  POLICY_TYPES=$(kubectl get networkpolicy deny-all-egress -n lab-network -o jsonpath='{.spec.policyTypes}' 2>/dev/null)
  if echo "$POLICY_TYPES" | grep -q "Egress"; then
    pass "NetworkPolicy 'deny-all-egress' tồn tại trong namespace 'lab-network' với policyType Egress"
  else
    fail "NetworkPolicy 'deny-all-egress' tồn tại nhưng thiếu policyType 'Egress'" \
         "Thêm 'policyTypes: [Egress]' vào spec của NetworkPolicy"
  fi
else
  fail "NetworkPolicy 'deny-all-egress' không tìm thấy trong namespace 'lab-network'" \
       "kubectl apply -f deny-all-egress.yaml (xem README.md Bước 3)"
fi

echo ""

# --- Tiêu chí 3: Có NetworkPolicy cho phép traffic từ frontend-ns đến backend-ns trên port 80 ---

echo "Kiểm tra tiêu chí 3: NetworkPolicy cho phép traffic từ frontend-ns đến backend-ns port 80"

# Tìm NetworkPolicy trong backend-ns có namespaceSelector trỏ đến frontend-ns và port 80
FOUND_ALLOW_POLICY=0

# Lấy tất cả NetworkPolicy trong backend-ns
NP_LIST=$(kubectl get networkpolicy -n backend-ns -o name 2>/dev/null)

if [ -z "$NP_LIST" ]; then
  fail "Không tìm thấy NetworkPolicy nào trong namespace 'backend-ns'" \
       "Tạo NetworkPolicy allow-frontend-to-backend trong backend-ns (xem README.md Bước 4)"
else
  for NP in $NP_LIST; do
    NP_NAME=$(echo "$NP" | sed 's|networkpolicy.networking.k8s.io/||')
    NP_JSON=$(kubectl get networkpolicy "$NP_NAME" -n backend-ns -o json 2>/dev/null)

    # Kiểm tra có policyType Ingress
    HAS_INGRESS=$(echo "$NP_JSON" | grep -c '"Ingress"' 2>/dev/null || true)
    # Kiểm tra có namespaceSelector
    HAS_NS_SELECTOR=$(echo "$NP_JSON" | grep -c 'namespaceSelector' 2>/dev/null || true)
    # Kiểm tra có port 80
    HAS_PORT_80=$(echo "$NP_JSON" | grep -c '"port": 80\|"port":"80"' 2>/dev/null || true)

    if [ "$HAS_INGRESS" -gt 0 ] && [ "$HAS_NS_SELECTOR" -gt 0 ] && [ "$HAS_PORT_80" -gt 0 ]; then
      FOUND_ALLOW_POLICY=1
      ALLOW_POLICY_NAME="$NP_NAME"
      break
    fi
  done

  if [ "$FOUND_ALLOW_POLICY" -eq 1 ]; then
    pass "NetworkPolicy '$ALLOW_POLICY_NAME' trong 'backend-ns' cho phép ingress từ namespace selector trên port 80"
  else
    fail "Không tìm thấy NetworkPolicy nào trong 'backend-ns' cho phép ingress từ 'frontend-ns' trên port 80" \
         "Tạo NetworkPolicy với namespaceSelector: {kubernetes.io/metadata.name: frontend-ns} và port 80 (xem README.md Bước 4)"
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
  echo "Chúc mừng! Bạn đã hoàn thành Lab 1.1."
  echo "Tiếp theo: Đọc phần 'Giải thích' trong README.md"
  echo "Dọn dẹp: bash cleanup.sh"
  exit 0
fi
