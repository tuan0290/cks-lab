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
  echo "[ERROR] kubectl không tìm thấy."
  exit 1
fi

if ! kubectl cluster-info &>/dev/null; then
  echo "[ERROR] Không thể kết nối đến Kubernetes cluster."
  exit 1
fi

echo "[OK] kubectl và cluster kết nối thành công."

if ! command -v openssl &>/dev/null; then
  echo "[WARN] openssl không tìm thấy. Cài đặt: apt-get install openssl"
fi

# --- Kiểm tra Ingress Controller ---

echo ""
echo "Kiểm tra Ingress Controller..."

INGRESS_RUNNING=$(kubectl get pods --all-namespaces -l app.kubernetes.io/component=controller \
  --no-headers 2>/dev/null | grep -c "Running" || true)

if [ "$INGRESS_RUNNING" -gt 0 ]; then
  echo "[OK] Ingress Controller đã có sẵn ($INGRESS_RUNNING pod đang Running)."
  kubectl get pods --all-namespaces -l app.kubernetes.io/component=controller --no-headers 2>/dev/null
else
  echo "[INFO] Chưa có Ingress Controller. Bạn cần cài đặt ở Bước 2 trong README.md."
  echo ""
  echo "  Cài đặt nhanh bằng Helm:"
  echo "    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx"
  echo "    helm repo update"
  echo "    helm install ingress-nginx ingress-nginx/ingress-nginx \\"
  echo "      --namespace ingress-nginx --create-namespace \\"
  echo "      --set controller.service.type=NodePort \\"
  echo "      --set controller.service.nodePorts.http=30080 \\"
  echo "      --set controller.service.nodePorts.https=30443"
  echo ""
  echo "  Hoặc không dùng Helm:"
  echo "    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/baremetal/deploy.yaml"
fi

# --- Kiểm tra IngressClass ---

echo ""
echo "Kiểm tra IngressClass..."
INGRESSCLASS=$(kubectl get ingressclass --no-headers 2>/dev/null | head -3)
if [ -n "$INGRESSCLASS" ]; then
  echo "[OK] IngressClass có sẵn:"
  echo "$INGRESSCLASS"
else
  echo "[INFO] Chưa có IngressClass — sẽ được tạo khi cài Ingress Controller."
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
echo "  Deployment: nginx-deployment (tls-lab)"
echo "  Service:    nginx-service (tls-lab, port: 80)"
echo ""
echo "BƯỚC TIẾP THEO (theo thứ tự):"
echo ""
echo "  Bước 1: Kiểm tra Ingress Controller"
echo "    kubectl get pods -n ingress-nginx"
echo "    kubectl get ingressclass"
echo ""
echo "  Bước 2: Cài Ingress Controller nếu chưa có (xem README.md)"
echo ""
echo "  Bước 3: Tạo TLS certificate"
echo "    mkdir -p /tmp/tls-lab"
echo "    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \\"
echo "      -keyout /tmp/tls-lab/tls.key -out /tmp/tls-lab/tls.crt \\"
echo "      -subj \"/CN=app.tls-lab.local/O=tls-lab\""
echo ""
echo "  Bước 4: Tạo TLS Secret"
echo "    kubectl create secret tls tls-secret \\"
echo "      --cert=/tmp/tls-lab/tls.crt --key=/tmp/tls-lab/tls.key -n tls-lab"
echo ""
echo "  Bước 5: Tạo Ingress với ingressClassName: nginx và TLS"
echo ""
echo "  Bước 6: Test HTTPS với curl"
echo ""
echo "  Bước 7: bash verify.sh"
echo ""
echo "Dọn dẹp: bash cleanup.sh"
echo ""
