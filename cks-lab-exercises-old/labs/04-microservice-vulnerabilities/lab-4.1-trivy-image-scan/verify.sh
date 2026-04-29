#!/bin/bash
# Lab 4.1 – Trivy Image Scan
# Script kiểm tra kết quả bài lab

PASS=0
FAIL=0
FAILED=0

echo "=========================================="
echo " Lab 4.1 – Kiểm tra kết quả"
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

# --- Tiêu chí 1: trivy đã được cài đặt ---

echo "Kiểm tra tiêu chí 1: trivy đã được cài đặt"

if command -v trivy &>/dev/null; then
  TRIVY_VERSION=$(trivy --version 2>/dev/null | head -1)
  pass "trivy đã được cài đặt (${TRIVY_VERSION})"
else
  fail "trivy không tìm thấy" \
       "Cài đặt trivy: https://aquasecurity.github.io/trivy/latest/getting-started/installation/"
fi

echo ""

# --- Tiêu chí 2: Pod web-app tồn tại trong namespace trivy-lab ---

echo "Kiểm tra tiêu chí 2: Pod 'web-app' tồn tại trong namespace 'trivy-lab'"

if kubectl get pod web-app -n trivy-lab &>/dev/null; then
  POD_STATUS=$(kubectl get pod web-app -n trivy-lab \
    -o jsonpath='{.status.phase}' 2>/dev/null)

  if [ "$POD_STATUS" = "Running" ]; then
    pass "Pod 'web-app' tồn tại trong namespace 'trivy-lab' và đang Running"
  else
    fail "Pod 'web-app' tồn tại nhưng không ở trạng thái Running (hiện tại: ${POD_STATUS})" \
         "kubectl describe pod web-app -n trivy-lab để xem lý do"
  fi
else
  fail "Pod 'web-app' không tìm thấy trong namespace 'trivy-lab'" \
       "kubectl run web-app --image=nginx:1.25-alpine --namespace=trivy-lab --restart=Never"
fi

echo ""

# --- Tiêu chí 3: Pod web-app sử dụng image nginx:1.25-alpine (không phải nginx:1.14.0) ---

echo "Kiểm tra tiêu chí 3: Pod 'web-app' sử dụng image nginx:1.25-alpine"

CURRENT_IMAGE=$(kubectl get pod web-app -n trivy-lab \
  -o jsonpath='{.spec.containers[0].image}' 2>/dev/null)

if [ -z "$CURRENT_IMAGE" ]; then
  fail "Không thể lấy thông tin image của pod 'web-app'" \
       "Kiểm tra pod tồn tại: kubectl get pod web-app -n trivy-lab"
elif echo "$CURRENT_IMAGE" | grep -q "nginx:1.14.0"; then
  fail "Pod 'web-app' vẫn đang dùng image cũ: ${CURRENT_IMAGE}" \
       "Xóa pod cũ và tạo lại: kubectl delete pod web-app -n trivy-lab && kubectl run web-app --image=nginx:1.25-alpine --namespace=trivy-lab --restart=Never"
elif echo "$CURRENT_IMAGE" | grep -q "nginx:1.25-alpine"; then
  pass "Pod 'web-app' đang sử dụng image nginx:1.25-alpine (image an toàn hơn)"
else
  fail "Pod 'web-app' đang dùng image không mong đợi: ${CURRENT_IMAGE} (mong đợi: nginx:1.25-alpine)" \
       "kubectl delete pod web-app -n trivy-lab && kubectl run web-app --image=nginx:1.25-alpine --namespace=trivy-lab --restart=Never"
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
  echo "Chúc mừng! Bạn đã hoàn thành Lab 4.1."
  echo "Tiếp theo: Đọc phần 'Giải thích' trong README.md"
  echo "Dọn dẹp: bash cleanup.sh"
  exit 0
fi
