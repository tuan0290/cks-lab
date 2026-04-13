#!/bin/bash
# Lab 1.3 – Ingress TLS
# Script khởi tạo môi trường lab

set -e

echo "=========================================="
echo " Lab 1.3 – Ingress TLS"
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

if ! command -v openssl &>/dev/null; then
  echo "[WARN] openssl không tìm thấy. Bạn sẽ cần openssl để tạo TLS certificate."
  echo "       Cài đặt: apt-get install openssl  hoặc  yum install openssl"
fi

# --- Tạo namespace tls-lab ---

echo ""
echo "Tạo namespace tls-lab..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: tls-lab
  labels:
    lab: "1.3"
    purpose: ingress-tls
EOF

echo "[OK] Namespace 'tls-lab' đã được tạo."

# --- Deploy nginx Deployment ---

echo ""
echo "Triển khai nginx Deployment trong namespace tls-lab..."

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  namespace: tls-lab
  labels:
    app: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
EOF

echo "[OK] Deployment 'nginx-deployment' đã được tạo."

# --- Tạo Service cho nginx ---

echo ""
echo "Tạo Service cho nginx..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
  namespace: tls-lab
  labels:
    app: nginx
spec:
  selector:
    app: nginx
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
  type: ClusterIP
EOF

echo "[OK] Service 'nginx-service' đã được tạo."

# --- Tóm tắt ---

echo ""
echo "=========================================="
echo " Môi trường đã sẵn sàng!"
echo "=========================================="
echo ""
echo "Tài nguyên đã tạo:"
echo "  Namespace:  tls-lab"
echo "  Deployment: nginx-deployment (namespace: tls-lab)"
echo "  Service:    nginx-service    (namespace: tls-lab, port: 80)"
echo ""
echo "Bước tiếp theo:"
echo "  1. Đọc README.md để hiểu yêu cầu bài lab"
echo ""
echo "  2. Tạo self-signed TLS certificate:"
echo "     openssl req -x509 -nodes -days 365 -newkey rsa:2048 \\"
echo "       -keyout /tmp/tls-lab/tls.key \\"
echo "       -out /tmp/tls-lab/tls.crt \\"
echo "       -subj \"/CN=app.tls-lab.local/O=tls-lab\""
echo ""
echo "  3. Tạo Kubernetes TLS Secret:"
echo "     kubectl create secret tls tls-secret \\"
echo "       --cert=/tmp/tls-lab/tls.crt \\"
echo "       --key=/tmp/tls-lab/tls.key \\"
echo "       -n tls-lab"
echo ""
echo "  4. Tạo Ingress với TLS configuration"
echo ""
echo "  5. Chạy verify.sh để kiểm tra kết quả:"
echo "     bash verify.sh"
echo ""
echo "Dọn dẹp sau khi hoàn thành:"
echo "  bash cleanup.sh"
echo ""
