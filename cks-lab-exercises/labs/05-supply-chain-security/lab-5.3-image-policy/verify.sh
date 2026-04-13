#!/bin/bash
# Lab 5.3 – Image Policy Webhook
# Script kiểm tra kết quả bài lab

PASS=0
FAIL=0
FAILED=0

echo "=========================================="
echo " Lab 5.3 – Kiểm tra kết quả"
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

# --- Tiêu chí 1: ConstraintTemplate K8sAllowedRepos tồn tại HOẶC ImagePolicyWebhook được cấu hình ---

echo "Kiểm tra tiêu chí 1: ConstraintTemplate 'K8sAllowedRepos' tồn tại hoặc ImagePolicyWebhook được cấu hình"

CONSTRAINT_TEMPLATE_EXISTS=0
IMAGE_POLICY_EXISTS=0

# Kiểm tra ConstraintTemplate
if kubectl get constrainttemplate k8sallowedrepos &>/dev/null 2>&1; then
  CONSTRAINT_TEMPLATE_EXISTS=1
fi

# Kiểm tra ImagePolicyWebhook (kiểm tra admission config trên apiserver)
if kubectl get validatingwebhookconfiguration 2>/dev/null | grep -qi "image"; then
  IMAGE_POLICY_EXISTS=1
fi

if [ "$CONSTRAINT_TEMPLATE_EXISTS" -eq 1 ]; then
  pass "ConstraintTemplate 'k8sallowedrepos' tồn tại trong cluster"
elif [ "$IMAGE_POLICY_EXISTS" -eq 1 ]; then
  pass "ImagePolicyWebhook ValidatingWebhookConfiguration tồn tại trong cluster"
else
  fail "Không tìm thấy ConstraintTemplate 'k8sallowedrepos' hoặc ImagePolicyWebhook" \
       "Apply ConstraintTemplate: kubectl apply -f /tmp/allowed-repos-template.yaml"
fi

echo ""

# --- Tiêu chí 2: Constraint tồn tại ---

echo "Kiểm tra tiêu chí 2: Constraint 'allowed-repos' tồn tại"

CONSTRAINT_EXISTS=0

# Kiểm tra K8sAllowedRepos constraint
if kubectl get k8sallowedrepos allowed-repos &>/dev/null 2>&1; then
  CONSTRAINT_EXISTS=1
fi

# Kiểm tra bất kỳ K8sAllowedRepos constraint nào
if [ "$CONSTRAINT_EXISTS" -eq 0 ]; then
  if kubectl get k8sallowedrepos &>/dev/null 2>&1; then
    COUNT=$(kubectl get k8sallowedrepos --no-headers 2>/dev/null | wc -l)
    if [ "$COUNT" -gt 0 ]; then
      CONSTRAINT_EXISTS=1
    fi
  fi
fi

if [ "$CONSTRAINT_EXISTS" -eq 1 ]; then
  pass "Constraint K8sAllowedRepos tồn tại trong cluster"
else
  fail "Không tìm thấy Constraint K8sAllowedRepos" \
       "Tạo Constraint: kubectl apply -f - với kind: K8sAllowedRepos"
fi

echo ""

# --- Tiêu chí 3: Namespace policy-lab tồn tại ---

echo "Kiểm tra tiêu chí 3: Namespace 'policy-lab' tồn tại trong cluster"

if kubectl get namespace policy-lab &>/dev/null; then
  pass "Namespace 'policy-lab' tồn tại trong cluster"
else
  fail "Namespace 'policy-lab' không tìm thấy" \
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
  echo "Chúc mừng! Bạn đã hoàn thành Lab 5.3."
  echo "Tiếp theo: Đọc phần 'Giải thích' trong README.md"
  echo "Dọn dẹp: bash cleanup.sh"
  exit 0
fi
