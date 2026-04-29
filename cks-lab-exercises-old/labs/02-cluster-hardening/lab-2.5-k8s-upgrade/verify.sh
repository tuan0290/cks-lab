#!/bin/bash
# Lab 2.5 – Kubernetes Cluster Upgrade
# Script kiểm tra kết quả bài lab

PASS=0
FAIL=0
FAILED=0

echo "=========================================="
echo " Lab 2.5 – Kiểm tra kết quả"
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

if ! command -v kubectl &>/dev/null; then
  echo "[ERROR] kubectl không tìm thấy."
  exit 1
fi

if ! kubectl cluster-info &>/dev/null; then
  echo "[ERROR] Không thể kết nối đến cluster."
  exit 1
fi

# --- Tiêu chí 1: Tất cả node ở trạng thái Ready ---

echo "Kiểm tra tiêu chí 1: Tất cả node ở trạng thái Ready"

NOT_READY=$(kubectl get nodes --no-headers 2>/dev/null | grep -v " Ready " | wc -l)
TOTAL_NODES=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)

if [ "$NOT_READY" -eq 0 ] && [ "$TOTAL_NODES" -gt 0 ]; then
  pass "Tất cả ${TOTAL_NODES} node đang ở trạng thái Ready"
else
  fail "Có ${NOT_READY}/${TOTAL_NODES} node không ở trạng thái Ready" \
       "kubectl get nodes để xem chi tiết"
fi

echo ""

# --- Tiêu chí 2: Phiên bản kubelet đã được upgrade ---

echo "Kiểm tra tiêu chí 2: Phiên bản kubelet trên các node"

echo "Phiên bản kubelet hiện tại:"
kubectl get nodes -o custom-columns='NODE:.metadata.name,VERSION:.status.nodeInfo.kubeletVersion' 2>/dev/null

# Kiểm tra tất cả node có cùng phiên bản không (sau upgrade phải đồng nhất)
VERSIONS=$(kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo.kubeletVersion}' 2>/dev/null | tr ' ' '\n' | sort -u)
VERSION_COUNT=$(echo "$VERSIONS" | wc -l)

if [ "$VERSION_COUNT" -eq 1 ]; then
  CURRENT_VERSION=$(echo "$VERSIONS" | head -1)
  pass "Tất cả node đang chạy cùng phiên bản: ${CURRENT_VERSION}"
else
  fail "Các node đang chạy phiên bản khác nhau — upgrade chưa hoàn thành" \
       "Kiểm tra worker node chưa được upgrade: kubectl get nodes"
  echo "       Phiên bản hiện có:"
  echo "$VERSIONS" | while read v; do echo "         - $v"; done
fi

echo ""

# --- Tiêu chí 3: Tất cả pod kube-system đang Running ---

echo "Kiểm tra tiêu chí 3: Tất cả pod trong kube-system đang Running"

NOT_RUNNING=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | \
  grep -v -E "Running|Completed" | wc -l)
TOTAL_PODS=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | wc -l)

if [ "$NOT_RUNNING" -eq 0 ] && [ "$TOTAL_PODS" -gt 0 ]; then
  pass "Tất cả ${TOTAL_PODS} pod trong kube-system đang Running/Completed"
else
  fail "${NOT_RUNNING}/${TOTAL_PODS} pod trong kube-system không ở trạng thái Running" \
       "kubectl get pods -n kube-system để xem chi tiết"
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
  echo "Chúc mừng! Cluster đã được upgrade thành công."
  echo "Dọn dẹp: bash cleanup.sh"
  exit 0
fi
