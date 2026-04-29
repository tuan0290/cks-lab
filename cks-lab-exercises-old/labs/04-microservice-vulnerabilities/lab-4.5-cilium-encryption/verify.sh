#!/bin/bash
# Lab 4.5 – Pod-to-Pod Encryption với Cilium
# Script kiểm tra kết quả bài lab

PASS=0
FAIL=0
FAILED=0

echo "=========================================="
echo " Lab 4.5 – Kiểm tra kết quả"
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

# --- Tiêu chí 1: Cilium đang chạy trong kube-system ---

echo "Kiểm tra tiêu chí 1: Cilium đang chạy trong namespace kube-system"

CILIUM_RUNNING=$(kubectl get pods -n kube-system -l k8s-app=cilium \
  --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)

if [ "$CILIUM_RUNNING" -gt 0 ]; then
  pass "Cilium đang chạy ($CILIUM_RUNNING pod(s) ở trạng thái Running)"
else
  CILIUM_TOTAL=$(kubectl get pods -n kube-system -l k8s-app=cilium --no-headers 2>/dev/null | wc -l)
  if [ "$CILIUM_TOTAL" -gt 0 ]; then
    fail "Cilium pods tồn tại nhưng không ở trạng thái Running ($CILIUM_TOTAL pod(s))" \
         "kubectl get pods -n kube-system -l k8s-app=cilium để xem trạng thái"
  else
    fail "Không tìm thấy Cilium pods trong namespace kube-system" \
         "Cài đặt Cilium: helm install cilium cilium/cilium --namespace kube-system"
  fi
fi

echo ""

# --- Tiêu chí 2: CiliumNetworkPolicy tồn tại trong cilium-lab ---

echo "Kiểm tra tiêu chí 2: CiliumNetworkPolicy tồn tại trong namespace cilium-lab"

# Kiểm tra CRD tồn tại
if ! kubectl get crd ciliumnetworkpolicies.cilium.io &>/dev/null; then
  fail "CRD CiliumNetworkPolicy không tồn tại — Cilium chưa được cài đặt đúng cách" \
       "Cài đặt Cilium để có CiliumNetworkPolicy CRD"
else
  # Kiểm tra namespace tồn tại
  if ! kubectl get namespace cilium-lab &>/dev/null; then
    fail "Namespace 'cilium-lab' không tồn tại" \
         "Chạy setup.sh để tạo namespace: bash setup.sh"
  else
    CNP_COUNT=$(kubectl get ciliumnetworkpolicy -n cilium-lab --no-headers 2>/dev/null | wc -l)
    if [ "$CNP_COUNT" -gt 0 ]; then
      CNP_NAMES=$(kubectl get ciliumnetworkpolicy -n cilium-lab -o name 2>/dev/null | tr '\n' ' ')
      pass "CiliumNetworkPolicy tồn tại trong namespace 'cilium-lab': $CNP_NAMES"
    else
      fail "Không tìm thấy CiliumNetworkPolicy trong namespace 'cilium-lab'" \
           "Tạo CiliumNetworkPolicy: kubectl apply -f <policy.yaml> -n cilium-lab (xem README.md Bước 5)"
    fi
  fi
fi

echo ""

# --- Tiêu chí 3: Cilium encryption mode được bật ---

echo "Kiểm tra tiêu chí 3: Cilium encryption mode được bật"

# Kiểm tra ConfigMap cilium-config
CILIUM_CONFIG=$(kubectl get configmap cilium-config -n kube-system -o json 2>/dev/null)

if [ -z "$CILIUM_CONFIG" ]; then
  fail "Không tìm thấy ConfigMap 'cilium-config' trong kube-system" \
       "Đảm bảo Cilium đã được cài đặt đúng cách"
else
  # Kiểm tra WireGuard
  WIREGUARD_ENABLED=$(echo "$CILIUM_CONFIG" | grep -o '"enable-wireguard":"true"' 2>/dev/null || true)
  # Kiểm tra IPSec
  IPSEC_ENABLED=$(echo "$CILIUM_CONFIG" | grep -o '"enable-ipsec":"true"' 2>/dev/null || true)
  # Kiểm tra encryption flag chung
  ENCRYPTION_ENABLED=$(echo "$CILIUM_CONFIG" | grep -o '"encryption"' 2>/dev/null || true)

  if [ -n "$WIREGUARD_ENABLED" ]; then
    pass "Cilium WireGuard encryption đã được bật (enable-wireguard: true)"
  elif [ -n "$IPSEC_ENABLED" ]; then
    pass "Cilium IPSec encryption đã được bật (enable-ipsec: true)"
  else
    # Kiểm tra qua Cilium pod status
    CILIUM_POD=$(kubectl get pods -n kube-system -l k8s-app=cilium -o name 2>/dev/null | head -1)
    if [ -n "$CILIUM_POD" ]; then
      ENCRYPT_STATUS=$(kubectl exec "$CILIUM_POD" -n kube-system -- cilium status 2>/dev/null | \
        grep -i "encryption\|wireguard" || true)
      if echo "$ENCRYPT_STATUS" | grep -qi "wireguard\|ipsec\|enabled"; then
        pass "Cilium encryption đang hoạt động (xác nhận qua cilium status)"
      else
        fail "Cilium encryption chưa được bật" \
             "Patch ConfigMap: kubectl patch configmap cilium-config -n kube-system --type merge -p '{\"data\":{\"enable-wireguard\":\"true\"}}' && kubectl rollout restart daemonset/cilium -n kube-system"
      fi
    else
      fail "Cilium encryption chưa được bật trong ConfigMap" \
           "Xem README.md Bước 2 để bật WireGuard encryption"
    fi
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
  echo "Chúc mừng! Bạn đã hoàn thành Lab 4.5."
  echo "Tiếp theo: Đọc phần 'Giải thích' trong README.md"
  echo "Dọn dẹp: bash cleanup.sh"
  exit 0
fi
