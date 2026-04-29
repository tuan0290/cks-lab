#!/bin/bash
# Lab 2.4 – Restrict API Server Access
# Script kiểm tra kết quả bài lab

PASS=0
FAIL=0
FAILED=0

echo "=========================================="
echo " Lab 2.4 – Kiểm tra kết quả"
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

# Lấy kube-apiserver pod
APISERVER_POD=$(kubectl get pods -n kube-system -l component=kube-apiserver -o name 2>/dev/null | head -1)
APISERVER_MANIFEST="/etc/kubernetes/manifests/kube-apiserver.yaml"

get_apiserver_commands() {
  if [ -n "$APISERVER_POD" ]; then
    kubectl get "$APISERVER_POD" -n kube-system \
      -o jsonpath='{.spec.containers[0].command}' 2>/dev/null | tr ',' '\n'
  elif [ -f "$APISERVER_MANIFEST" ]; then
    grep "^\s*-\s*--" "$APISERVER_MANIFEST" | sed 's/^\s*-\s*//'
  else
    echo ""
  fi
}

APISERVER_COMMANDS=$(get_apiserver_commands)

if [ -z "$APISERVER_COMMANDS" ]; then
  echo "[WARN] Không thể lấy cấu hình kube-apiserver. Một số kiểm tra có thể không chính xác."
  echo "       Đảm bảo đang chạy trên control-plane node."
  echo ""
fi

# --- Tiêu chí 1: --anonymous-auth=false ---

echo "Kiểm tra tiêu chí 1: kube-apiserver có --anonymous-auth=false"

ANON_FLAG=$(echo "$APISERVER_COMMANDS" | grep "anonymous-auth" || true)

if echo "$ANON_FLAG" | grep -q "anonymous-auth=false"; then
  pass "kube-apiserver có --anonymous-auth=false"
elif echo "$ANON_FLAG" | grep -q "anonymous-auth=true"; then
  fail "kube-apiserver có --anonymous-auth=true (cần đổi thành false)" \
       "Sửa kube-apiserver manifest: thay --anonymous-auth=true thành --anonymous-auth=false"
else
  fail "kube-apiserver không có flag --anonymous-auth (mặc định là true)" \
       "Thêm '- --anonymous-auth=false' vào /etc/kubernetes/manifests/kube-apiserver.yaml"
fi

echo ""

# --- Tiêu chí 2: NodeRestriction trong --enable-admission-plugins ---

echo "Kiểm tra tiêu chí 2: NodeRestriction trong --enable-admission-plugins"

ADMISSION_FLAG=$(echo "$APISERVER_COMMANDS" | grep "enable-admission-plugins" || true)

if echo "$ADMISSION_FLAG" | grep -q "NodeRestriction"; then
  pass "kube-apiserver có NodeRestriction trong --enable-admission-plugins"
else
  # Kiểm tra xem có flag nào không
  if [ -z "$ADMISSION_FLAG" ]; then
    fail "kube-apiserver không có --enable-admission-plugins (NodeRestriction chưa được bật)" \
         "Thêm '- --enable-admission-plugins=NodeRestriction' vào kube-apiserver manifest"
  else
    fail "NodeRestriction không có trong --enable-admission-plugins: $ADMISSION_FLAG" \
         "Thêm NodeRestriction vào danh sách: --enable-admission-plugins=NodeRestriction,..."
  fi
fi

echo ""

# --- Tiêu chí 3: --authorization-mode bao gồm RBAC ---

echo "Kiểm tra tiêu chí 3: --authorization-mode bao gồm RBAC"

AUTHZ_FLAG=$(echo "$APISERVER_COMMANDS" | grep "authorization-mode" || true)

if echo "$AUTHZ_FLAG" | grep -q "RBAC"; then
  if echo "$AUTHZ_FLAG" | grep -q "Node"; then
    pass "kube-apiserver có --authorization-mode bao gồm cả Node và RBAC: $(echo $AUTHZ_FLAG | tr -d ' ')"
  else
    pass "kube-apiserver có --authorization-mode bao gồm RBAC (thiếu Node — xem gợi ý)"
    echo "       [INFO] Khuyến nghị: --authorization-mode=Node,RBAC để kubelet hoạt động đúng"
  fi
else
  if [ -z "$AUTHZ_FLAG" ]; then
    fail "kube-apiserver không có --authorization-mode" \
         "Thêm '- --authorization-mode=Node,RBAC' vào kube-apiserver manifest"
  else
    fail "RBAC không có trong --authorization-mode: $AUTHZ_FLAG" \
         "Sửa thành --authorization-mode=Node,RBAC"
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
  echo "Chúc mừng! Bạn đã hoàn thành Lab 2.4."
  echo "Tiếp theo: Đọc phần 'Giải thích' trong README.md"
  echo "Dọn dẹp: bash cleanup.sh"
  exit 0
fi
