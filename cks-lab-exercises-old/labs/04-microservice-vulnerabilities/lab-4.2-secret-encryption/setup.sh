#!/bin/bash
# Lab 4.2 – Secret Encryption at Rest
# Script khởi tạo môi trường lab

set -e

echo "=========================================="
echo " Lab 4.2 – Secret Encryption at Rest"
echo " Đang khởi tạo môi trường..."
echo "=========================================="

# --- Kiểm tra prerequisites ---

if ! command -v kubectl &>/dev/null; then
  echo "[ERROR] kubectl không tìm thấy. Vui lòng cài đặt kubectl trước."
  exit 1
fi

if ! kubectl cluster-info &>/dev/null; then
  echo "[ERROR] Không thể kết nối đến Kubernetes cluster."
  echo "        Kiểm tra kubeconfig: kubectl cluster-info"
  exit 1
fi

echo "[OK] kubectl và cluster kết nối thành công."

# --- Tạo namespace encryption-lab ---

echo ""
echo "Tạo namespace encryption-lab..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: encryption-lab
  labels:
    lab: "4.2"
    purpose: secret-encryption
EOF

echo "[OK] Namespace 'encryption-lab' đã được tạo."

# --- Tạo sample Secret (chưa mã hóa) ---

echo ""
echo "Tạo sample Secret 'sample-secret' trong namespace encryption-lab..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: sample-secret
  namespace: encryption-lab
  labels:
    lab: "4.2"
type: Opaque
stringData:
  username: admin
  password: P@ssw0rd123!
  api-key: sk-1234567890abcdef
EOF

echo "[OK] Secret 'sample-secret' đã được tạo."

# --- Tạo EncryptionConfiguration template tại /tmp/encryption-config.yaml ---

echo ""
echo "Tạo EncryptionConfiguration template tại /tmp/encryption-config.yaml..."

# Tạo key ngẫu nhiên 32 bytes
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

cat > /tmp/encryption-config.yaml <<EOF
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF

echo "[OK] EncryptionConfiguration template đã được tạo tại /tmp/encryption-config.yaml"
echo "     Key đã được tạo ngẫu nhiên: ${ENCRYPTION_KEY}"

echo ""
echo "=========================================="
echo " Môi trường đã sẵn sàng!"
echo "=========================================="
echo ""
echo "Tài nguyên đã tạo:"
echo "  Namespace:              encryption-lab"
echo "  Secret:                 sample-secret (chưa mã hóa)"
echo "  EncryptionConfig:       /tmp/encryption-config.yaml"
echo ""
echo "NHIỆM VỤ:"
echo "  1. Copy EncryptionConfiguration lên control-plane node:"
echo "       sudo mkdir -p /etc/kubernetes/enc"
echo "       sudo cp /tmp/encryption-config.yaml /etc/kubernetes/enc/encryption-config.yaml"
echo "       sudo chmod 600 /etc/kubernetes/enc/encryption-config.yaml"
echo ""
echo "  2. Thêm flag vào kube-apiserver manifest:"
echo "       sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml"
echo "       # Thêm: - --encryption-provider-config=/etc/kubernetes/enc/encryption-config.yaml"
echo ""
echo "  3. Thêm volume mount cho /etc/kubernetes/enc vào kube-apiserver"
echo ""
echo "  4. Chờ kube-apiserver khởi động lại và xác minh mã hóa"
echo ""
echo "  5. Chạy verify.sh để kiểm tra kết quả:"
echo "       bash verify.sh"
echo ""
echo "Xem README.md để biết hướng dẫn chi tiết."
echo ""
echo "Dọn dẹp sau khi hoàn thành:"
echo "  bash cleanup.sh"
echo ""
