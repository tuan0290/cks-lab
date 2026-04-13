#!/bin/bash
# Lab 2.1 – RBAC Least Privilege
# Script kiểm tra kết quả bài lab

PASS=0
FAIL=0
FAILED=0

echo "=========================================="
echo " Lab 2.1 – Kiểm tra kết quả"
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

warn() {
  echo "[WARN] $1"
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

# --- Tiêu chí 1: ClusterRoleBinding app-sa-binding không còn gán cluster-admin cho app-sa ---

echo "Kiểm tra tiêu chí 1: ClusterRoleBinding 'app-sa-binding' không còn gán cluster-admin cho app-sa"

CRB_EXISTS=$(kubectl get clusterrolebinding app-sa-binding &>/dev/null && echo "yes" || echo "no")

if [ "$CRB_EXISTS" = "no" ]; then
  pass "ClusterRoleBinding 'app-sa-binding' đã bị xóa"
else
  # CRB tồn tại — kiểm tra xem có còn gán cluster-admin không
  CRB_ROLE=$(kubectl get clusterrolebinding app-sa-binding \
    -o jsonpath='{.roleRef.name}' 2>/dev/null)
  CRB_SUBJECT_SA=$(kubectl get clusterrolebinding app-sa-binding -o json 2>/dev/null | \
    grep -c '"name": "app-sa"' || true)

  if [ "$CRB_ROLE" = "cluster-admin" ] && [ "$CRB_SUBJECT_SA" -gt 0 ]; then
    fail "ClusterRoleBinding 'app-sa-binding' vẫn còn gán 'cluster-admin' cho 'app-sa'" \
         "kubectl delete clusterrolebinding app-sa-binding"
  else
    pass "ClusterRoleBinding 'app-sa-binding' tồn tại nhưng không còn gán cluster-admin cho app-sa"
  fi
fi

echo ""

# --- Tiêu chí 2: app-sa có thể list pods trong rbac-lab ---

echo "Kiểm tra tiêu chí 2: app-sa có thể list pods trong namespace rbac-lab"

CAN_LIST=$(kubectl auth can-i list pods \
  --as=system:serviceaccount:rbac-lab:app-sa -n rbac-lab 2>/dev/null)

if [ "$CAN_LIST" = "yes" ]; then
  pass "app-sa có thể list pods trong namespace 'rbac-lab' (kubectl auth can-i list pods → yes)"
else
  fail "app-sa không thể list pods trong namespace 'rbac-lab'" \
       "Tạo Role với verbs [get, list, watch] trên pods và RoleBinding cho app-sa trong rbac-lab"
fi

echo ""

# --- Tiêu chí 3: app-sa không thể delete pods trong rbac-lab ---

echo "Kiểm tra tiêu chí 3: app-sa không thể delete pods trong namespace rbac-lab"

CAN_DELETE=$(kubectl auth can-i delete pods \
  --as=system:serviceaccount:rbac-lab:app-sa -n rbac-lab 2>/dev/null)

if [ "$CAN_DELETE" = "no" ]; then
  pass "app-sa không thể delete pods trong namespace 'rbac-lab' (kubectl auth can-i delete pods → no)"
else
  fail "app-sa vẫn có thể delete pods trong namespace 'rbac-lab' — vi phạm least-privilege" \
       "Kiểm tra không có RoleBinding/ClusterRoleBinding nào cấp quyền delete pods cho app-sa"
fi

echo ""

# --- Cảnh báo: wildcard verb "*" ---

echo "Kiểm tra cảnh báo: wildcard verb '*' cho app-sa"

WILDCARD_FOUND=0

# Kiểm tra tất cả RoleBinding trong rbac-lab
RB_LIST=$(kubectl get rolebinding -n rbac-lab -o name 2>/dev/null)
for RB in $RB_LIST; do
  RB_NAME=$(echo "$RB" | sed 's|rolebinding.rbac.authorization.k8s.io/||')
  # Kiểm tra subject là app-sa
  HAS_SA=$(kubectl get rolebinding "$RB_NAME" -n rbac-lab -o json 2>/dev/null | \
    grep -c '"name": "app-sa"' || true)
  if [ "$HAS_SA" -gt 0 ]; then
    ROLE_REF=$(kubectl get rolebinding "$RB_NAME" -n rbac-lab \
      -o jsonpath='{.roleRef.name}' 2>/dev/null)
    ROLE_KIND=$(kubectl get rolebinding "$RB_NAME" -n rbac-lab \
      -o jsonpath='{.roleRef.kind}' 2>/dev/null)
    # Lấy verbs của role được tham chiếu
    if [ "$ROLE_KIND" = "Role" ]; then
      VERBS=$(kubectl get role "$ROLE_REF" -n rbac-lab \
        -o jsonpath='{.rules[*].verbs[*]}' 2>/dev/null)
    elif [ "$ROLE_KIND" = "ClusterRole" ]; then
      VERBS=$(kubectl get clusterrole "$ROLE_REF" \
        -o jsonpath='{.rules[*].verbs[*]}' 2>/dev/null)
    fi
    if echo "$VERBS" | grep -qw '\*'; then
      warn "RoleBinding '$RB_NAME' trong rbac-lab sử dụng wildcard verb '*' cho app-sa — vi phạm least-privilege"
      WILDCARD_FOUND=1
    fi
  fi
done

# Kiểm tra tất cả ClusterRoleBinding
CRB_LIST=$(kubectl get clusterrolebinding -o name 2>/dev/null)
for CRB in $CRB_LIST; do
  CRB_NAME=$(echo "$CRB" | sed 's|clusterrolebinding.rbac.authorization.k8s.io/||')
  HAS_SA=$(kubectl get clusterrolebinding "$CRB_NAME" -o json 2>/dev/null | \
    grep -c '"name": "app-sa"' || true)
  if [ "$HAS_SA" -gt 0 ]; then
    CR_REF=$(kubectl get clusterrolebinding "$CRB_NAME" \
      -o jsonpath='{.roleRef.name}' 2>/dev/null)
    VERBS=$(kubectl get clusterrole "$CR_REF" \
      -o jsonpath='{.rules[*].verbs[*]}' 2>/dev/null)
    if echo "$VERBS" | grep -qw '\*'; then
      warn "ClusterRoleBinding '$CRB_NAME' sử dụng wildcard verb '*' cho app-sa — vi phạm least-privilege"
      WILDCARD_FOUND=1
    fi
  fi
done

if [ "$WILDCARD_FOUND" -eq 0 ]; then
  echo "       Không phát hiện wildcard verb '*' cho app-sa."
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
  echo "Chúc mừng! Bạn đã hoàn thành Lab 2.1."
  echo "Tiếp theo: Đọc phần 'Giải thích' trong README.md"
  echo "Dọn dẹp: bash cleanup.sh"
  exit 0
fi
