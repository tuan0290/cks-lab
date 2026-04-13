#!/bin/bash
# Lab 3.1 – AppArmor
# Script kiểm tra kết quả bài lab

PASS=0
FAIL=0
FAILED=0

echo "=========================================="
echo " Lab 3.1 – Kiểm tra kết quả"
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

# --- Tiêu chí 1: Pod secure-pod tồn tại trong namespace apparmor-lab ---

echo "Kiểm tra tiêu chí 1: Pod 'secure-pod' tồn tại trong namespace 'apparmor-lab'"

if kubectl get pod secure-pod -n apparmor-lab &>/dev/null; then
  # Kiểm tra trạng thái Running
  POD_STATUS=$(kubectl get pod secure-pod -n apparmor-lab \
    -o jsonpath='{.status.phase}' 2>/dev/null)

  if [ "$POD_STATUS" = "Running" ]; then
    pass "Pod 'secure-pod' tồn tại trong namespace 'apparmor-lab' và đang Running"
  else
    fail "Pod 'secure-pod' tồn tại nhưng không ở trạng thái Running (hiện tại: ${POD_STATUS})" \
         "kubectl describe pod secure-pod -n apparmor-lab để xem lý do"
  fi
else
  fail "Pod 'secure-pod' không tìm thấy trong namespace 'apparmor-lab'" \
       "kubectl apply -f pod.yaml với annotation AppArmor đúng"
fi

echo ""

# --- Tiêu chí 2: Pod có AppArmor annotation đúng ---

echo "Kiểm tra tiêu chí 2: Pod có annotation AppArmor 'localhost/k8s-deny-write' cho container 'secure-container'"

ANNOTATION=$(kubectl get pod secure-pod -n apparmor-lab \
  -o jsonpath='{.metadata.annotations.container\.apparmor\.security\.beta\.kubernetes\.io/secure-container}' \
  2>/dev/null)

if [ "$ANNOTATION" = "localhost/k8s-deny-write" ]; then
  pass "Pod có annotation: container.apparmor.security.beta.kubernetes.io/secure-container=localhost/k8s-deny-write"
else
  if [ -z "$ANNOTATION" ]; then
    fail "Pod 'secure-pod' không có annotation AppArmor cho container 'secure-container'" \
         "Thêm annotation: container.apparmor.security.beta.kubernetes.io/secure-container: localhost/k8s-deny-write"
  else
    fail "Annotation AppArmor không đúng (hiện tại: '${ANNOTATION}', mong đợi: 'localhost/k8s-deny-write')" \
         "Sửa annotation thành: container.apparmor.security.beta.kubernetes.io/secure-container: localhost/k8s-deny-write"
  fi
fi

echo ""

# --- Tiêu chí 3: Pod đang ở trạng thái Running (kiểm tra lại tổng hợp) ---

echo "Kiểm tra tiêu chí 3: Pod 'secure-pod' đang ở trạng thái Running"

POD_PHASE=$(kubectl get pod secure-pod -n apparmor-lab \
  -o jsonpath='{.status.phase}' 2>/dev/null)

if [ "$POD_PHASE" = "Running" ]; then
  pass "Pod 'secure-pod' đang ở trạng thái Running — AppArmor profile được chấp nhận bởi node"
else
  if [ -z "$POD_PHASE" ]; then
    fail "Pod 'secure-pod' không tồn tại" \
         "Tạo pod với kubectl apply"
  else
    fail "Pod 'secure-pod' không ở trạng thái Running (hiện tại: ${POD_PHASE})" \
         "Kiểm tra AppArmor profile đã được load trên node: sudo aa-status | grep k8s-deny-write"
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
  echo ""
  echo "Lưu ý: Nếu pod ở trạng thái Pending hoặc Error, kiểm tra AppArmor profile"
  echo "đã được load trên node worker:"
  echo "  ssh <node-worker> 'sudo aa-status | grep k8s-deny-write'"
  exit 1
else
  echo ""
  echo "Chúc mừng! Bạn đã hoàn thành Lab 3.1."
  echo "Tiếp theo: Đọc phần 'Giải thích' trong README.md"
  echo "Dọn dẹp: bash cleanup.sh"
  exit 0
fi
