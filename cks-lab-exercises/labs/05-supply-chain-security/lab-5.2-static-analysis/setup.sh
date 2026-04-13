#!/bin/bash
# Lab 5.2 – Static Analysis
# Script khởi tạo môi trường lab

set -e

echo "=========================================="
echo " Lab 5.2 – Static Analysis"
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

# Kiểm tra kubesec hoặc trivy
TOOL_FOUND=0
if command -v kubesec &>/dev/null; then
  echo "[OK] kubesec đã được cài đặt."
  TOOL_FOUND=1
fi
if command -v trivy &>/dev/null; then
  echo "[OK] trivy đã được cài đặt."
  TOOL_FOUND=1
fi

if [ "$TOOL_FOUND" -eq 0 ]; then
  echo "[WARN] Không tìm thấy kubesec hoặc trivy."
  echo "       Cài đặt kubesec: https://kubesec.io/"
  echo "       Cài đặt trivy:   https://aquasecurity.github.io/trivy/"
  echo "       Hoặc dùng kubesec API: curl -sSX POST --data-binary @manifest.yaml https://v2.kubesec.io/scan"
  echo ""
  echo "[INFO] Tiếp tục tạo môi trường lab..."
fi

# --- Tạo namespace static-lab ---

echo ""
echo "Tạo namespace static-lab..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: static-lab
  labels:
    lab: "5.2"
    purpose: static-analysis
EOF

echo "[OK] Namespace 'static-lab' đã được tạo."

# --- Tạo insecure manifest tại /tmp/insecure-manifest.yaml ---

echo ""
echo "Tạo insecure manifest tại /tmp/insecure-manifest.yaml..."

cat > /tmp/insecure-manifest.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: insecure-pod
  namespace: static-lab
  labels:
    app: insecure-app
spec:
  hostPID: true
  containers:
  - name: app
    image: nginx:1.25-alpine
    securityContext:
      privileged: true
    ports:
    - containerPort: 80
EOF

echo "[OK] File /tmp/insecure-manifest.yaml đã được tạo."

echo ""
echo "=========================================="
echo " Môi trường đã sẵn sàng!"
echo "=========================================="
echo ""
echo "Tài nguyên đã tạo:"
echo "  Namespace: static-lab"
echo "  File:      /tmp/insecure-manifest.yaml (manifest có vấn đề bảo mật)"
echo ""
echo "NHIỆM VỤ:"
echo "  1. Xem manifest có vấn đề:"
echo "       cat /tmp/insecure-manifest.yaml"
echo ""
echo "  2. Phân tích bằng kubesec:"
echo "       kubesec scan /tmp/insecure-manifest.yaml"
echo "     Hoặc trivy config:"
echo "       trivy config /tmp/insecure-manifest.yaml"
echo ""
echo "  3. Tạo manifest đã sửa tại /tmp/fixed-manifest.yaml"
echo "     (xóa privileged:true và hostPID:true)"
echo ""
echo "  4. Chạy verify.sh để kiểm tra kết quả:"
echo "       bash verify.sh"
echo ""
echo "Dọn dẹp sau khi hoàn thành:"
echo "  bash cleanup.sh"
echo ""
