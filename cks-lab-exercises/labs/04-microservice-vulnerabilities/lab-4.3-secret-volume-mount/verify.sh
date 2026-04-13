#!/bin/bash
# Lab 4.3 – Secret Volume Mount
# Script kiểm tra kết quả bài lab

PASS=0
FAIL=0
FAILED=0

echo "=========================================="
echo " Lab 4.3 – Kiểm tra kết quả"
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

# --- Tiêu chí 1: Pod secure-app tồn tại và đang Running ---

echo "Kiểm tra tiêu chí 1: Pod 'secure-app' tồn tại trong namespace 'secret-lab' và đang Running"

if kubectl get pod secure-app -n secret-lab &>/dev/null; then
  POD_STATUS=$(kubectl get pod secure-app -n secret-lab \
    -o jsonpath='{.status.phase}' 2>/dev/null)

  if [ "$POD_STATUS" = "Running" ]; then
    pass "Pod 'secure-app' tồn tại trong namespace 'secret-lab' và đang Running"
  else
    fail "Pod 'secure-app' tồn tại nhưng không ở trạng thái Running (hiện tại: ${POD_STATUS})" \
         "kubectl describe pod secure-app -n secret-lab để xem lý do"
  fi
else
  fail "Pod 'secure-app' không tìm thấy trong namespace 'secret-lab'" \
       "Tạo pod với Secret volume mount: xem README.md Bước 3"
fi

echo ""

# --- Tiêu chí 2: Pod secure-app mount Secret dưới dạng volume (không phải env var) ---

echo "Kiểm tra tiêu chí 2: Pod 'secure-app' mount Secret 'app-credentials' dưới dạng volume"

# Kiểm tra volumes trong pod spec
VOLUME_SECRET=$(kubectl get pod secure-app -n secret-lab \
  -o jsonpath='{.spec.volumes[*].secret.secretName}' 2>/dev/null)

# Kiểm tra env var (cảnh báo nếu dùng)
ENV_SECRET=$(kubectl get pod secure-app -n secret-lab \
  -o jsonpath='{.spec.containers[0].env[*].valueFrom.secretKeyRef.name}' 2>/dev/null)

if echo "$VOLUME_SECRET" | grep -q "app-credentials"; then
  pass "Pod 'secure-app' mount Secret 'app-credentials' dưới dạng volume"

  # Cảnh báo nếu vẫn dùng env var
  if echo "$ENV_SECRET" | grep -q "app-credentials"; then
    warn "Pod 'secure-app' vẫn đang dùng Secret qua env var — nên xóa env var và chỉ dùng volume mount"
    warn "Rủi ro: Secret value có thể bị lộ qua 'kubectl describe pod' hoặc log"
  fi
else
  if echo "$ENV_SECRET" | grep -q "app-credentials"; then
    fail "Pod 'secure-app' đang dùng Secret 'app-credentials' qua env var thay vì volume mount" \
         "Xóa phần 'env' và thêm 'volumes' + 'volumeMounts' với secretName: app-credentials"
  else
    fail "Pod 'secure-app' không mount Secret 'app-credentials' (không tìm thấy volume hoặc env var)" \
         "Thêm volume với secret.secretName: app-credentials và volumeMount tương ứng"
  fi
fi

echo ""

# --- Tiêu chí 3: Volume mount có defaultMode: 0400 ---

echo "Kiểm tra tiêu chí 3: Volume mount có defaultMode: 0400 (chỉ owner đọc được)"

DEFAULT_MODE=$(kubectl get pod secure-app -n secret-lab \
  -o jsonpath='{.spec.volumes[*].secret.defaultMode}' 2>/dev/null)

if [ -z "$DEFAULT_MODE" ]; then
  # Thử lấy từ items mode
  ITEMS_MODE=$(kubectl get pod secure-app -n secret-lab \
    -o jsonpath='{.spec.volumes[*].secret.items[*].mode}' 2>/dev/null)

  if [ -n "$ITEMS_MODE" ] && echo "$ITEMS_MODE" | grep -q "256"; then
    # 256 decimal = 0400 octal
    pass "Volume mount có mode 0400 (256 decimal) được cấu hình cho các items"
  else
    fail "Volume mount không có defaultMode: 0400 được cấu hình" \
         "Thêm 'defaultMode: 0400' vào spec.volumes[].secret trong pod spec"
  fi
elif [ "$DEFAULT_MODE" = "256" ]; then
  # 256 decimal = 0400 octal
  pass "Volume mount có defaultMode: 0400 (256 decimal) — chỉ owner đọc được"
else
  # Chuyển đổi để hiển thị octal
  OCTAL_MODE=$(printf '%o' "$DEFAULT_MODE" 2>/dev/null || echo "$DEFAULT_MODE")
  fail "Volume mount có defaultMode: 0${OCTAL_MODE} (mong đợi: 0400)" \
       "Sửa defaultMode thành 0400 trong spec.volumes[].secret"
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
  echo "Chúc mừng! Bạn đã hoàn thành Lab 4.3."
  echo "Tiếp theo: Đọc phần 'Giải thích' trong README.md"
  echo "Dọn dẹp: bash cleanup.sh"
  exit 0
fi
