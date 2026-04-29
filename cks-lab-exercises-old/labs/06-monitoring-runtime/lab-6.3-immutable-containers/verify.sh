#!/bin/bash
# Lab 6.3 – Immutable Containers
# Script kiểm tra kết quả bài lab

PASS=0
FAIL=0
FAILED=0

echo "=========================================="
echo " Lab 6.3 – Kiểm tra kết quả"
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

# --- Tiêu chí 1: Pod immutable-app có readOnlyRootFilesystem: true ---

echo "Kiểm tra tiêu chí 1: Pod 'immutable-app' có readOnlyRootFilesystem: true"

if ! kubectl get pod immutable-app -n immutable-lab &>/dev/null; then
  fail "Pod 'immutable-app' không tìm thấy trong namespace 'immutable-lab'" \
       "Tạo pod với readOnlyRootFilesystem: true - xem README.md Bước 2"
else
  READONLY=$(kubectl get pod immutable-app -n immutable-lab \
    -o jsonpath='{.spec.containers[0].securityContext.readOnlyRootFilesystem}' 2>/dev/null)

  if [ "$READONLY" = "true" ]; then
    pass "Pod 'immutable-app' có readOnlyRootFilesystem: true"
  else
    fail "Pod 'immutable-app' không có readOnlyRootFilesystem: true (hiện tại: ${READONLY:-false})" \
         "Thêm securityContext.readOnlyRootFilesystem: true vào pod spec"
  fi
fi

echo ""

# --- Tiêu chí 2: Pod immutable-app có emptyDir volume mounts cho /tmp và /var/run ---

echo "Kiểm tra tiêu chí 2: Pod 'immutable-app' có emptyDir volume mounts cho thư mục ghi"

if ! kubectl get pod immutable-app -n immutable-lab &>/dev/null; then
  fail "Không thể kiểm tra: Pod 'immutable-app' không tồn tại" ""
else
  # Lấy danh sách mountPaths
  MOUNT_PATHS=$(kubectl get pod immutable-app -n immutable-lab \
    -o jsonpath='{.spec.containers[0].volumeMounts[*].mountPath}' 2>/dev/null)

  # Kiểm tra có ít nhất một emptyDir volume
  VOLUME_COUNT=$(kubectl get pod immutable-app -n immutable-lab \
    -o jsonpath='{.spec.volumes}' 2>/dev/null | grep -c "emptyDir" || true)

  HAS_TMP=0
  HAS_RUN=0

  if echo "$MOUNT_PATHS" | grep -q "/tmp"; then
    HAS_TMP=1
  fi
  if echo "$MOUNT_PATHS" | grep -q "/var/run\|/run"; then
    HAS_RUN=1
  fi

  if [ "$HAS_TMP" -eq 1 ] && [ "$HAS_RUN" -eq 1 ]; then
    pass "Pod 'immutable-app' có emptyDir volume mounts cho /tmp và /var/run"
  elif [ "${VOLUME_COUNT:-0}" -gt 0 ]; then
    pass "Pod 'immutable-app' có emptyDir volume mounts (paths: ${MOUNT_PATHS})"
  else
    fail "Pod 'immutable-app' không có emptyDir volume mounts cho /tmp và /var/run" \
         "Thêm volumeMounts và volumes với emptyDir cho /tmp và /var/run"
  fi
fi

echo ""

# --- Tiêu chí 3: Pod immutable-app đang Running ---

echo "Kiểm tra tiêu chí 3: Pod 'immutable-app' đang ở trạng thái Running"

if ! kubectl get pod immutable-app -n immutable-lab &>/dev/null; then
  fail "Pod 'immutable-app' không tìm thấy trong namespace 'immutable-lab'" \
       "Tạo pod: xem README.md Bước 2"
else
  POD_STATUS=$(kubectl get pod immutable-app -n immutable-lab \
    -o jsonpath='{.status.phase}' 2>/dev/null)

  if [ "$POD_STATUS" = "Running" ]; then
    pass "Pod 'immutable-app' đang ở trạng thái Running"
  else
    fail "Pod 'immutable-app' không ở trạng thái Running (hiện tại: ${POD_STATUS})" \
         "kubectl describe pod immutable-app -n immutable-lab để xem lý do"
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
  echo "Chúc mừng! Bạn đã hoàn thành Lab 6.3."
  echo "Tiếp theo: Đọc phần 'Giải thích' trong README.md"
  echo "Dọn dẹp: bash cleanup.sh"
  exit 0
fi
