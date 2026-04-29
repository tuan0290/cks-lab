#!/bin/bash
# Lab 6.1 – Falco Rules
# Script kiểm tra kết quả bài lab

PASS=0
FAIL=0
FAILED=0

echo "=========================================="
echo " Lab 6.1 – Kiểm tra kết quả"
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

# --- Tiêu chí 1: Falco đang chạy ---

echo "Kiểm tra tiêu chí 1: Falco đang chạy (systemd service hoặc DaemonSet)"

FALCO_RUNNING=0

# Kiểm tra systemd service
if systemctl is-active falco &>/dev/null 2>&1; then
  FALCO_RUNNING=1
  pass "Falco systemd service đang chạy (active)"
fi

# Kiểm tra DaemonSet trong namespace falco
if [ "$FALCO_RUNNING" -eq 0 ]; then
  if kubectl get daemonset falco -n falco &>/dev/null 2>&1; then
    DESIRED=$(kubectl get daemonset falco -n falco -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null)
    READY=$(kubectl get daemonset falco -n falco -o jsonpath='{.status.numberReady}' 2>/dev/null)
    if [ -n "$DESIRED" ] && [ "$DESIRED" -gt 0 ] && [ "$DESIRED" = "$READY" ]; then
      FALCO_RUNNING=1
      pass "Falco DaemonSet đang chạy trong namespace 'falco' (${READY}/${DESIRED} pods ready)"
    else
      fail "Falco DaemonSet tồn tại nhưng chưa sẵn sàng (${READY:-0}/${DESIRED:-0} pods ready)" \
           "kubectl rollout status daemonset/falco -n falco"
    fi
  fi
fi

# Kiểm tra pod falco trong bất kỳ namespace nào
if [ "$FALCO_RUNNING" -eq 0 ]; then
  FALCO_PODS=$(kubectl get pods --all-namespaces -l app=falco --no-headers 2>/dev/null | grep -c "Running" || true)
  if [ "${FALCO_PODS:-0}" -gt 0 ]; then
    FALCO_RUNNING=1
    pass "Falco pods đang chạy trong cluster (${FALCO_PODS} pods Running)"
  fi
fi

if [ "$FALCO_RUNNING" -eq 0 ]; then
  fail "Falco không tìm thấy hoặc không đang chạy" \
       "Cài đặt Falco: helm install falco falcosecurity/falco --namespace falco --create-namespace"
fi

echo ""

# --- Tiêu chí 2: Custom rule file tồn tại và chứa shell spawn detection ---

echo "Kiểm tra tiêu chí 2: /tmp/custom-rules.yaml tồn tại và chứa shell spawn detection rule"

if [ ! -f /tmp/custom-rules.yaml ]; then
  fail "File /tmp/custom-rules.yaml không tìm thấy" \
       "Chạy setup.sh để tạo file: bash setup.sh"
else
  # Kiểm tra file chứa rule phát hiện shell
  RULE_OK=0
  if grep -qi "shell" /tmp/custom-rules.yaml && grep -qi "container" /tmp/custom-rules.yaml; then
    RULE_OK=1
  fi
  if grep -qi "spawned_process\|proc.name\|shell_binaries\|bash\|/bin/sh" /tmp/custom-rules.yaml; then
    RULE_OK=1
  fi

  if [ "$RULE_OK" -eq 1 ]; then
    pass "File /tmp/custom-rules.yaml tồn tại và chứa shell spawn detection rule"
  else
    fail "File /tmp/custom-rules.yaml tồn tại nhưng không chứa shell spawn detection rule" \
         "Thêm rule phát hiện shell: xem README.md phần Gợi ý 1"
  fi
fi

echo ""

# --- Tiêu chí 3: Namespace falco-lab tồn tại ---

echo "Kiểm tra tiêu chí 3: Namespace 'falco-lab' tồn tại với pod test"

if kubectl get namespace falco-lab &>/dev/null; then
  # Kiểm tra pod test-pod
  if kubectl get pod test-pod -n falco-lab &>/dev/null; then
    POD_STATUS=$(kubectl get pod test-pod -n falco-lab -o jsonpath='{.status.phase}' 2>/dev/null)
    if [ "$POD_STATUS" = "Running" ]; then
      pass "Namespace 'falco-lab' tồn tại và pod 'test-pod' đang Running"
    else
      pass "Namespace 'falco-lab' tồn tại và pod 'test-pod' tồn tại (status: ${POD_STATUS})"
    fi
  else
    pass "Namespace 'falco-lab' tồn tại (pod test-pod chưa được tạo)"
  fi
else
  fail "Namespace 'falco-lab' không tìm thấy" \
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
  echo "Chúc mừng! Bạn đã hoàn thành Lab 6.1."
  echo "Tiếp theo: Đọc phần 'Giải thích' trong README.md"
  echo "Dọn dẹp: bash cleanup.sh"
  exit 0
fi
