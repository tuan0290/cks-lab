#!/bin/bash
# Lab 2.2 – Audit Policy
# Script kiểm tra kết quả bài lab

PASS=0
FAIL=0
FAILED=0

echo "=========================================="
echo " Lab 2.2 – Kiểm tra kết quả"
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

# --- Xác định đường dẫn policy file ---

POLICY_FILE=""
if [ -f "/etc/kubernetes/audit/audit-policy.yaml" ]; then
  POLICY_FILE="/etc/kubernetes/audit/audit-policy.yaml"
elif [ -f "/tmp/audit-policy.yaml" ]; then
  POLICY_FILE="/tmp/audit-policy.yaml"
fi

# --- Tiêu chí 1: File audit policy tồn tại và chứa RequestResponse cho secrets ---

echo "Kiểm tra tiêu chí 1: Audit policy file tồn tại và có rule RequestResponse cho secrets"

if [ -z "$POLICY_FILE" ]; then
  fail "Không tìm thấy audit policy file" \
       "Tạo file tại /etc/kubernetes/audit/audit-policy.yaml hoặc /tmp/audit-policy.yaml"
else
  echo "       Tìm thấy policy file: $POLICY_FILE"

  # Kiểm tra cú pháp YAML cơ bản
  if ! grep -q "apiVersion: audit.k8s.io/v1" "$POLICY_FILE"; then
    fail "File '$POLICY_FILE' không có apiVersion: audit.k8s.io/v1" \
         "Đảm bảo file bắt đầu với 'apiVersion: audit.k8s.io/v1' và 'kind: Policy'"
  elif ! grep -q "kind: Policy" "$POLICY_FILE"; then
    fail "File '$POLICY_FILE' không có kind: Policy" \
         "Đảm bảo file có 'kind: Policy'"
  elif ! grep -q "RequestResponse" "$POLICY_FILE"; then
    fail "File '$POLICY_FILE' không chứa rule với level 'RequestResponse'" \
         "Thêm rule: level: RequestResponse cho resources: [\"secrets\"]"
  else
    # Kiểm tra RequestResponse được áp dụng cho secrets
    # Tìm block chứa cả RequestResponse và secrets
    if python3 -c "
import yaml, sys
with open('$POLICY_FILE') as f:
    policy = yaml.safe_load(f)
rules = policy.get('rules', [])
for rule in rules:
    if rule.get('level') == 'RequestResponse':
        for res in rule.get('resources', []):
            if 'secrets' in res.get('resources', []):
                sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
      pass "Audit policy file '$POLICY_FILE' tồn tại và có rule RequestResponse cho secrets"
    elif grep -A5 "RequestResponse" "$POLICY_FILE" | grep -q "secrets"; then
      pass "Audit policy file '$POLICY_FILE' tồn tại và có rule RequestResponse cho secrets"
    else
      fail "File '$POLICY_FILE' có RequestResponse nhưng không áp dụng cho 'secrets'" \
           "Đảm bảo rule RequestResponse có resources: [{group: \"\", resources: [\"secrets\"]}]"
    fi
  fi
fi

echo ""

# --- Tiêu chí 2: Policy file chứa rule Metadata cho các thao tác còn lại ---

echo "Kiểm tra tiêu chí 2: Audit policy file có rule Metadata cho các thao tác còn lại"

if [ -z "$POLICY_FILE" ]; then
  fail "Không tìm thấy audit policy file — bỏ qua kiểm tra Metadata" ""
elif ! grep -q "Metadata" "$POLICY_FILE"; then
  fail "File '$POLICY_FILE' không chứa rule với level 'Metadata'" \
       "Thêm rule cuối: level: Metadata (không có resources filter) để bắt tất cả thao tác còn lại"
else
  pass "Audit policy file '$POLICY_FILE' có rule Metadata cho các thao tác còn lại"
fi

echo ""

# --- Tiêu chí 3: Audit log được ghi ra file hoặc policy được cấu hình đúng ---

echo "Kiểm tra tiêu chí 3: Audit logging được cấu hình (log file hoặc policy syntax hợp lệ)"

AUDIT_LOG_FILE="/var/log/kubernetes/audit/audit.log"
APISERVER_MANIFEST="/etc/kubernetes/manifests/kube-apiserver.yaml"

if [ -f "$AUDIT_LOG_FILE" ] && [ -s "$AUDIT_LOG_FILE" ]; then
  # Log file tồn tại và không rỗng
  LOG_LINES=$(wc -l < "$AUDIT_LOG_FILE" 2>/dev/null || echo "0")
  pass "Audit log file '$AUDIT_LOG_FILE' tồn tại và có ${LOG_LINES} dòng log"
elif [ -f "$APISERVER_MANIFEST" ] && grep -q "audit-policy-file" "$APISERVER_MANIFEST" 2>/dev/null; then
  # kube-apiserver manifest đã được cấu hình với audit flags
  POLICY_FLAG=$(grep "audit-policy-file" "$APISERVER_MANIFEST" | head -1 | tr -d ' ')
  pass "kube-apiserver manifest đã được cấu hình với audit logging ($POLICY_FLAG)"
elif [ -n "$POLICY_FILE" ]; then
  # Policy file tồn tại — kiểm tra cú pháp hợp lệ
  if python3 -c "
import yaml, sys
with open('$POLICY_FILE') as f:
    policy = yaml.safe_load(f)
assert policy.get('apiVersion') == 'audit.k8s.io/v1'
assert policy.get('kind') == 'Policy'
assert len(policy.get('rules', [])) > 0
sys.exit(0)
" 2>/dev/null; then
    pass "Audit policy file '$POLICY_FILE' có cú pháp YAML hợp lệ và sẵn sàng để cấu hình vào kube-apiserver"
    echo "       Lưu ý: Để hoàn thành đầy đủ, hãy cấu hình kube-apiserver với --audit-policy-file và --audit-log-path"
  else
    fail "Audit policy file '$POLICY_FILE' có lỗi cú pháp YAML" \
         "Kiểm tra lại cú pháp YAML: python3 -c \"import yaml; yaml.safe_load(open('$POLICY_FILE'))\""
  fi
else
  fail "Audit logging chưa được cấu hình" \
       "Tạo policy file và cấu hình kube-apiserver với --audit-policy-file và --audit-log-path"
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
  echo "Chúc mừng! Bạn đã hoàn thành Lab 2.2."
  echo "Tiếp theo: Đọc phần 'Giải thích' trong README.md"
  echo "Dọn dẹp: bash cleanup.sh"
  exit 0
fi
