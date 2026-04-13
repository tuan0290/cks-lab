#!/bin/bash
# Lab 4.4 – RuntimeClass Sandbox
# Script kiểm tra kết quả bài lab

PASS=0
FAIL=0
FAILED=0

echo "=========================================="
echo " Lab 4.4 – Kiểm tra kết quả"
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

# --- Tiêu chí 1: RuntimeClass gvisor tồn tại với handler runsc ---

echo "Kiểm tra tiêu chí 1: RuntimeClass 'gvisor' tồn tại với handler 'runsc'"

if kubectl get runtimeclass gvisor &>/dev/null; then
  HANDLER=$(kubectl get runtimeclass gvisor \
    -o jsonpath='{.handler}' 2>/dev/null)

  if [ "$HANDLER" = "runsc" ]; then
    pass "RuntimeClass 'gvisor' tồn tại với handler 'runsc'"
  else
    fail "RuntimeClass 'gvisor' tồn tại nhưng handler không đúng (hiện tại: '${HANDLER}', mong đợi: 'runsc')" \
         "Xóa và tạo lại: kubectl delete runtimeclass gvisor && kubectl apply -f /tmp/gvisor-runtimeclass.yaml"
  fi
else
  fail "RuntimeClass 'gvisor' không tìm thấy trong cluster" \
       "Tạo RuntimeClass: kubectl apply -f /tmp/gvisor-runtimeclass.yaml"
fi

echo ""

# --- Tiêu chí 2: Pod sandboxed-pod tồn tại trong namespace runtime-lab ---

echo "Kiểm tra tiêu chí 2: Pod 'sandboxed-pod' tồn tại trong namespace 'runtime-lab'"

if kubectl get pod sandboxed-pod -n runtime-lab &>/dev/null; then
  POD_STATUS=$(kubectl get pod sandboxed-pod -n runtime-lab \
    -o jsonpath='{.status.phase}' 2>/dev/null)

  if [ "$POD_STATUS" = "Running" ]; then
    pass "Pod 'sandboxed-pod' tồn tại trong namespace 'runtime-lab' và đang Running"
  elif [ "$POD_STATUS" = "Pending" ]; then
    pass "Pod 'sandboxed-pod' tồn tại trong namespace 'runtime-lab' (trạng thái: Pending — gVisor có thể chưa được cài đặt trên node)"
    warn "Pod ở trạng thái Pending — đây là bình thường nếu gVisor chưa được cài đặt trên node"
    warn "Kiểm tra lý do: kubectl describe pod sandboxed-pod -n runtime-lab"
  else
    fail "Pod 'sandboxed-pod' tồn tại nhưng ở trạng thái không mong đợi (hiện tại: ${POD_STATUS})" \
         "kubectl describe pod sandboxed-pod -n runtime-lab để xem lý do"
  fi
else
  fail "Pod 'sandboxed-pod' không tìm thấy trong namespace 'runtime-lab'" \
       "Tạo pod với runtimeClassName: gvisor — xem README.md Bước 3"
fi

echo ""

# --- Tiêu chí 3: Pod sandboxed-pod có runtimeClassName: gvisor ---

echo "Kiểm tra tiêu chí 3: Pod 'sandboxed-pod' có runtimeClassName: gvisor"

RUNTIME_CLASS=$(kubectl get pod sandboxed-pod -n runtime-lab \
  -o jsonpath='{.spec.runtimeClassName}' 2>/dev/null)

if [ -z "$RUNTIME_CLASS" ]; then
  fail "Pod 'sandboxed-pod' không có runtimeClassName được cấu hình" \
       "Thêm 'runtimeClassName: gvisor' vào spec của pod"
elif [ "$RUNTIME_CLASS" = "gvisor" ]; then
  pass "Pod 'sandboxed-pod' có runtimeClassName: gvisor"
else
  fail "Pod 'sandboxed-pod' có runtimeClassName không đúng (hiện tại: '${RUNTIME_CLASS}', mong đợi: 'gvisor')" \
       "Xóa pod và tạo lại với runtimeClassName: gvisor"
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
  echo "Chúc mừng! Bạn đã hoàn thành Lab 4.4."
  echo "Tiếp theo: Đọc phần 'Giải thích' trong README.md"
  echo "Dọn dẹp: bash cleanup.sh"
  exit 0
fi
