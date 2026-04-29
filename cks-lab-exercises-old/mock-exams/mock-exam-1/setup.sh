#!/bin/bash
# Mock Exam 1 – Setup Script
# Tạo môi trường cluster với các vấn đề bảo mật cần giải quyết

set -e

echo "=========================================="
echo " Mock Exam 1 – Khởi tạo môi trường"
echo "=========================================="
echo ""

if ! command -v kubectl &>/dev/null; then
  echo "[ERROR] kubectl không tìm thấy."
  exit 1
fi

if ! kubectl cluster-info &>/dev/null; then
  echo "[ERROR] Không thể kết nối đến cluster."
  exit 1
fi

echo "[OK] kubectl và cluster kết nối thành công."
echo ""

# --- Tạo namespaces ---
for NS in exam-frontend exam-backend exam-restricted exam-rbac exam-system exam-micro exam-policy exam-runtime exam-audit; do
  kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: $NS
  labels:
    exam: "mock-1"
EOF
  echo "[OK] Namespace '$NS' đã được tạo."
done

# --- Q3: Over-privileged ServiceAccount ---
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: exam-sa
  namespace: exam-rbac
EOF

kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: exam-sa-admin
subjects:
- kind: ServiceAccount
  name: exam-sa
  namespace: exam-rbac
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
EOF
echo "[OK] Q3: ClusterRoleBinding exam-sa-admin (cluster-admin) đã được tạo."

# --- Q4: ServiceAccount with automount ---
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: no-token-sa
  namespace: exam-rbac
EOF

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: no-token-pod
  namespace: exam-rbac
spec:
  serviceAccountName: no-token-sa
  containers:
  - name: app
    image: nginx:1.25-alpine
EOF
echo "[OK] Q4: Pod no-token-pod với automount token đã được tạo."

# --- Q7: Vulnerable pod ---
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: vulnerable-app
  namespace: exam-micro
spec:
  containers:
  - name: app
    image: nginx:1.14.0
EOF
echo "[OK] Q7: Pod vulnerable-app với nginx:1.14.0 đã được tạo."

# --- Q8: Secret for mounting ---
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: exam-credentials
  namespace: exam-micro
type: Opaque
data:
  username: YWRtaW4=
  password: c3VwZXJzZWNyZXQ=
EOF
echo "[OK] Q8: Secret exam-credentials đã được tạo."

# --- Q11: Insecure manifest ---
cat > /tmp/exam-insecure.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: insecure-pod
  namespace: exam-policy
spec:
  hostPID: true
  containers:
  - name: app
    image: nginx:1.25-alpine
    securityContext:
      privileged: true
EOF
echo "[OK] Q11: /tmp/exam-insecure.yaml đã được tạo."

# --- Q14: Sample audit log ---
cat > /tmp/exam-audit.log <<'EOF'
{"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"RequestResponse","auditID":"a1b2c3","stage":"ResponseComplete","requestURI":"/api/v1/namespaces/exam-audit/secrets/exam-secret","verb":"delete","user":{"username":"alice","groups":["system:authenticated"]},"objectRef":{"resource":"secrets","namespace":"exam-audit","name":"exam-secret"},"responseStatus":{"code":200},"requestReceivedTimestamp":"2024-10-15T10:00:00Z"}
{"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"Metadata","auditID":"d4e5f6","stage":"ResponseComplete","requestURI":"/api/v1/namespaces/exam-audit/pods","verb":"list","user":{"username":"bob","groups":["system:authenticated"]},"objectRef":{"resource":"pods","namespace":"exam-audit"},"responseStatus":{"code":403},"requestReceivedTimestamp":"2024-10-15T10:01:00Z"}
{"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"Metadata","auditID":"g7h8i9","stage":"ResponseComplete","requestURI":"/api/v1/namespaces/exam-audit/pods","verb":"list","user":{"username":"charlie","groups":["system:authenticated"]},"objectRef":{"resource":"pods","namespace":"exam-audit"},"responseStatus":{"code":403},"requestReceivedTimestamp":"2024-10-15T10:02:00Z"}
{"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"RequestResponse","auditID":"j1k2l3","stage":"ResponseComplete","requestURI":"/api/v1/namespaces/exam-audit/pods/web-pod/exec","verb":"create","user":{"username":"alice","groups":["system:authenticated"]},"objectRef":{"resource":"pods","namespace":"exam-audit","name":"web-pod","subresource":"exec"},"responseStatus":{"code":101},"requestReceivedTimestamp":"2024-10-15T10:03:00Z"}
{"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"Metadata","auditID":"m4n5o6","stage":"ResponseComplete","requestURI":"/api/v1/namespaces/exam-audit/configmaps","verb":"get","user":{"username":"system:kube-proxy","groups":["system:authenticated"]},"objectRef":{"resource":"configmaps","namespace":"exam-audit"},"responseStatus":{"code":200},"requestReceivedTimestamp":"2024-10-15T10:04:00Z"}
EOF
echo "[OK] Q14: /tmp/exam-audit.log đã được tạo."

echo ""
echo "=========================================="
echo " Môi trường Mock Exam 1 đã sẵn sàng!"
echo "=========================================="
echo ""
echo "Bắt đầu bấm giờ 120 phút và làm bài thi."
echo "Đọc README.md để xem các câu hỏi."
echo ""
