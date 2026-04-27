# Đáp án Mock Exam 3

## Tổng điểm: 100 | Điểm đạt: 67

---

## Q1 – NetworkPolicy Egress Control (8 điểm)

```bash
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: restrict-egress
  namespace: m3-app
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  # Cho phép DNS
  - ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
  # Cho phép kết nối đến m3-db trên port 5432
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: m3-db
    ports:
    - protocol: TCP
      port: 5432
EOF
```

---

## Q2 – kube-bench CIS Remediation (7 điểm)

```bash
# Đọc output để xác định vấn đề
cat /tmp/m3-kubebench-output.txt
# FAIL 4.2.1: anonymous-auth cần false
# FAIL 4.2.4: readOnlyPort cần 0

# Sửa kubelet config
vi /var/lib/kubelet/config.yaml
# Thêm/sửa:
# readOnlyPort: 0
# authentication:
#   anonymous:
#     enabled: false

# Restart kubelet
systemctl restart kubelet

# Xác minh
systemctl status kubelet
```

---

## Q3 – Audit Policy Advanced (8 điểm)

```bash
mkdir -p /etc/kubernetes/audit

cat > /etc/kubernetes/audit/policy.yaml <<'EOF'
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
# Rule 1: Không log từ system:nodes
- level: None
  userGroups: ["system:nodes"]

# Rule 2: RequestResponse cho write operations trên secrets
- level: RequestResponse
  verbs: ["create", "update", "delete", "patch"]
  resources:
  - group: ""
    resources: ["secrets"]

# Rule 3: Request cho read operations trên secrets
- level: Request
  verbs: ["get", "list"]
  resources:
  - group: ""
    resources: ["secrets"]

# Rule 4: RequestResponse cho create/delete pods trong m3-prod
- level: RequestResponse
  verbs: ["create", "delete"]
  resources:
  - group: ""
    resources: ["pods"]
  namespaces: ["m3-prod"]

# Rule 5: Metadata cho tất cả còn lại
- level: Metadata
  omitStages:
  - RequestReceived
EOF

# Thêm vào kube-apiserver
vi /etc/kubernetes/manifests/kube-apiserver.yaml
# Thêm vào phần command:
# - --audit-log-path=/var/log/kubernetes/audit/audit.log
# - --audit-policy-file=/etc/kubernetes/audit/policy.yaml
# - --audit-log-maxage=7
# - --audit-log-maxbackup=3
# - --audit-log-maxsize=50

# Tạo thư mục log
mkdir -p /var/log/kubernetes/audit

# Chờ apiserver restart
watch crictl ps
```

---

## Q4 – ServiceAccount Hardening (7 điểm)

```bash
# Tạo ServiceAccount
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa
  namespace: m3-secure
automountServiceAccountToken: false
EOF

# Tạo Role
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: m3-secure
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list", "watch"]
EOF

# Tạo RoleBinding
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-sa-pod-reader
  namespace: m3-secure
subjects:
- kind: ServiceAccount
  name: app-sa
  namespace: m3-secure
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
EOF

# Tạo Pod
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: app-pod
  namespace: m3-secure
spec:
  serviceAccountName: app-sa
  automountServiceAccountToken: false
  containers:
  - name: app
    image: nginx:1.25-alpine
EOF
```

---

## Q5 – seccomp Custom Profile (5 điểm)

```bash
mkdir -p /var/lib/kubelet/seccomp

cat > /var/lib/kubelet/seccomp/m3-profile.json <<'EOF'
{
  "defaultAction": "SCMP_ACT_ERRNO",
  "architectures": ["SCMP_ARCH_X86_64"],
  "syscalls": [
    {
      "names": [
        "read", "write", "exit", "exit_group", "open", "close",
        "stat", "fstat", "mmap", "mprotect", "munmap", "brk",
        "rt_sigaction", "rt_sigreturn", "ioctl", "access", "execve",
        "getpid", "clone", "wait4", "nanosleep", "socket", "connect",
        "sendto", "recvfrom", "bind", "listen", "accept", "getsockname",
        "setsockopt", "getsockopt", "fcntl", "getdents64", "lseek",
        "pread64", "pwrite64"
      ],
      "action": "SCMP_ACT_ALLOW"
    }
  ]
}
EOF

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: seccomp-pod
  namespace: m3-system
spec:
  securityContext:
    seccompProfile:
      type: Localhost
      localhostProfile: m3-profile.json
  containers:
  - name: app
    image: nginx:1.25-alpine
EOF
```

---

## Q6 – AppArmor + Capabilities (5 điểm)

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: hardened-nginx
  namespace: m3-system
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 101
  containers:
  - name: nginx
    image: nginx:1.25-alpine
    securityContext:
      appArmorProfile:
        type: RuntimeDefault
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop: [ALL]
        add: [NET_BIND_SERVICE]
    volumeMounts:
    - name: cache
      mountPath: /var/cache/nginx
    - name: run
      mountPath: /var/run
    - name: tmp
      mountPath: /tmp
  volumes:
  - name: cache
    emptyDir: {}
  - name: run
    emptyDir: {}
  - name: tmp
    emptyDir: {}
EOF
```

---

## Q7 – Trivy + Fix Deployment (6 điểm)

```bash
# Quét và lưu JSON
trivy image --format json --output /tmp/m3-scan.json nginx:1.14.0

# Đếm CRITICAL
trivy image --severity CRITICAL --format json nginx:1.14.0 2>/dev/null | \
  python3 -c "
import json, sys
data = json.load(sys.stdin)
count = sum(len([v for v in r.get('Vulnerabilities', []) if v.get('Severity')=='CRITICAL'])
            for r in data.get('Results', []))
print(count)
" > /tmp/m3-critical-count.txt

cat /tmp/m3-critical-count.txt

# Cập nhật Deployment
kubectl set image deployment/web-app web=nginx:1.25-alpine -n m3-vuln

# Xác minh rollout
kubectl rollout status deployment/web-app -n m3-vuln
```

---

## Q8 – etcd Encryption (7 điểm)

```bash
# Tạo key 32 bytes
KEY=$(head -c 32 /dev/urandom | base64)

mkdir -p /etc/kubernetes/encryption

cat > /etc/kubernetes/encryption/config.yaml <<EOF
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
- resources:
  - secrets
  providers:
  - aescbc:
      keys:
      - name: key1
        secret: ${KEY}
  - identity: {}
EOF

# Thêm vào kube-apiserver
vi /etc/kubernetes/manifests/kube-apiserver.yaml
# Thêm: - --encryption-provider-config=/etc/kubernetes/encryption/config.yaml

# Chờ apiserver restart
watch crictl ps

# Tạo secret để test
kubectl create secret generic m3-encrypted-secret \
  --from-literal=key=value -n m3-secure

# Xác minh mã hóa trong etcd (nếu có etcdctl)
# ETCDCTL_API=3 etcdctl get /registry/secrets/m3-secure/m3-encrypted-secret \
#   --endpoints=https://127.0.0.1:2379 \
#   --cacert=/etc/kubernetes/pki/etcd/ca.crt \
#   --cert=/etc/kubernetes/pki/etcd/server.crt \
#   --key=/etc/kubernetes/pki/etcd/server.key | hexdump -C | head
# Output phải chứa "k8s:enc:aescbc" thay vì plaintext
```

---

## Q9 – Pod Security Admission Strict (7 điểm)

```bash
# Gắn nhãn namespace
kubectl label namespace m3-prod \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/warn=restricted \
  pod-security.kubernetes.io/enforce-version=latest \
  pod-security.kubernetes.io/audit-version=latest \
  pod-security.kubernetes.io/warn-version=latest \
  --overwrite

# Tạo pod compliant
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: compliant-pod
  namespace: m3-prod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: nginx:1.25-alpine
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop: [ALL]
    volumeMounts:
    - name: tmp
      mountPath: /tmp
  volumes:
  - name: tmp
    emptyDir: {}
EOF

# Test pod vi phạm (phải bị từ chối)
kubectl run violating-pod --image=nginx --privileged -n m3-prod
# Mong đợi: Error from server (Forbidden): ...
```

---

## Q10 – ImagePolicyWebhook (7 điểm)

```bash
# Sửa admission_config.json
cat > /etc/kubernetes/policywebhook/admission_config.json <<'EOF'
{
  "apiVersion": "apiserver.config.k8s.io/v1",
  "kind": "AdmissionConfiguration",
  "plugins": [
    {
      "name": "ImagePolicyWebhook",
      "configuration": {
        "imagePolicy": {
          "kubeConfigFile": "/etc/kubernetes/policywebhook/kubeconf",
          "allowTTL": 100,
          "denyTTL": 50,
          "retryBackoff": 500,
          "defaultAllow": false
        }
      }
    }
  ]
}
EOF

# Kiểm tra kubeconf
cat /etc/kubernetes/policywebhook/kubeconf
# Đảm bảo server: https://localhost:1234

# Thêm vào kube-apiserver
vi /etc/kubernetes/manifests/kube-apiserver.yaml
# Thêm:
# - --enable-admission-plugins=NodeRestriction,ImagePolicyWebhook
# - --admission-control-config-file=/etc/kubernetes/policywebhook/admission_config.json

# Chờ apiserver restart
watch crictl ps

# Test: phải bị từ chối
kubectl run test-pod --image=nginx --restart=Never
# Mong đợi: connection refused (external service chưa tồn tại + defaultAllow=false)
```

---

## Q11 – Cosign Sign + Verify (6 điểm)

```bash
mkdir -p /tmp/m3-cosign
cd /tmp/m3-cosign

# Tạo key pair
COSIGN_PASSWORD="" cosign generate-key-pair

# Ký image
COSIGN_PASSWORD="" cosign sign --key cosign.key docker.io/library/nginx:1.25-alpine

# Verify và lưu output
COSIGN_PASSWORD="" cosign verify \
  --key cosign.pub \
  docker.io/library/nginx:1.25-alpine 2>&1 | tee verify-output.txt

# Ghi policy explanation
cat > /tmp/m3-cosign/sign-policy.txt <<'EOF'
Image signing với Cosign đảm bảo:
1. Tính toàn vẹn: Image không bị thay đổi sau khi ký
2. Xác thực nguồn gốc: Chỉ image được ký bởi key tin cậy mới được deploy
3. Supply chain security: Ngăn chặn image bị giả mạo hoặc thay thế
4. Audit trail: Có thể truy vết ai đã ký image và khi nào
EOF
```

---

## Q12 – Trivy Config Scan (7 điểm)

```bash
# Quét và ghi issues
trivy config /tmp/m3-deployment.yaml 2>/dev/null | tee /tmp/m3-config-issues.txt

# Tạo manifest đã sửa
cat > /tmp/m3-deployment-fixed.yaml <<'EOF'
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
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: app
        image: nginx:1.25-alpine
        securityContext:
          privileged: false
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop: [ALL]
EOF

# Xác minh không còn HIGH/CRITICAL
trivy config /tmp/m3-deployment-fixed.yaml
```

---

## Q13 – Falco Custom Rules (7 điểm)

```bash
sudo tee /etc/falco/rules.d/m3-rules.yaml <<'EOF'
# Rule 1: Phát hiện package manager trong container
- rule: Detect Package Manager in Container
  desc: Detect package manager tools running inside a container
  condition: >
    spawned_process
    and container
    and proc.name in (apt, apt-get, yum, dnf, apk)
  output: >
    Package manager detected in container
    (user=%user.name pod=%k8s.pod.name ns=%k8s.ns.name
     tool=%proc.name cmdline=%proc.cmdline image=%container.image.repository)
  priority: WARNING
  tags: [container, package-manager]

# Rule 2: Phát hiện write vào /etc trong container
- rule: Detect Write to /etc in Container
  desc: Detect write operations to /etc directory inside a container
  condition: >
    open_write
    and container
    and fd.name startswith /etc/
    and not proc.name in (nginx, apache2, sshd)
  output: >
    Write to /etc detected in container
    (user=%user.name pod=%k8s.pod.name ns=%k8s.ns.name
     file=%fd.name proc=%proc.name cmdline=%proc.cmdline)
  priority: ERROR
  tags: [container, filesystem]

# Rule 3: Phát hiện kết nối ra ngoài trên port đáng ngờ (reverse shell)
- rule: Detect Outbound Connection to Suspicious Port
  desc: Detect outbound connections to ports commonly used by reverse shells
  condition: >
    outbound
    and container
    and fd.sport in (4444, 1234, 9001)
  output: >
    Suspicious outbound connection detected
    (user=%user.name pod=%k8s.pod.name ns=%k8s.ns.name
     dest=%fd.rip port=%fd.sport proc=%proc.name)
  priority: CRITICAL
  tags: [network, container]
EOF
```

---

## Q14 – Audit Log Investigation (6 điểm)

```bash
# Q14a: User tạo ClusterRoleBinding
jq -r 'select(.objectRef.resource=="clusterrolebindings" and .verb=="create") | .user.username' \
  /tmp/m3-audit.log
# Đáp án: mallory

# Q14b: ServiceAccount list secrets trong m3-prod
jq -r 'select(.objectRef.resource=="secrets" and .verb=="list" and .objectRef.namespace=="m3-prod") | .user.username' \
  /tmp/m3-audit.log
# Đáp án: system:serviceaccount:m3-prod:compromised-sa

# Q14c: Số lần anonymous user cố truy cập
jq 'select(.user.username=="system:anonymous")' /tmp/m3-audit.log | wc -l
# Đáp án: 3

# Q14d: Pod bị xóa và bởi user nào
jq -r 'select(.objectRef.resource=="pods" and .verb=="delete") | "\(.objectRef.name) by \(.user.username)"' \
  /tmp/m3-audit.log
# Đáp án: web-pod by mallory

cat > /tmp/m3-audit-answers.txt <<'EOF'
Q14a: mallory (tạo ClusterRoleBinding evil-binding)
Q14b: system:serviceaccount:m3-prod:compromised-sa
Q14c: 3 lần (anonymous user bị từ chối 403)
Q14d: Pod web-pod bị xóa bởi mallory
EOF
```

---

## Q15 – Runtime Threat Response (7 điểm)

```bash
# Kiểm tra pod suspicious-pod
kubectl get pod suspicious-pod -n m3-runtime -o yaml

# Ghi threat report
cat > /tmp/m3-threat-report.txt <<'EOF'
Pod: suspicious-pod / Namespace: m3-runtime
Các vấn đề bảo mật phát hiện:
1. hostPID: true — Pod có thể thấy tất cả processes trên host
2. hostNetwork: true — Pod dùng network namespace của host
3. privileged: true — Container có toàn quyền trên host
4. allowPrivilegeEscalation: true — Cho phép leo thang đặc quyền
5. runAsUser: 0 — Chạy với root user
6. hostPath volume mount / — Mount toàn bộ filesystem của host
Mức độ nguy hiểm: CRITICAL — Pod có thể escape container và kiểm soát host
EOF

# Xóa pod nguy hiểm
kubectl delete pod suspicious-pod -n m3-runtime

# Tạo pod thay thế an toàn
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: secure-replacement
  namespace: m3-runtime
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: nginx:1.25-alpine
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop: [ALL]
    volumeMounts:
    - name: tmp
      mountPath: /tmp
  volumes:
  - name: tmp
    emptyDir: {}
EOF
```

---

## Bảng điểm

| Domain | Câu | Điểm tối đa | Điểm của bạn |
|--------|-----|-------------|--------------|
| Cluster Setup | Q1, Q2 | 15 | ___ |
| Cluster Hardening | Q3, Q4 | 15 | ___ |
| System Hardening | Q5, Q6 | 10 | ___ |
| Microservice Vulnerabilities | Q7, Q8, Q9 | 20 | ___ |
| Supply Chain Security | Q10, Q11, Q12 | 20 | ___ |
| Monitoring/Runtime | Q13, Q14, Q15 | 20 | ___ |
| **Tổng** | | **100** | **___** |

---

## Phân tích điểm yếu

Nếu bạn dưới 67 điểm, tập trung ôn lại:

| Điểm yếu | Lab cần ôn |
|----------|-----------|
| Q1 (Egress NetworkPolicy) | lab-1.1-network-policy |
| Q3 (Audit Policy) | lab-2.2-audit-policy |
| Q8 (etcd Encryption) | lab-4.2-secret-encryption |
| Q9 (PSA Restricted) | lab-1.2-pod-security-standards |
| Q10 (ImagePolicyWebhook) | lab-5.3-image-policy |
| Q13 (Falco Rules) | lab-6.1-falco-rules |
| Q14 (Audit Log Analysis) | lab-6.2-audit-log-analysis |
