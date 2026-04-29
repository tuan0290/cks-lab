# Đáp án Mock Exam 3

## Tổng điểm: 100 | Điểm đạt: 67

---

## Q1 – NetworkPolicy Ingress (5 điểm)

```bash
# Deny all ingress + egress trong m3-backend
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: m3-backend
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF

# Allow ingress từ m3-frontend trên port 8080
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend
  namespace: m3-backend
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: m3-frontend
    ports:
    - protocol: TCP
      port: 8080
EOF
```

---

## Q2 – NetworkPolicy Egress Control (5 điểm)

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
  - ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
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

## Q3 – containerd + kube-bench CIS (5 điểm)

```bash
# Đọc kube-bench output
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

# Kiểm tra containerd config
grep "SystemdCgroup" /etc/containerd/config.toml
# Nếu chưa có, thêm vào:
# [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
#   SystemdCgroup = true

# Restart kubelet
systemctl restart kubelet
systemctl status kubelet
```

---

## Q4 – API Server Security Flags (5 điểm)

```bash
# Kiểm tra từng flag
grep "anonymous-auth" /etc/kubernetes/manifests/kube-apiserver.yaml
grep "authorization-mode" /etc/kubernetes/manifests/kube-apiserver.yaml
grep "enable-admission-plugins" /etc/kubernetes/manifests/kube-apiserver.yaml
grep "service-account-lookup" /etc/kubernetes/manifests/kube-apiserver.yaml

# Ghi kết quả
cat > /tmp/m3-apiserver-audit.txt <<'EOF'
--anonymous-auth=false          → CẦN CÓ (tắt anonymous access)
--authorization-mode=Node,RBAC  → CẦN CÓ (chỉ dùng RBAC)
--enable-admission-plugins=NodeRestriction,EventRateLimit → CẦN CÓ
--service-account-lookup=true   → CẦN CÓ (validate ServiceAccount token)
EOF

# Nếu thiếu flag nào, thêm vào kube-apiserver manifest:
vi /etc/kubernetes/manifests/kube-apiserver.yaml
```

---

## Q5 – Audit Policy Advanced (5 điểm)

```bash
mkdir -p /etc/kubernetes/audit
mkdir -p /var/log/kubernetes/audit

cat > /etc/kubernetes/audit/policy.yaml <<'EOF'
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: None
  userGroups: ["system:nodes"]

- level: RequestResponse
  verbs: ["create", "update", "delete", "patch"]
  resources:
  - group: ""
    resources: ["secrets"]

- level: Request
  verbs: ["get", "list"]
  resources:
  - group: ""
    resources: ["secrets"]

- level: RequestResponse
  verbs: ["create", "delete"]
  resources:
  - group: ""
    resources: ["pods"]
  namespaces: ["m3-prod"]

- level: Metadata
  omitStages:
  - RequestReceived
EOF

# Thêm vào kube-apiserver
vi /etc/kubernetes/manifests/kube-apiserver.yaml
# Thêm:
# - --audit-log-path=/var/log/kubernetes/audit/audit.log
# - --audit-policy-file=/etc/kubernetes/audit/policy.yaml
# - --audit-log-maxage=7
# - --audit-log-maxbackup=3
# - --audit-log-maxsize=50

watch crictl ps
```

---

## Q6 – ServiceAccount + RBAC Hardening (5 điểm)

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa
  namespace: m3-secure
automountServiceAccountToken: false
EOF

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

## Q7 – seccomp Custom Profile (4 điểm)

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

# Pod dùng Localhost profile
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

# Pod dùng RuntimeDefault
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: seccomp-default-pod
  namespace: m3-system
spec:
  securityContext:
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: nginx:1.25-alpine
EOF
```

---

## Q8 – AppArmor + Capabilities (3 điểm)

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

## Q9 – Kernel Security Parameters (3 điểm)

```bash
cat > /etc/sysctl.d/99-m3-security.conf <<'EOF'
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.all.accept_redirects=0
kernel.kexec_load_disabled=1
kernel.yama.ptrace_scope=1
fs.protected_hardlinks=1
fs.protected_symlinks=1
EOF

sysctl -p /etc/sysctl.d/99-m3-security.conf
```

---

## Q10 – Pod Security Admission Strict (5 điểm)

```bash
kubectl label namespace m3-prod \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/warn=restricted \
  pod-security.kubernetes.io/enforce-version=latest \
  pod-security.kubernetes.io/audit-version=latest \
  pod-security.kubernetes.io/warn-version=latest \
  --overwrite

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

# Test vi phạm
kubectl run violating-pod --image=nginx --privileged -n m3-prod
# Mong đợi: Error from server (Forbidden)
```

---

## Q11 – Trivy Image Scan (5 điểm)

```bash
trivy image --format json --output /tmp/m3-scan.json nginx:1.14.0

trivy image --severity CRITICAL --format json nginx:1.14.0 2>/dev/null | \
  python3 -c "
import json, sys
data = json.load(sys.stdin)
count = sum(len([v for v in r.get('Vulnerabilities', []) if v.get('Severity')=='CRITICAL'])
            for r in data.get('Results', []))
print(count)
" > /tmp/m3-critical-count.txt

kubectl set image deployment/web-app web=nginx:1.25-alpine -n m3-vuln
kubectl rollout status deployment/web-app -n m3-vuln
```

---

## Q12 – etcd Encryption (5 điểm)

```bash
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
# - --encryption-provider-config=/etc/kubernetes/encryption/config.yaml

watch crictl ps

kubectl create secret generic m3-encrypted-secret \
  --from-literal=key=value -n m3-secure
```

---

## Q13 – ResourceQuota + LimitRange (5 điểm)

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ResourceQuota
metadata:
  name: m3-quota
  namespace: m3-prod
spec:
  hard:
    requests.cpu: "2"
    requests.memory: 4Gi
    limits.cpu: "4"
    limits.memory: 8Gi
EOF

kubectl apply -f - <<EOF
apiVersion: v1
kind: LimitRange
metadata:
  name: m3-limits
  namespace: m3-prod
spec:
  limits:
  - default:
      cpu: 500m
      memory: 512Mi
    defaultRequest:
      cpu: 100m
      memory: 128Mi
    type: Container
EOF
```

---

## Q14 – ImagePolicyWebhook (5 điểm)

```bash
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

vi /etc/kubernetes/manifests/kube-apiserver.yaml
# - --enable-admission-plugins=NodeRestriction,ImagePolicyWebhook
# - --admission-control-config-file=/etc/kubernetes/policywebhook/admission_config.json

watch crictl ps

kubectl run test-pod --image=nginx --restart=Never
# Mong đợi: connection refused (defaultAllow=false)
```

---

## Q15 – Cosign Sign + Verify (5 điểm)

```bash
mkdir -p /tmp/m3-cosign
cd /tmp/m3-cosign

COSIGN_PASSWORD="" cosign generate-key-pair
COSIGN_PASSWORD="" cosign sign --key cosign.key docker.io/library/nginx:1.25-alpine
COSIGN_PASSWORD="" cosign verify --key cosign.pub \
  docker.io/library/nginx:1.25-alpine 2>&1 | tee verify-output.txt
```

---

## Q16 – Kyverno Policy (5 điểm)

```bash
kubectl apply -f - <<EOF
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: check-image-registry
spec:
  validationFailureAction: enforce
  background: true
  rules:
  - name: verify-registry
    match:
      any:
      - resources:
          kinds:
          - Pod
          namespaces:
          - m3-prod
    validate:
      message: "Images must only be pulled from approved registries"
      pattern:
        spec:
          containers:
          - image: "registry.k8s.io/* | docker.io/library/*"
EOF
```

---

## Q17 – SBOM với Syft + Trivy Config Scan (5 điểm)

```bash
# Tạo SBOM
syft nginx:1.25-alpine -o cyclonedx-json > /tmp/m3-sbom.json

# Tìm openssl version
cat /tmp/m3-sbom.json | jq -r '.components[] | select(.name=="openssl") | .version' \
  > /tmp/m3-openssl-version.txt
cat /tmp/m3-openssl-version.txt

# Trivy config scan
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
```

---

## Q18 – Falco Custom Rules (5 điểm)

```bash
sudo tee /etc/falco/rules.d/m3-rules.yaml <<'EOF'
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

## Q19 – Audit Log Investigation (5 điểm)

```bash
# Q19a: User tạo ClusterRoleBinding
jq -r 'select(.objectRef.resource=="clusterrolebindings" and .verb=="create") | .user.username' \
  /tmp/m3-audit.log
# Đáp án: mallory

# Q19b: ServiceAccount list secrets trong m3-prod
jq -r 'select(.objectRef.resource=="secrets" and .verb=="list" and .objectRef.namespace=="m3-prod") | .user.username' \
  /tmp/m3-audit.log
# Đáp án: system:serviceaccount:m3-prod:compromised-sa

# Q19c: Số lần anonymous user cố truy cập
jq 'select(.user.username=="system:anonymous")' /tmp/m3-audit.log | wc -l
# Đáp án: 3

# Q19d: Pod bị xóa
jq -r 'select(.objectRef.resource=="pods" and .verb=="delete") | "\(.objectRef.name) by \(.user.username)"' \
  /tmp/m3-audit.log
# Đáp án: web-pod by mallory

cat > /tmp/m3-audit-answers.txt <<'EOF'
Q19a: mallory (tạo ClusterRoleBinding evil-binding)
Q19b: system:serviceaccount:m3-prod:compromised-sa
Q19c: 3 lần (anonymous user bị từ chối 403)
Q19d: Pod web-pod bị xóa bởi mallory
EOF
```

---

## Q20 – Cilium IPsec Encryption (5 điểm)

```bash
cat > /tmp/m3-cilium-config.yaml <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: cilium-config
  namespace: kube-system
data:
  enable-ipsec: "true"
  ipsec-key-file: "/etc/cilium/ipsec/keys"
  encryption: "ipsec"
  encryption-node-encryption: "true"
  tls-ca-cert: "/var/lib/cilium/tls/ca.crt"
  tls-client-cert: "/var/lib/cilium/tls/client.crt"
  tls-client-key: "/var/lib/cilium/tls/client.key"
EOF

cat > /tmp/m3-cilium-notes.txt <<'EOF'
IPsec vs WireGuard trong Cilium:

IPsec:
- Giao thức cũ hơn, được hỗ trợ rộng rãi
- Hoạt động ở kernel level (xfrm framework)
- Cần quản lý key thủ công hoặc qua Kubernetes Secret
- Overhead cao hơn WireGuard
- Cấu hình: encryption: "ipsec"

WireGuard:
- Giao thức mới hơn, hiệu năng cao hơn
- Tích hợp sẵn trong Linux kernel >= 5.6
- Key rotation tự động
- Overhead thấp hơn IPsec
- Cấu hình: encryption: "wireguard"

Cả hai đều mã hóa Pod-to-Pod traffic (east-west traffic).
Dùng encryption-node-encryption: "true" để mã hóa cả node-to-node traffic.
EOF
```

---

## Q21 – Runtime Threat Response (5 điểm)

```bash
kubectl get pod suspicious-pod -n m3-runtime -o yaml

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

kubectl delete pod suspicious-pod -n m3-runtime

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
| Cluster Setup | Q1, Q2, Q3 | 15 | ___ |
| Cluster Hardening | Q4, Q5, Q6 | 15 | ___ |
| System Hardening | Q7, Q8, Q9 | 10 | ___ |
| Microservice Vulnerabilities | Q10, Q11, Q12, Q13 | 20 | ___ |
| Supply Chain Security | Q14, Q15, Q16, Q17 | 20 | ___ |
| Monitoring/Runtime | Q18, Q19, Q20, Q21 | 20 | ___ |
| **Tổng** | | **100** | **___** |

---

## Phân tích điểm yếu

| Điểm yếu | Lab cần ôn |
|----------|-----------|
| Q1, Q2 (NetworkPolicy) | lab-1.1-network-policy |
| Q3 (containerd/kube-bench) | lab-1.4-kube-bench |
| Q5 (Audit Policy) | lab-2.2-audit-policy |
| Q6 (RBAC/SA) | lab-2.1-rbac-least-privilege |
| Q7 (seccomp) | lab-3.2-seccomp |
| Q8 (AppArmor) | lab-3.1-apparmor |
| Q10 (PSA) | lab-1.2-pod-security-standards |
| Q12 (etcd Encryption) | lab-4.2-secret-encryption |
| Q14 (ImagePolicyWebhook) | lab-5.3-image-policy |
| Q15 (Cosign) | lab-5.1-cosign-image-signing |
| Q17 (SBOM/Syft) | lab-5.4-sbom |
| Q18 (Falco) | lab-6.1-falco-rules |
| Q19 (Audit Log) | lab-6.2-audit-log-analysis |
| Q20 (Cilium) | lab-4.5-cilium-encryption |
