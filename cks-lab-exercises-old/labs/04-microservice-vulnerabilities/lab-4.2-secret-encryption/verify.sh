#!/bin/bash
# Lab 4.2 – Secret Encryption at Rest
# Script kiểm tra kết quả bài lab

PASS=0
FAIL=0
FAILED=0

echo "=========================================="
echo " Lab 4.2 – Kiểm tra kết quả"
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

# --- Tiêu chí 1: EncryptionConfiguration file tồn tại và chứa aescbc ---

echo "Kiểm tra tiêu chí 1: EncryptionConfiguration file tồn tại và chứa provider aescbc"

ENC_CONFIG_FOUND=0
ENC_CONFIG_PATH=""

# Kiểm tra đường dẫn chính thức trước
if [ -f /etc/kubernetes/enc/encryption-config.yaml ]; then
  ENC_CONFIG_FOUND=1
  ENC_CONFIG_PATH="/etc/kubernetes/enc/encryption-config.yaml"
elif [ -f /tmp/encryption-config.yaml ]; then
  ENC_CONFIG_FOUND=1
  ENC_CONFIG_PATH="/tmp/encryption-config.yaml"
  warn "EncryptionConfiguration tìm thấy tại /tmp/encryption-config.yaml (không phải đường dẫn production)"
  warn "Trong môi trường thực, file nên ở /etc/kubernetes/enc/encryption-config.yaml"
fi

if [ "$ENC_CONFIG_FOUND" -eq 1 ]; then
  if grep -q "aescbc" "$ENC_CONFIG_PATH" 2>/dev/null; then
    pass "EncryptionConfiguration tồn tại tại '${ENC_CONFIG_PATH}' và chứa provider aescbc"
  else
    fail "EncryptionConfiguration tồn tại tại '${ENC_CONFIG_PATH}' nhưng không chứa provider aescbc" \
         "Thêm provider aescbc vào file EncryptionConfiguration"
  fi
else
  fail "EncryptionConfiguration không tìm thấy tại /etc/kubernetes/enc/encryption-config.yaml hoặc /tmp/encryption-config.yaml" \
       "Tạo file EncryptionConfiguration: xem README.md Bước 1"
fi

echo ""

# --- Tiêu chí 2: kube-apiserver manifest có --encryption-provider-config flag ---

echo "Kiểm tra tiêu chí 2: kube-apiserver manifest có flag --encryption-provider-config"

APISERVER_MANIFEST="/etc/kubernetes/manifests/kube-apiserver.yaml"

if [ -f "$APISERVER_MANIFEST" ]; then
  if grep -q "encryption-provider-config" "$APISERVER_MANIFEST" 2>/dev/null; then
    ENC_FLAG=$(grep "encryption-provider-config" "$APISERVER_MANIFEST" | head -1 | tr -d ' ')
    pass "kube-apiserver manifest có flag --encryption-provider-config (${ENC_FLAG})"
  else
    fail "kube-apiserver manifest tồn tại nhưng không có flag --encryption-provider-config" \
         "Thêm '- --encryption-provider-config=/etc/kubernetes/enc/encryption-config.yaml' vào command trong /etc/kubernetes/manifests/kube-apiserver.yaml"
  fi
else
  warn "Không tìm thấy kube-apiserver manifest tại /etc/kubernetes/manifests/kube-apiserver.yaml"
  warn "Script này có thể đang chạy trên worker node hoặc môi trường không phải kubeadm"
  # Kiểm tra qua kube-apiserver process flags
  if pgrep -a kube-apiserver 2>/dev/null | grep -q "encryption-provider-config"; then
    pass "kube-apiserver process đang chạy với flag --encryption-provider-config"
  else
    fail "Không thể xác minh flag --encryption-provider-config trên kube-apiserver" \
         "Kiểm tra trên control-plane node: grep encryption-provider-config /etc/kubernetes/manifests/kube-apiserver.yaml"
  fi
fi

echo ""

# --- Tiêu chí 3: Secret sample-secret tồn tại trong namespace encryption-lab ---

echo "Kiểm tra tiêu chí 3: Secret 'sample-secret' tồn tại trong namespace 'encryption-lab'"

if kubectl get secret sample-secret -n encryption-lab &>/dev/null; then
  pass "Secret 'sample-secret' tồn tại trong namespace 'encryption-lab'"
else
  fail "Secret 'sample-secret' không tìm thấy trong namespace 'encryption-lab'" \
       "Chạy setup.sh để tạo lại Secret: bash setup.sh"
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
  echo "Lưu ý: Bài lab này yêu cầu quyền truy cập control-plane node."
  echo "Nếu đang chạy trên worker node, một số kiểm tra sẽ không thể thực hiện."
  exit 1
else
  echo ""
  echo "Chúc mừng! Bạn đã hoàn thành Lab 4.2."
  echo "Tiếp theo: Đọc phần 'Giải thích' trong README.md"
  echo "Dọn dẹp: bash cleanup.sh"
  exit 0
fi
