#!/bin/bash
# Lab 1.4 – CIS Benchmark với kube-bench
# Script kiểm tra kết quả bài lab

PASS=0
FAIL=0
FAILED=0

echo "=========================================="
echo " Lab 1.4 – Kiểm tra kết quả"
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

# --- Tiêu chí 1: kube-bench đã được cài đặt ---

echo "Kiểm tra tiêu chí 1: kube-bench đã được cài đặt"

if command -v kube-bench &>/dev/null; then
  pass "kube-bench đã được cài đặt tại $(command -v kube-bench)"
else
  fail "kube-bench chưa được cài đặt hoặc không có trong PATH" \
       "curl -L https://github.com/aquasecurity/kube-bench/releases/latest/download/kube-bench_linux_amd64.tar.gz | tar xz && sudo mv kube-bench /usr/local/bin/"
fi

echo ""

# --- Tiêu chí 2: kube-apiserver có --profiling=false ---

echo "Kiểm tra tiêu chí 2: kube-apiserver có flag --profiling=false"

# Phương pháp 1: Kiểm tra qua kubectl (pod spec)
APISERVER_POD=$(kubectl get pods -n kube-system -l component=kube-apiserver -o name 2>/dev/null | head -1)

if [ -n "$APISERVER_POD" ]; then
  PROFILING_FLAG=$(kubectl get "$APISERVER_POD" -n kube-system -o jsonpath='{.spec.containers[0].command}' 2>/dev/null | tr ',' '\n' | grep "profiling" || true)

  if echo "$PROFILING_FLAG" | grep -q "profiling=false"; then
    pass "kube-apiserver đang chạy với --profiling=false"
  elif echo "$PROFILING_FLAG" | grep -q "profiling=true"; then
    fail "kube-apiserver có --profiling=true (cần đổi thành false)" \
         "Sửa /etc/kubernetes/manifests/kube-apiserver.yaml: thay --profiling=true thành --profiling=false"
  else
    fail "kube-apiserver không có flag --profiling (mặc định là true)" \
         "Thêm '--profiling=false' vào /etc/kubernetes/manifests/kube-apiserver.yaml"
  fi
else
  # Phương pháp 2: Kiểm tra manifest trực tiếp
  APISERVER_MANIFEST="/etc/kubernetes/manifests/kube-apiserver.yaml"
  if [ -f "$APISERVER_MANIFEST" ]; then
    if grep -q "\-\-profiling=false" "$APISERVER_MANIFEST"; then
      pass "kube-apiserver manifest có --profiling=false"
    else
      fail "kube-apiserver manifest không có --profiling=false" \
           "Thêm '- --profiling=false' vào command section trong $APISERVER_MANIFEST"
    fi
  else
    fail "Không tìm thấy kube-apiserver pod hoặc manifest" \
         "Đảm bảo đang chạy trên control-plane node và kube-apiserver đang hoạt động"
  fi
fi

echo ""

# --- Tiêu chí 3: kube-apiserver có --anonymous-auth=false ---

echo "Kiểm tra tiêu chí 3: kube-apiserver có flag --anonymous-auth=false"

if [ -n "$APISERVER_POD" ]; then
  ANON_FLAG=$(kubectl get "$APISERVER_POD" -n kube-system -o jsonpath='{.spec.containers[0].command}' 2>/dev/null | tr ',' '\n' | grep "anonymous-auth" || true)

  if echo "$ANON_FLAG" | grep -q "anonymous-auth=false"; then
    pass "kube-apiserver đang chạy với --anonymous-auth=false"
  elif echo "$ANON_FLAG" | grep -q "anonymous-auth=true"; then
    fail "kube-apiserver có --anonymous-auth=true (cần đổi thành false)" \
         "Sửa /etc/kubernetes/manifests/kube-apiserver.yaml: thay --anonymous-auth=true thành --anonymous-auth=false"
  else
    fail "kube-apiserver không có flag --anonymous-auth (mặc định là true)" \
         "Thêm '--anonymous-auth=false' vào /etc/kubernetes/manifests/kube-apiserver.yaml"
  fi
else
  APISERVER_MANIFEST="/etc/kubernetes/manifests/kube-apiserver.yaml"
  if [ -f "$APISERVER_MANIFEST" ]; then
    if grep -q "\-\-anonymous-auth=false" "$APISERVER_MANIFEST"; then
      pass "kube-apiserver manifest có --anonymous-auth=false"
    else
      fail "kube-apiserver manifest không có --anonymous-auth=false" \
           "Thêm '- --anonymous-auth=false' vào command section trong $APISERVER_MANIFEST"
    fi
  else
    fail "Không tìm thấy kube-apiserver pod hoặc manifest" \
         "Đảm bảo đang chạy trên control-plane node và kube-apiserver đang hoạt động"
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
  echo "Chúc mừng! Bạn đã hoàn thành Lab 1.4."
  echo "Tiếp theo: Đọc phần 'Giải thích' trong README.md"
  echo "Dọn dẹp: bash cleanup.sh"
  exit 0
fi
