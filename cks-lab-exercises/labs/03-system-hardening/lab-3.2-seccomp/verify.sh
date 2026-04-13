#!/bin/bash
# Lab 3.2 – Seccomp
# Script kiểm tra kết quả bài lab

PASS=0
FAIL=0
FAILED=0

echo "=========================================="
echo " Lab 3.2 – Kiểm tra kết quả"
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

# --- Tiêu chí 1: Pod hardened-pod tồn tại và đang Running ---

echo "Kiểm tra tiêu chí 1: Pod 'hardened-pod' tồn tại trong namespace 'seccomp-lab' và đang Running"

if kubectl get pod hardened-pod -n seccomp-lab &>/dev/null; then
  POD_STATUS=$(kubectl get pod hardened-pod -n seccomp-lab \
    -o jsonpath='{.status.phase}' 2>/dev/null)

  if [ "$POD_STATUS" = "Running" ]; then
    pass "Pod 'hardened-pod' tồn tại trong namespace 'seccomp-lab' và đang Running"
  else
    fail "Pod 'hardened-pod' tồn tại nhưng không ở trạng thái Running (hiện tại: ${POD_STATUS})" \
         "kubectl describe pod hardened-pod -n seccomp-lab để xem lý do"
  fi
else
  fail "Pod 'hardened-pod' không tìm thấy trong namespace 'seccomp-lab'" \
       "Tạo pod với seccompProfile và SecurityContext đúng theo README.md"
fi

echo ""

# --- Tiêu chí 2: Pod có seccompProfile đúng ---

echo "Kiểm tra tiêu chí 2: Pod có seccompProfile type=Localhost và localhostProfile=profiles/deny-write.json"

SECCOMP_TYPE=$(kubectl get pod hardened-pod -n seccomp-lab \
  -o jsonpath='{.spec.securityContext.seccompProfile.type}' 2>/dev/null)

SECCOMP_PROFILE=$(kubectl get pod hardened-pod -n seccomp-lab \
  -o jsonpath='{.spec.securityContext.seccompProfile.localhostProfile}' 2>/dev/null)

SECCOMP_OK=1

if [ "$SECCOMP_TYPE" != "Localhost" ]; then
  fail "seccompProfile.type không đúng (hiện tại: '${SECCOMP_TYPE}', mong đợi: 'Localhost')" \
       "Đặt spec.securityContext.seccompProfile.type: Localhost"
  SECCOMP_OK=0
fi

if [ "$SECCOMP_PROFILE" != "profiles/deny-write.json" ]; then
  fail "seccompProfile.localhostProfile không đúng (hiện tại: '${SECCOMP_PROFILE}', mong đợi: 'profiles/deny-write.json')" \
       "Đặt spec.securityContext.seccompProfile.localhostProfile: profiles/deny-write.json"
  SECCOMP_OK=0
fi

if [ "$SECCOMP_OK" -eq 1 ]; then
  pass "Pod có seccompProfile: type=Localhost, localhostProfile=profiles/deny-write.json"
fi

echo ""

# --- Tiêu chí 3: Pod có SecurityContext đầy đủ ---

echo "Kiểm tra tiêu chí 3: Pod có SecurityContext đầy đủ (runAsNonRoot, allowPrivilegeEscalation, readOnlyRootFilesystem, capabilities.drop)"

SC_OK=1

# Kiểm tra runAsNonRoot (pod-level hoặc container-level)
RUN_AS_NON_ROOT=$(kubectl get pod hardened-pod -n seccomp-lab \
  -o jsonpath='{.spec.securityContext.runAsNonRoot}' 2>/dev/null)
CONTAINER_RUN_AS_NON_ROOT=$(kubectl get pod hardened-pod -n seccomp-lab \
  -o jsonpath='{.spec.containers[0].securityContext.runAsNonRoot}' 2>/dev/null)

if [ "$RUN_AS_NON_ROOT" != "true" ] && [ "$CONTAINER_RUN_AS_NON_ROOT" != "true" ]; then
  fail "runAsNonRoot không được đặt thành true (pod-level: '${RUN_AS_NON_ROOT}', container-level: '${CONTAINER_RUN_AS_NON_ROOT}')" \
       "Thêm runAsNonRoot: true vào spec.securityContext hoặc spec.containers[].securityContext"
  SC_OK=0
fi

# Kiểm tra allowPrivilegeEscalation: false (container-level)
ALLOW_PRIV_ESC=$(kubectl get pod hardened-pod -n seccomp-lab \
  -o jsonpath='{.spec.containers[0].securityContext.allowPrivilegeEscalation}' 2>/dev/null)

if [ "$ALLOW_PRIV_ESC" != "false" ]; then
  fail "allowPrivilegeEscalation không được đặt thành false (hiện tại: '${ALLOW_PRIV_ESC}')" \
       "Thêm allowPrivilegeEscalation: false vào spec.containers[].securityContext"
  SC_OK=0
fi

# Kiểm tra readOnlyRootFilesystem: true (container-level)
READ_ONLY_FS=$(kubectl get pod hardened-pod -n seccomp-lab \
  -o jsonpath='{.spec.containers[0].securityContext.readOnlyRootFilesystem}' 2>/dev/null)

if [ "$READ_ONLY_FS" != "true" ]; then
  fail "readOnlyRootFilesystem không được đặt thành true (hiện tại: '${READ_ONLY_FS}')" \
       "Thêm readOnlyRootFilesystem: true vào spec.containers[].securityContext"
  SC_OK=0
fi

# Kiểm tra capabilities.drop chứa ALL
CAPS_DROP=$(kubectl get pod hardened-pod -n seccomp-lab \
  -o jsonpath='{.spec.containers[0].securityContext.capabilities.drop}' 2>/dev/null)

if echo "$CAPS_DROP" | grep -qi "ALL"; then
  : # OK
else
  fail "capabilities.drop không chứa 'ALL' (hiện tại: '${CAPS_DROP}')" \
       "Thêm capabilities.drop: [ALL] vào spec.containers[].securityContext"
  SC_OK=0
fi

if [ "$SC_OK" -eq 1 ]; then
  pass "Pod có đầy đủ SecurityContext: runAsNonRoot=true, allowPrivilegeEscalation=false, readOnlyRootFilesystem=true, capabilities.drop=[ALL]"
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
  echo ""
  echo "Lưu ý: Nếu pod ở trạng thái Pending hoặc Error, kiểm tra Seccomp profile"
  echo "đã được copy vào đúng đường dẫn trên node worker:"
  echo "  ssh <node-worker> 'ls -la /var/lib/kubelet/seccomp/profiles/'"
  exit 1
else
  echo ""
  echo "Chúc mừng! Bạn đã hoàn thành Lab 3.2."
  echo "Tiếp theo: Đọc phần 'Giải thích' trong README.md"
  echo "Dọn dẹp: bash cleanup.sh"
  exit 0
fi
