#!/bin/bash
# Lab 5.3 – ImagePolicyWebhook Setup
# Script khởi tạo môi trường lab

set -e

echo "=========================================="
echo " Lab 5.3 – ImagePolicyWebhook Setup"
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

# --- Kiểm tra quyền truy cập control plane ---

APISERVER_MANIFEST="/etc/kubernetes/manifests/kube-apiserver.yaml"
POLICY_DIR="/etc/kubernetes/policywebhook"

if [ ! -f "$APISERVER_MANIFEST" ]; then
  echo "[ERROR] Không tìm thấy $APISERVER_MANIFEST"
  echo "        Lab này yêu cầu chạy trực tiếp trên control plane node."
  exit 1
fi

echo "[OK] Tìm thấy kube-apiserver manifest."

# --- Tạo thư mục policy ---

echo ""
echo "Tạo thư mục $POLICY_DIR..."
mkdir -p "$POLICY_DIR"
echo "[OK] Thư mục $POLICY_DIR đã được tạo."

# --- Tạo self-signed cert cho external service (giả lập) ---

echo ""
echo "Tạo self-signed certificate cho external webhook service..."

if [ ! -f "$POLICY_DIR/external-cert.pem" ]; then
  openssl req -x509 -newkey rsa:2048 -keyout "$POLICY_DIR/external-key.pem" \
    -out "$POLICY_DIR/external-cert.pem" -days 365 -nodes \
    -subj "/CN=localhost" \
    -addext "subjectAltName=IP:127.0.0.1" 2>/dev/null
  echo "[OK] Certificate đã được tạo tại $POLICY_DIR/external-cert.pem"
else
  echo "[SKIP] Certificate đã tồn tại."
fi

# --- Tạo kubeconf (chưa điền server URL — người dùng phải tự điền) ---

echo ""
echo "Tạo file kubeconf mẫu tại $POLICY_DIR/kubeconf..."

cat > "$POLICY_DIR/kubeconf" <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority: /etc/kubernetes/policywebhook/external-cert.pem
    server: https://localhost:1234
  name: image-checker
users:
- name: api-server
  user: {}
contexts:
- context:
    cluster: image-checker
    user: api-server
  name: image-checker
current-context: image-checker
EOF

echo "[OK] File kubeconf đã được tạo tại $POLICY_DIR/kubeconf"

# --- Tạo admission_config.json (thiếu một số field — người dùng phải hoàn thiện) ---

echo ""
echo "Tạo file admission_config.json (chưa hoàn chỉnh) tại $POLICY_DIR/admission_config.json..."

cat > "$POLICY_DIR/admission_config.json" <<EOF
{
  "apiVersion": "apiserver.config.k8s.io/v1",
  "kind": "AdmissionConfiguration",
  "plugins": [
    {
      "name": "ImagePolicyWebhook",
      "configuration": {
        "imagePolicy": {
          "kubeConfigFile": "/etc/kubernetes/policywebhook/kubeconf",
          "allowTTL": 50,
          "denyTTL": 50,
          "retryBackoff": 500,
          "defaultAllow": true
        }
      }
    }
  ]
}
EOF

echo "[OK] File admission_config.json đã được tạo tại $POLICY_DIR/admission_config.json"
echo "     (Lưu ý: defaultAllow=true và allowTTL=50 — bạn cần sửa lại)"

echo ""
echo "=========================================="
echo " Môi trường đã sẵn sàng!"
echo "=========================================="
echo ""
echo "Files đã tạo:"
echo "  $POLICY_DIR/admission_config.json  (cần hoàn thiện)"
echo "  $POLICY_DIR/kubeconf               (cần kiểm tra server URL)"
echo "  $POLICY_DIR/external-cert.pem      (self-signed cert)"
echo ""
echo "NHIỆM VỤ:"
echo "  1. Sửa admission_config.json:"
echo "       - Đặt allowTTL = 100"
echo "       - Đặt defaultAllow = false"
echo ""
echo "  2. Kiểm tra kubeconf trỏ đúng server https://localhost:1234"
echo ""
echo "  3. Thêm admission plugin vào kube-apiserver:"
echo "       --enable-admission-plugins=NodeRestriction,ImagePolicyWebhook"
echo "       --admission-control-config-file=/etc/kubernetes/policywebhook/admission_config.json"
echo ""
echo "  4. Chờ apiserver restart và kiểm tra:"
echo "       watch crictl ps"
echo ""
echo "  5. Chạy verify.sh để kiểm tra kết quả:"
echo "       bash verify.sh"
echo ""
echo "Tham khảo: README.md"
echo ""
