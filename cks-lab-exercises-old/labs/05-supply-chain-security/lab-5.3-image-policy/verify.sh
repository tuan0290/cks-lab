#!/bin/bash
# Lab 5.3 – ImagePolicyWebhook Setup
# Script kiểm tra kết quả bài lab

PASS=0
FAIL=0
FAILED=0

POLICY_DIR="/etc/kubernetes/policywebhook"
APISERVER_MANIFEST="/etc/kubernetes/manifests/kube-apiserver.yaml"

echo "=========================================="
echo " Lab 5.3 – Kiểm tra kết quả"
echo "=========================================="
echo ""

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

# --- Tiêu chí 1: admission_config.json tồn tại và có allowTTL=100 ---

echo "Kiểm tra tiêu chí 1: admission_config.json có allowTTL=100"

if [ ! -f "$POLICY_DIR/admission_config.json" ]; then
  fail "Không tìm thấy $POLICY_DIR/admission_config.json" \
       "Chạy setup.sh để tạo file mẫu: bash setup.sh"
else
  ALLOW_TTL=$(python3 -c "import json; d=json.load(open('$POLICY_DIR/admission_config.json')); print(d['plugins'][0]['configuration']['imagePolicy']['allowTTL'])" 2>/dev/null || echo "")
  if [ "$ALLOW_TTL" = "100" ]; then
    pass "admission_config.json có allowTTL=100"
  else
    fail "admission_config.json có allowTTL=$ALLOW_TTL (cần 100)" \
         "Sửa allowTTL thành 100 trong $POLICY_DIR/admission_config.json"
  fi
fi

echo ""

# --- Tiêu chí 2: defaultAllow=false ---

echo "Kiểm tra tiêu chí 2: admission_config.json có defaultAllow=false"

if [ -f "$POLICY_DIR/admission_config.json" ]; then
  DEFAULT_ALLOW=$(python3 -c "import json; d=json.load(open('$POLICY_DIR/admission_config.json')); print(str(d['plugins'][0]['configuration']['imagePolicy']['defaultAllow']).lower())" 2>/dev/null || echo "")
  if [ "$DEFAULT_ALLOW" = "false" ]; then
    pass "admission_config.json có defaultAllow=false"
  else
    fail "admission_config.json có defaultAllow=$DEFAULT_ALLOW (cần false)" \
         "Đặt defaultAllow=false để block Pod khi external service không reachable"
  fi
else
  fail "Không tìm thấy $POLICY_DIR/admission_config.json" ""
fi

echo ""

# --- Tiêu chí 3: kubeconf trỏ đúng server https://localhost:1234 ---

echo "Kiểm tra tiêu chí 3: kubeconf trỏ đến https://localhost:1234"

if [ ! -f "$POLICY_DIR/kubeconf" ]; then
  fail "Không tìm thấy $POLICY_DIR/kubeconf" \
       "Chạy setup.sh để tạo file mẫu: bash setup.sh"
else
  if grep -q "https://localhost:1234" "$POLICY_DIR/kubeconf"; then
    pass "kubeconf trỏ đến https://localhost:1234"
  else
    SERVER=$(grep "server:" "$POLICY_DIR/kubeconf" | awk '{print $2}')
    fail "kubeconf trỏ đến '$SERVER' (cần https://localhost:1234)" \
         "Sửa server: https://localhost:1234 trong $POLICY_DIR/kubeconf"
  fi
fi

echo ""

# --- Tiêu chí 4: kube-apiserver có ImagePolicyWebhook admission plugin ---

echo "Kiểm tra tiêu chí 4: kube-apiserver bật ImagePolicyWebhook admission plugin"

if [ ! -f "$APISERVER_MANIFEST" ]; then
  fail "Không tìm thấy $APISERVER_MANIFEST" \
       "Lab này cần chạy trên control plane node"
else
  if grep -q "ImagePolicyWebhook" "$APISERVER_MANIFEST"; then
    pass "kube-apiserver có --enable-admission-plugins chứa ImagePolicyWebhook"
  else
    fail "kube-apiserver chưa bật ImagePolicyWebhook" \
         "Thêm --enable-admission-plugins=NodeRestriction,ImagePolicyWebhook vào $APISERVER_MANIFEST"
  fi
fi

echo ""

# --- Tiêu chí 5: kube-apiserver có --admission-control-config-file ---

echo "Kiểm tra tiêu chí 5: kube-apiserver có --admission-control-config-file"

if [ -f "$APISERVER_MANIFEST" ]; then
  if grep -q "admission-control-config-file" "$APISERVER_MANIFEST"; then
    pass "kube-apiserver có --admission-control-config-file được cấu hình"
  else
    fail "kube-apiserver thiếu --admission-control-config-file" \
         "Thêm --admission-control-config-file=/etc/kubernetes/policywebhook/admission_config.json"
  fi
else
  fail "Không tìm thấy $APISERVER_MANIFEST" ""
fi

echo ""

# --- Tiêu chí 6: Tạo Pod bị từ chối (external service không reachable) ---

echo "Kiểm tra tiêu chí 6: Tạo Pod bị từ chối khi external service không reachable"

if ! command -v kubectl &>/dev/null || ! kubectl cluster-info &>/dev/null 2>&1; then
  fail "kubectl không kết nối được — bỏ qua kiểm tra này" ""
else
  TEST_OUTPUT=$(kubectl run test-pod-verify --image=nginx --restart=Never -n default 2>&1 || true)
  kubectl delete pod test-pod-verify -n default --ignore-not-found=true &>/dev/null 2>&1 || true

  if echo "$TEST_OUTPUT" | grep -qi "forbidden\|connection refused\|dial tcp"; then
    pass "Pod bị từ chối — ImagePolicyWebhook đang hoạt động đúng"
  else
    fail "Pod không bị từ chối — ImagePolicyWebhook chưa hoạt động" \
         "Kiểm tra apiserver đã restart chưa: watch crictl ps"
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
  echo "Chúc mừng! Bạn đã hoàn thành Lab 5.3."
  echo "Dọn dẹp: bash cleanup.sh"
  exit 0
fi
