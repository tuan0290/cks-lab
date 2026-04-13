#!/bin/bash
# Lab 4.5 – Pod-to-Pod Encryption với Cilium
# Script khởi tạo môi trường lab

set -e

echo "=========================================="
echo " Lab 4.5 – Pod-to-Pod Encryption với Cilium"
echo " Đang khởi tạo môi trường..."
echo "=========================================="
echo ""

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

# --- Kiểm tra Cilium ---

echo ""
echo "Kiểm tra Cilium CNI..."

CILIUM_PODS=$(kubectl get pods -n kube-system -l k8s-app=cilium --no-headers 2>/dev/null | wc -l)

if [ "$CILIUM_PODS" -gt 0 ]; then
  echo "[OK] Cilium đang chạy ($CILIUM_PODS pod(s) trong kube-system)."
  kubectl get pods -n kube-system -l k8s-app=cilium
else
  echo "[WARN] Không tìm thấy Cilium pods trong kube-system."
  echo ""
  echo "  Cài đặt Cilium với Helm:"
  echo "  helm repo add cilium https://helm.cilium.io/"
  echo "  helm install cilium cilium/cilium --version 1.15.0 \\"
  echo "    --namespace kube-system \\"
  echo "    --set encryption.enabled=true \\"
  echo "    --set encryption.type=wireguard"
  echo ""
  echo "  Hoặc với cilium CLI:"
  echo "  cilium install --version 1.15.0 \\"
  echo "    --set encryption.enabled=true \\"
  echo "    --set encryption.type=wireguard"
  echo ""
fi

# --- Kiểm tra cilium CLI ---

if command -v cilium &>/dev/null; then
  echo "[OK] cilium CLI đã được cài đặt."
else
  echo "[INFO] cilium CLI chưa được cài đặt (tùy chọn)."
  echo "       Cài đặt: https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/"
fi

# --- Tạo namespace cilium-lab ---

echo ""
echo "Tạo namespace cilium-lab..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: cilium-lab
  labels:
    lab: "4.5"
    purpose: cilium-encryption-lab
EOF

echo "[OK] Namespace 'cilium-lab' đã được tạo."

# --- Deploy server pod ---

echo ""
echo "Triển khai server pod (nginx) trong cilium-lab..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: server
  namespace: cilium-lab
  labels:
    app: server
    lab: "4.5"
spec:
  containers:
  - name: nginx
    image: nginx:1.25-alpine
    ports:
    - containerPort: 80
EOF

echo "[OK] server pod đã được tạo."

# --- Deploy client pod ---

echo ""
echo "Triển khai client pod (curl) trong cilium-lab..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: client
  namespace: cilium-lab
  labels:
    app: client
    lab: "4.5"
spec:
  containers:
  - name: curl
    image: curlimages/curl:8.5.0
    command: ["sleep", "3600"]
EOF

echo "[OK] client pod đã được tạo."

# --- Chờ pods sẵn sàng ---

echo ""
echo "Chờ các pod khởi động (tối đa 60 giây)..."

kubectl wait --for=condition=Ready pod/server -n cilium-lab --timeout=60s 2>/dev/null \
  && echo "[OK] server pod sẵn sàng." \
  || echo "[WARN] server pod chưa sẵn sàng — tiếp tục."

kubectl wait --for=condition=Ready pod/client -n cilium-lab --timeout=60s 2>/dev/null \
  && echo "[OK] client pod sẵn sàng." \
  || echo "[WARN] client pod chưa sẵn sàng — tiếp tục."

# --- Tóm tắt ---

echo ""
echo "=========================================="
echo " Môi trường đã sẵn sàng!"
echo "=========================================="
echo ""
echo "Tài nguyên đã tạo:"
echo "  Namespace: cilium-lab"
echo "  Pod:       server (nginx, label: app=server)"
echo "             client (curl, label: app=client)"
echo ""
echo "Bước tiếp theo:"
echo "  1. Đọc README.md để hiểu yêu cầu bài lab"
echo "  2. Bật WireGuard encryption trên Cilium"
echo "  3. Tạo CiliumNetworkPolicy trong namespace cilium-lab"
echo "  4. Chạy verify.sh để kiểm tra kết quả:"
echo "     bash verify.sh"
echo ""
echo "Dọn dẹp sau khi hoàn thành:"
echo "  bash cleanup.sh"
echo ""
