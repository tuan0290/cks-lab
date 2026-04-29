#!/bin/bash
# Lab 6.4 – Behavioral Analytics với Falco
# Script kiểm tra kết quả bài lab

PASS=0
FAIL=0
FAILED=0

echo "=========================================="
echo " Lab 6.4 – Kiểm tra kết quả"
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

# --- Tiêu chí 1: Falco service đang chạy ---

echo "Kiểm tra tiêu chí 1: Falco service đang chạy"

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

# --- Tiêu chí 2: File rule tùy chỉnh tồn tại tại /etc/falco/rules.d/ ---

echo "Kiểm tra tiêu chí 2: File rule tùy chỉnh tồn tại tại /etc/falco/rules.d/"

RULES_DIR="/etc/falco/rules.d"
RULE_FOUND=0

if [ -d "$RULES_DIR" ]; then
  # Tìm bất kỳ file .yaml nào trong thư mục rules.d
  RULE_FILES=$(find "$RULES_DIR" -name "*.yaml" -o -name "*.yml" 2>/dev/null | head -5)
  if [ -n "$RULE_FILES" ]; then
    RULE_COUNT=$(echo "$RULE_FILES" | wc -l)
    RULE_FOUND=1
    pass "Tìm thấy ${RULE_COUNT} file rule tùy chỉnh trong ${RULES_DIR}"
    echo "       Files: $(echo "$RULE_FILES" | tr '\n' ' ')"
  else
    fail "Thư mục ${RULES_DIR} tồn tại nhưng không có file rule (.yaml/.yml)" \
         "Tạo rule file: sudo nano ${RULES_DIR}/behavioral-rules.yaml"
  fi
else
  fail "Thư mục ${RULES_DIR} không tồn tại" \
       "Tạo thư mục và rule file: sudo mkdir -p ${RULES_DIR} && sudo nano ${RULES_DIR}/behavioral-rules.yaml"
fi

echo ""

# --- Tiêu chí 3: /tmp/falco-alerts.log tồn tại và chứa ít nhất 1 dòng ---

echo "Kiểm tra tiêu chí 3: /tmp/falco-alerts.log tồn tại và chứa ít nhất 1 alert"

ALERTS_FILE="/tmp/falco-alerts.log"

if [ ! -f "$ALERTS_FILE" ]; then
  fail "File ${ALERTS_FILE} không tồn tại" \
       "Cấu hình Falco file output trong /etc/falco/falco.yaml và restart Falco, sau đó trigger behaviors: bash /tmp/trigger-behaviors.sh"
else
  LINE_COUNT=$(wc -l < "$ALERTS_FILE" 2>/dev/null || echo 0)
  if [ "${LINE_COUNT:-0}" -ge 1 ]; then
    pass "File ${ALERTS_FILE} tồn tại và chứa ${LINE_COUNT} dòng alert"
  else
    fail "File ${ALERTS_FILE} tồn tại nhưng rỗng (0 dòng)" \
         "Trigger behaviors để tạo alert: bash /tmp/trigger-behaviors.sh"
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
  echo "Chúc mừng! Bạn đã hoàn thành Lab 6.4."
  echo "Tiếp theo: Đọc phần 'Giải thích' trong README.md"
  echo "Dọn dẹp: bash cleanup.sh"
  exit 0
fi
