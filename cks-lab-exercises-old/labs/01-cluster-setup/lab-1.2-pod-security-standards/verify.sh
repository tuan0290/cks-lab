#!/bin/bash
# Lab 1.2 – Pod Security Standards (PSS)
# Script kiểm tra kết quả bài lab

PASS=0
FAIL=0
FAILED=0

echo "=========================================="
echo " Lab 1.2 – Kiểm tra kết quả"
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

# --- Tiêu chí 1: Namespace pss-lab có label enforce=restricted ---

echo "Kiểm tra tiêu chí 1: Namespace pss-lab có label pod-security.kubernetes.io/enforce=restricted"

ENFORCE_LABEL=$(kubectl get namespace pss-lab -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null)

if [ "$ENFORCE_LABEL" = "restricted" ]; then
  pass "Namespace 'pss-lab' có label 'pod-security.kubernetes.io/enforce=restricted'"
else
  fail "Namespace 'pss-lab' thiếu label 'pod-security.kubernetes.io/enforce=restricted' (hiện tại: '${ENFORCE_LABEL:-<không có>')" \
       "kubectl label namespace pss-lab pod-security.kubernetes.io/enforce=restricted"
fi

echo ""

# --- Tiêu chí 2: Namespace pss-lab có label enforce-version=latest ---

echo "Kiểm tra tiêu chí 2: Namespace pss-lab có label pod-security.kubernetes.io/enforce-version=latest"

VERSION_LABEL=$(kubectl get namespace pss-lab -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce-version}' 2>/dev/null)

if [ "$VERSION_LABEL" = "latest" ]; then
  pass "Namespace 'pss-lab' có label 'pod-security.kubernetes.io/enforce-version=latest'"
else
  fail "Namespace 'pss-lab' thiếu label 'pod-security.kubernetes.io/enforce-version=latest' (hiện tại: '${VERSION_LABEL:-<không có>')" \
       "kubectl label namespace pss-lab pod-security.kubernetes.io/enforce-version=latest"
fi

echo ""

# --- Tiêu chí 3: Pod privileged bị từ chối trong pss-lab ---

echo "Kiểm tra tiêu chí 3: Pod privileged bị từ chối khi tạo trong namespace pss-lab"

# Thử tạo pod privileged và kiểm tra xem có bị từ chối không
CREATE_OUTPUT=$(kubectl apply -f - 2>&1 <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: pss-verify-privileged-pod
  namespace: pss-lab
spec:
  containers:
  - name: test
    image: nginx:1.25-alpine
    securityContext:
      privileged: true
EOF
)
CREATE_EXIT=$?

# Dọn dẹp nếu pod được tạo thành công (không mong muốn)
kubectl delete pod pss-verify-privileged-pod -n pss-lab --ignore-not-found=true &>/dev/null

if [ $CREATE_EXIT -ne 0 ] || echo "$CREATE_OUTPUT" | grep -qiE "forbidden|violates|denied|Error"; then
  pass "Pod privileged bị từ chối trong namespace 'pss-lab' (PSS restricted hoạt động đúng)"
else
  fail "Pod privileged được tạo thành công trong 'pss-lab' — PSS restricted chưa được áp dụng đúng" \
       "Kiểm tra label: kubectl get namespace pss-lab --show-labels"
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
  echo "Chúc mừng! Bạn đã hoàn thành Lab 1.2."
  echo "Tiếp theo: Đọc phần 'Giải thích' trong README.md"
  echo "Dọn dẹp: bash cleanup.sh"
  exit 0
fi
