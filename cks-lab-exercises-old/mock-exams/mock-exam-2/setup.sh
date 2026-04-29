#!/bin/bash
# Mock Exam 2 – Setup Script
# Tạo môi trường với các cấu hình bảo mật sai cần tìm và sửa

set -e

echo "=========================================="
echo " Mock Exam 2 – Khởi tạo môi trường"
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
for NS in fix-backend fix-pss fix-rbac fix-system fix-micro fix-policy fix-runtime fix-audit; do
  kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: $NS
  labels:
    exam: "mock-2"
EOF
  echo "[OK] Namespace '$NS' đã được tạo."
done

# --- Q1: Broken NetworkPolicy (allows all instead of deny) ---
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: broken-policy
  namespace: fix-backend
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - {}
EOF
echo "[OK] Q1: NetworkPolicy broken-policy (allows all) đã được tạo."

# --- Q2: PSS with wrong level ---
kubectl label namespace fix-pss \
  pod-security.kubernetes.io/enforce=baseline \
  pod-security.kubernetes.io/enforce-version=latest \
  --overwrite
echo "[OK] Q2: Namespace fix-pss với PSS baseline đã được tạo."

# --- Q3: Role with wildcard verb ---
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: broken-role
  namespace: fix-rbac
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["*"]
EOF
echo "[OK] Q3: Role broken-role với wildcard verb đã được tạo."

# --- Q4: Broken audit policy ---
cat > /tmp/fix-audit-policy.yaml <<'EOF'
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: Metadata
  resources:
  - group: ""
    resources: ["secrets"]
- level: Metadata
  omitStages:
  - RequestReceived
EOF
echo "[OK] Q4: /tmp/fix-audit-policy.yaml (sai level cho secrets) đã được tạo."

# --- Q5: Pod with wrong AppArmor annotation ---
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: broken-apparmor
  namespace: fix-system
  annotations:
    container.apparmor.security.beta.kubernetes.io/wrong-container: runtime/default
spec:
  containers:
  - name: app
    image: nginx:1.25-alpine
EOF
echo "[OK] Q5: Pod broken-apparmor với annotation sai tên container đã được tạo."

# --- Q6: Insecure pod ---
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: insecure-pod
  namespace: fix-system
spec:
  containers:
  - name: app
    image: nginx:1.25-alpine
    securityContext:
      privileged: true
      allowPrivilegeEscalation: true
EOF
echo "[OK] Q6: Pod insecure-pod với privileged:true đã được tạo."

# --- Q7: Deployment with old image ---
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-deploy
  namespace: fix-micro
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: web
        image: nginx:1.14.0
EOF
echo "[OK] Q7: Deployment web-deploy với nginx:1.14.0 đã được tạo."

# --- Q8: Pod with secret as env var ---
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
  namespace: fix-micro
type: Opaque
data:
  password: c2VjcmV0cGFzcw==
EOF

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: bad-secret-pod
  namespace: fix-micro
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    env:
    - name: APP_PASSWORD
      valueFrom:
        secretKeyRef:
          name: app-secret
          key: password
EOF
echo "[OK] Q8: Pod bad-secret-pod với secret env var đã được tạo."

# --- Q9: Broken EncryptionConfiguration (identity first) ---
cat > /tmp/fix-encryption.yaml <<'EOF'
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
- resources:
  - secrets
  providers:
  - identity: {}
  - aescbc:
      keys:
      - name: key1
        secret: c2VjcmV0a2V5MTIzNDU2Nzg5MDEyMzQ1Ng==
EOF
echo "[OK] Q9: /tmp/fix-encryption.yaml (identity trước aescbc) đã được tạo."

# --- Q11: Insecure Dockerfile ---
cat > /tmp/fix-dockerfile <<'EOF'
FROM node:latest
WORKDIR /app
COPY . .
RUN npm install
EXPOSE 3000
CMD ["node", "server.js"]
EOF
echo "[OK] Q11: /tmp/fix-dockerfile (dùng latest, chạy root) đã được tạo."

# --- Q13: Falco rule with missing output ---
cat > /tmp/fix-falco-rule.yaml <<'EOF'
- rule: Detect shell in container
  desc: A shell was spawned in a container
  condition: spawned_process and container and shell_procs
  priority: WARNING
  tags: [container, shell]
EOF
echo "[OK] Q13: /tmp/fix-falco-rule.yaml (thiếu output field) đã được tạo."

# --- Q14: Audit log for forensics ---
cat > /tmp/fix-audit.log <<'EOF'
{"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"RequestResponse","auditID":"a1","stage":"ResponseComplete","requestURI":"/api/v1/namespaces/fix-audit/secrets/fix-secret","verb":"get","user":{"username":"system:serviceaccount:fix-audit:monitor-sa"},"objectRef":{"resource":"secrets","namespace":"fix-audit","name":"fix-secret"},"responseStatus":{"code":200},"requestReceivedTimestamp":"2024-10-15T08:30:00Z"}
{"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"RequestResponse","auditID":"b2","stage":"ResponseComplete","requestURI":"/api/v1/namespaces/fix-audit/pods","verb":"create","user":{"username":"system:serviceaccount:fix-audit:deploy-sa"},"objectRef":{"resource":"pods","namespace":"fix-audit","name":"new-pod"},"responseStatus":{"code":201},"requestReceivedTimestamp":"2024-10-15T09:00:00Z"}
{"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"RequestResponse","auditID":"c3","stage":"ResponseComplete","requestURI":"/api/v1/namespaces/fix-audit/pods/web-pod/exec","verb":"create","user":{"username":"alice"},"objectRef":{"resource":"pods","namespace":"fix-audit","name":"web-pod","subresource":"exec"},"responseStatus":{"code":101},"requestReceivedTimestamp":"2024-10-15T09:15:00Z"}
{"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"RequestResponse","auditID":"d4","stage":"ResponseComplete","requestURI":"/api/v1/namespaces/fix-audit/pods/db-pod/exec","verb":"create","user":{"username":"bob"},"objectRef":{"resource":"pods","namespace":"fix-audit","name":"db-pod","subresource":"exec"},"responseStatus":{"code":101},"requestReceivedTimestamp":"2024-10-15T09:20:00Z"}
{"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"RequestResponse","auditID":"e5","stage":"ResponseComplete","requestURI":"/api/v1/namespaces/fix-audit/secrets/fix-secret","verb":"get","user":{"username":"charlie"},"objectRef":{"resource":"secrets","namespace":"fix-audit","name":"fix-secret"},"responseStatus":{"code":200},"requestReceivedTimestamp":"2024-10-15T10:00:00Z"}
EOF
echo "[OK] Q14: /tmp/fix-audit.log đã được tạo."

# --- Q15: Mutable pod ---
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: mutable-pod
  namespace: fix-runtime
spec:
  containers:
  - name: app
    image: nginx:1.25-alpine
EOF
echo "[OK] Q15: Pod mutable-pod (không có readOnlyRootFilesystem) đã được tạo."

echo ""
echo "=========================================="
echo " Môi trường Mock Exam 2 đã sẵn sàng!"
echo "=========================================="
echo ""
echo "Bắt đầu bấm giờ 120 phút và làm bài thi."
echo "Đọc README.md để xem các câu hỏi."
echo ""
