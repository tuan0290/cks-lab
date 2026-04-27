#!/bin/bash
# Mock Exam 3 – Setup Script
# Tạo môi trường với các tình huống bảo mật nâng cao

set -e

echo "=========================================="
echo " Mock Exam 3 – Khởi tạo môi trường"
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
for NS in m3-app m3-db m3-frontend m3-backend m3-secure m3-system m3-vuln m3-prod m3-runtime m3-audit; do
  kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: $NS
  labels:
    exam: "mock-3"
EOF
  echo "[OK] Namespace '$NS' đã được tạo."
done

# --- Q1: Pods trong m3-frontend và m3-backend ---
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: frontend
  namespace: m3-frontend
  labels:
    app: frontend
spec:
  containers:
  - name: app
    image: nginx:1.25-alpine
EOF

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: backend
  namespace: m3-backend
  labels:
    app: backend
spec:
  containers:
  - name: app
    image: nginx:1.25-alpine
EOF
echo "[OK] Q1: Pods frontend/backend đã được tạo."

# --- Q2: Pod trong m3-app ---
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: backend
  namespace: m3-app
  labels:
    app: backend
spec:
  containers:
  - name: app
    image: nginx:1.25-alpine
EOF
echo "[OK] Q2: Pod backend trong m3-app đã được tạo."

# --- Q2: kube-bench output giả lập ---
cat > /tmp/m3-kubebench-output.txt <<'EOF'
[INFO] 4 Worker Node Security Configuration
[INFO] 4.2 Kubelet
[FAIL] 4.2.1 Ensure that the --anonymous-auth argument is set to false (Automated)
       Remediation: Edit the kubelet config file /var/lib/kubelet/config.yaml
       and set: authentication.anonymous.enabled: false
[PASS] 4.2.2 Ensure that the --authorization-mode argument is not set to AlwaysAllow
[FAIL] 4.2.4 Ensure that the --read-only-port argument is set to 0 (Automated)
       Remediation: Edit the kubelet config file /var/lib/kubelet/config.yaml
       and set: readOnlyPort: 0
[PASS] 4.2.6 Ensure that the --protect-kernel-defaults argument is set to true
[PASS] 4.2.7 Ensure that the --make-iptables-util-chains argument is set to true

== Summary ==
0 checks PASS
2 checks FAIL
0 checks WARN
0 checks INFO
EOF
echo "[OK] Q2: /tmp/m3-kubebench-output.txt đã được tạo."

# --- Q3: Tạo thư mục audit ---
mkdir -p /etc/kubernetes/audit
echo "[OK] Q3: Thư mục /etc/kubernetes/audit đã được tạo."

# --- Q7: Deployment với image cũ ---
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: m3-vuln
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: web
        image: nginx:1.14.0
EOF
echo "[OK] Q7: Deployment web-app với nginx:1.14.0 đã được tạo."

# --- Q8: Tạo thư mục encryption ---
mkdir -p /etc/kubernetes/encryption
echo "[OK] Q8: Thư mục /etc/kubernetes/encryption đã được tạo."

# --- Q9: Tạo namespace m3-prod ---
kubectl label namespace m3-prod \
  pod-security.kubernetes.io/enforce=privileged \
  pod-security.kubernetes.io/enforce-version=latest \
  --overwrite 2>/dev/null || true
echo "[OK] Q9: Namespace m3-prod với PSS privileged (cần sửa thành restricted)."

# --- Q10: Setup ImagePolicyWebhook files ---
POLICY_DIR="/etc/kubernetes/policywebhook"
mkdir -p "$POLICY_DIR"

# Tạo cert nếu chưa có
if [ ! -f "$POLICY_DIR/external-cert.pem" ]; then
  openssl req -x509 -newkey rsa:2048 -keyout "$POLICY_DIR/external-key.pem" \
    -out "$POLICY_DIR/external-cert.pem" -days 365 -nodes \
    -subj "/CN=localhost" \
    -addext "subjectAltName=IP:127.0.0.1" 2>/dev/null
fi

# Tạo kubeconf
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

# Tạo admission_config.json chưa hoàn chỉnh (người dùng phải sửa)
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
echo "[OK] Q10: Files ImagePolicyWebhook đã được tạo tại $POLICY_DIR"
echo "     (admission_config.json cần sửa: allowTTL=100, defaultAllow=false)"

# --- Q12: Insecure deployment manifest ---
cat > /tmp/m3-deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: insecure-app
  namespace: m3-prod
spec:
  replicas: 1
  selector:
    matchLabels:
      app: insecure-app
  template:
    metadata:
      labels:
        app: insecure-app
    spec:
      containers:
      - name: app
        image: nginx:1.25-alpine
        securityContext:
          privileged: true
          allowPrivilegeEscalation: true
          runAsUser: 0
EOF
echo "[OK] Q12: /tmp/m3-deployment.yaml (insecure) đã được tạo."

# --- Q13: Tạo thư mục Falco rules ---
mkdir -p /etc/falco/rules.d
echo "[OK] Q13: Thư mục /etc/falco/rules.d đã được tạo."

# --- Q14: Audit log với sự cố bảo mật ---
cat > /tmp/m3-audit.log <<'EOF'
{"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"RequestResponse","auditID":"a1","stage":"ResponseComplete","requestURI":"/apis/rbac.authorization.k8s.io/v1/clusterrolebindings","verb":"create","user":{"username":"mallory","groups":["system:authenticated"]},"objectRef":{"resource":"clusterrolebindings","name":"evil-binding"},"responseStatus":{"code":201},"requestReceivedTimestamp":"2024-10-15T02:00:00Z"}
{"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"RequestResponse","auditID":"b2","stage":"ResponseComplete","requestURI":"/api/v1/namespaces/m3-prod/secrets","verb":"list","user":{"username":"system:serviceaccount:m3-prod:compromised-sa"},"objectRef":{"resource":"secrets","namespace":"m3-prod"},"responseStatus":{"code":200},"requestReceivedTimestamp":"2024-10-15T02:05:00Z"}
{"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"Metadata","auditID":"c3","stage":"ResponseComplete","requestURI":"/api/v1/namespaces/default/pods","verb":"list","user":{"username":"system:anonymous","groups":["system:unauthenticated"]},"objectRef":{"resource":"pods","namespace":"default"},"responseStatus":{"code":403},"requestReceivedTimestamp":"2024-10-15T02:10:00Z"}
{"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"Metadata","auditID":"d4","stage":"ResponseComplete","requestURI":"/api/v1/namespaces/default/secrets","verb":"list","user":{"username":"system:anonymous","groups":["system:unauthenticated"]},"objectRef":{"resource":"secrets","namespace":"default"},"responseStatus":{"code":403},"requestReceivedTimestamp":"2024-10-15T02:11:00Z"}
{"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"Metadata","auditID":"e5","stage":"ResponseComplete","requestURI":"/apis/apps/v1/namespaces/default/deployments","verb":"list","user":{"username":"system:anonymous","groups":["system:unauthenticated"]},"objectRef":{"resource":"deployments","namespace":"default"},"responseStatus":{"code":403},"requestReceivedTimestamp":"2024-10-15T02:12:00Z"}
{"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"RequestResponse","auditID":"f6","stage":"ResponseComplete","requestURI":"/api/v1/namespaces/m3-prod/pods/web-pod","verb":"delete","user":{"username":"mallory","groups":["system:authenticated"]},"objectRef":{"resource":"pods","namespace":"m3-prod","name":"web-pod"},"responseStatus":{"code":200},"requestReceivedTimestamp":"2024-10-15T02:15:00Z"}
EOF
echo "[OK] Q14: /tmp/m3-audit.log đã được tạo."

# --- Q15: Pod với nhiều vấn đề bảo mật ---
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: suspicious-pod
  namespace: m3-runtime
spec:
  hostPID: true
  hostNetwork: true
  containers:
  - name: app
    image: nginx:1.25-alpine
    securityContext:
      privileged: true
      allowPrivilegeEscalation: true
      runAsUser: 0
    volumeMounts:
    - name: host-root
      mountPath: /host
  volumes:
  - name: host-root
    hostPath:
      path: /
EOF
echo "[OK] Q15: Pod suspicious-pod (nhiều vấn đề bảo mật) đã được tạo."

echo ""
echo "=========================================="
echo " Môi trường Mock Exam 3 đã sẵn sàng!"
echo "=========================================="
echo ""
echo "Bắt đầu bấm giờ 120 phút và làm bài thi."
echo "Đọc README.md để xem các câu hỏi."
echo ""
echo "Lưu ý:"
echo "  - Q2, Q3, Q8, Q10 yêu cầu quyền truy cập control plane"
echo "  - Q10 cần sửa file tại /etc/kubernetes/policywebhook/"
echo "  - Q13 cần quyền ghi vào /etc/falco/rules.d/"
echo ""
