# Kubernetes CKS 2026 - Hướng Dẫn Học & Lab Thực Hành

> **Phiên bản:** v2.0 (2026)  
> **Dựa trên:** CNCF cập nhật ngày 15/10/2024  
> **Kubernetes Version:** v1.34  
> **Cập nhật:** 24/01/2026

---

## 📋 Mục Lục

1. [Tổng Quan Kỳ Thi](#i-tổng-quan-kỳ-thi)
2. [Thay Đổi Quan Trọng 2024](#ii-thay-đổi-quan-trọng-2024)
3. [Domain 1: Cluster Setup (15%)](#domain-1-cluster-setup-15)
4. [Domain 2: Cluster Hardening (15%)](#domain-2-cluster-hardening-15)
5. [Domain 3: System Hardening (10%)](#domain-3-system-hardening-10)
6. [Domain 4: Minimize Microservice Vulnerabilities (20%)](#domain-4-minimize-microservice-vulnerabilities-20)
7. [Domain 5: Supply Chain Security (20%)](#domain-5-supply-chain-security-20)
8. [Domain 6: Monitoring, Logging & Runtime Security (20%)](#domain-6-monitoring-logging--runtime-security-20)
9. [Lộ Trình Học (12-14 Tuần)](#iv-lộ-trình-học-12-14-tuần)
10. [Checklist Thực Hành](#v-checklist-thực-hành)
11. [Quick Reference Commands](#vi-quick-reference-commands)
12. [Mẹo Thi](#vii-mẹo-thi)
13. [Tài Nguyên Học Tập](#viii-tài-nguyên-học-tập)

---

## I. Tổng Quan Kỳ Thi

| Thông tin | Chi tiết |
|-----------|---------|
| Tên chứng chỉ | Certified Kubernetes Security Specialist (CKS) |
| Thời gian thi | 2 giờ |
| Số câu hỏi | 15-20 câu (thực hành) |
| Điểm đậu | 67% |
| Hình thức | Online proctoring + thực hành trên Kubernetes cluster |
| Hiệu lực | 3 năm |
| Giá thi | $395 USD |
| Điều kiện | **Bắt buộc có CKA còn hiệu lực** |
| Cập nhật mới nhất | 15/10/2024 |
| Phiên bản K8s | v1.34 (2025) |

### Phân bổ trọng số các Domain (v1.34)

```
1. Cluster Setup        (Thiết lập cluster)      15% ██████
2. Cluster Hardening    (Tăng cường cluster)      15% ██████
3. System Hardening     (Tăng cường hệ thống)     10% ████
4. Minimize Microservice Vulnerabilities          20% ████████  ← Tăng
5. Supply Chain Security (Bảo mật chuỗi cung ứng) 20% ████████  ← Tăng
6. Monitoring, Logging & Runtime Security         20% ████████  ← Tăng
```

> **Lưu ý:** 3 domain cuối chiếm tới **60%** tổng điểm!

---

## II. Thay Đổi Quan Trọng 2024

| Loại thay đổi | Phiên bản cũ (trước 2024) | Phiên bản mới (sau 10/2024) |
|---------------|--------------------------|----------------------------|
| Pod Security | Pod Security Policy (PSP) | **Pod Security Admission (PSA)** |
| Supply Chain Security | 10% | **20%** (tăng gấp đôi) |
| Microservice Vulnerabilities | 15% | **20%** (trọng tâm mới) |
| Runtime Safety | 15% | **20%** (Falco là trọng tâm chính) |
| Mirror Signature | Đề cập ngắn | **Sigstore/Cosign chuyên sâu** |
| Inter-Pod Encryption | Không có | **Yêu cầu CNI plugin encryption** |

### 🆕 Nội dung MỚI cần học:
- Pod Security Admission (PSA)
- Sigstore/Cosign (ký và xác thực image)
- Falco (phát hiện mối đe dọa runtime)
- CNI Pod-to-Pod encryption
- Kyverno (chính sách kiểm soát)

### ✅ Nội dung cũ vẫn còn (đã tăng cường):
- RBAC (nguyên tắc tối thiểu đặc quyền)
- NetworkPolicy
- seccomp/AppArmor
- Quét lỗ hổng bảo mật image (Trivy)

### ❌ Nội dung đã BỊ XÓA:
- Pod Security Policy (PSP) — đã deprecated
- Docker runtime → thay bằng containerd/CRI-O

---

## Domain 1: Cluster Setup (15%)

**Trọng tâm thi:**
- NetworkPolicy: giới hạn truy cập cấp cluster
- CIS benchmark: kiểm tra cấu hình bảo mật K8s components (etcd, kubelet, kubedns, kubeapi)
- Ingress TLS: cấu hình đúng Ingress với TLS
- Metadata protection: bảo vệ node metadata và endpoints
- Binary verification: xác thực binary trước khi deploy

| Kỹ năng | Trọng số | Ghi chú |
|---------|---------|---------|
| Cấu hình NetworkPolicy | 40% | Cơ bản + nâng cao |
| Bảo mật etcd | 30% | Mã hóa, Backup, Access Control |
| Bảo mật container runtime | 30% | Cấu hình containerd/CRI-O |

---

### Lab 1.1: Cấu hình etcd Encryption

```yaml
# /etc/kubernetes/encryption-config.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
    - secrets
    providers:
    - aescbc:
        keys:
        - name: key1
          secret: <32-byte-base64-key>
    - identity: {}  # Fallback (đọc dữ liệu cũ chưa mã hóa)
```

```bash
# Tạo key 32 bytes
head -c 32 /dev/urandom | base64

# Thêm vào kube-apiserver
--encryption-provider-config=/etc/kubernetes/encryption-config.yaml
```

---

### Lab 1.2: NetworkPolicy - Deny All Ingress

```yaml
# Chặn tất cả ingress traffic vào namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```

```yaml
# Cho phép frontend → backend port 8080
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
```

---

### Lab 1.3: Cấu hình containerd

```toml
# /etc/containerd/config.toml
version = 3
[plugins."io.containerd.grpc.v1.cri"]
  [plugins."io.containerd.grpc.v1.cri".containerd]
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
        runtime_type = "io.containerd.runc.v2"
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
          SystemdCgroup = true
```

---

## Domain 2: Cluster Hardening (15%)

**Trọng tâm thi:**
- RBAC tối thiểu đặc quyền
- ServiceAccount: vô hiệu hóa auto-mount, giảm quyền
- Giới hạn truy cập Kubernetes API
- Nâng cấp Kubernetes tránh lỗ hổng bảo mật

| Kỹ năng | Trọng số | Ghi chú |
|---------|---------|---------|
| API Server Security | 30% | Authentication, Authorization, Audit |
| RBAC chuyên sâu | 40% | Tối thiểu quyền, role binding |
| Control plane security | 30% | Giao tiếp component, quản lý certificate |

---

### Lab 2.1: Cấu hình API Server Security

```bash
# Các tham số quan trọng của kube-apiserver
--anonymous-auth=false                              # Tắt anonymous access
--authorization-mode=Node,RBAC                      # Chỉ dùng RBAC
--enable-admission-plugins=NodeRestriction,EventRateLimit
--secure-port=6443                                  # Chỉ dùng HTTPS
--tls-cert-file=/etc/kubernetes/pki/apiserver.crt
--tls-private-key-file=/etc/kubernetes/pki/apiserver.key
--client-ca-file=/etc/kubernetes/pki/ca.crt
--service-account-lookup=true                       # Validate ServiceAccount
--service-account-key-file=/etc/kubernetes/pki/sa.pub
--service-account-signing-key-file=/etc/kubernetes/pki/sa.key
```

---

### Lab 2.2: RBAC - Nguyên tắc Tối Thiểu Đặc Quyền

```yaml
# Tạo ServiceAccount với quyền tối thiểu (chỉ đọc deployment)
apiVersion: v1
kind: ServiceAccount
metadata:
  name: deployment-reader
  namespace: production
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: deployment-reader-role
  namespace: production
rules:
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: deployment-reader-binding
  namespace: production
subjects:
- kind: ServiceAccount
  name: deployment-reader
  namespace: production
roleRef:
  kind: Role
  name: deployment-reader-role
  apiGroup: rbac.authorization.k8s.io
---
# Pod sử dụng SA với quyền tối thiểu
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
  namespace: production
spec:
  serviceAccountName: deployment-reader
  automountServiceAccountToken: true  # hoặc false nếu không cần
```

```bash
# Kiểm tra quyền
kubectl auth can-i delete secrets -n default --as=system:anonymous
kubectl auth can-i get secrets --all-namespaces
```

---

### Lab 2.3: Cấu hình Audit Log

```yaml
# /etc/kubernetes/audit-policy.yaml
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
  - RequestReceived
rules:
  # Ghi log đầy đủ khi tạo/sửa/xóa Secret
  - level: RequestResponse
    verbs: ["create", "update", "delete", "patch"]
    resources:
    - group: ""
      resources: ["secrets"]

  # Ghi metadata khi đọc Secret
  - level: Request
    verbs: ["get", "list"]
    resources:
    - group: ""
      resources: ["secrets"]

  # Ghi log đầy đủ cho Deployment/StatefulSet
  - level: RequestResponse
    verbs: ["create", "update", "delete", "patch"]
    resources:
    - group: "apps"
      resources: ["deployments", "statefulsets", "daemonsets"]
    - group: "batch"
      resources: ["jobs", "cronjobs"]

  # Metadata cho tất cả resource còn lại
  - level: Metadata
    verbs: ["*"]
    resources:
    - group: ""
      resources: ["*"]
    omitStages:
    - RequestReceived

  # Không ghi log node get/list events (giảm noise)
  - level: None
    userGroups: ["system:nodes"]
    verbs: ["get", "list"]
    resources:
    - group: ""
      resources: ["events", "nodes"]

  # Ghi log anonymous requests
  - level: Request
    userGroups: ["system:unauthenticated"]
    resources:
    - group: ""
      resources: ["*"]
```

```bash
# Thêm vào kube-apiserver
--audit-log-path=/var/log/kubernetes/audit.log
--audit-policy-file=/etc/kubernetes/audit-policy.yaml
--audit-log-maxage=30
--audit-log-maxbackup=10
--audit-log-maxsize=100
```

---

### Lab 2.4: Kubelet Security Configuration

```yaml
# /var/lib/kubelet/config.yaml
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false          # Quan trọng: tắt anonymous auth
  webhook:
    enabled: true
    cacheTTL: 2m
  x509:
    clientCAFile: /etc/kubernetes/pki/ca.crt
authorization:
  mode: Webhook             # Dùng Webhook (không dùng AlwaysAllow)
  webhook:
    cacheAuthorizedTTL: 5m
    cacheUnauthorizedTTL: 30s
address: 0.0.0.0
port: 10250
readOnlyPort: 0             # Quan trọng: tắt readonly port (mặc định 10255)
rotateCertificates: true
serverTLSBootstrap: true
clusterDomain: cluster.local
clusterDNS:
  - 10.96.0.10
maxPods: 110
staticPodPath: /etc/kubernetes/manifests
cgroupDriver: systemd
```

---

## Domain 3: System Hardening (10%)

**Trọng tâm thi:**
- Minimize host OS footprint (giảm attack surface)
- Least Privilege IAM
- Giới hạn truy cập mạng từ bên ngoài
- Kernel hardening: AppArmor và seccomp

| Kỹ năng | Trọng số | Ghi chú |
|---------|---------|---------|
| Cấu hình seccomp | 35% | Lọc system call |
| Cấu hình AppArmor | 35% | Access control profile |
| Tham số kernel security | 30% | sysctl, capabilities |

---

### Lab 3.1: seccomp Profile

```json
// /var/lib/kubelet/seccomp/my-profile.json
{
  "defaultAction": "SCMP_ACT_ERRNO",
  "architectures": ["SCMP_ARCH_X86_64"],
  "syscalls": [
    {
      "names": [
        "read", "write", "open", "close", "stat", "fstat",
        "lstat", "poll", "lseek", "mmap", "brk",
        "rt_sigaction", "rt_sigprocmask", "rt_sigreturn",
        "ioctl", "pread64", "pwrite64", "readv", "writev",
        "access", "pipe", "select", "sched_yield", "mremap",
        "munmap", "dup", "dup2", "pause", "nanosleep",
        "getpid", "sendfile", "socket", "connect", "accept",
        "sendto", "recvfrom", "sendmsg", "recvmsg",
        "shutdown", "bind", "listen", "getsockname",
        "clone", "fork", "vfork", "execve", "exit",
        "wait4", "kill", "uname"
      ],
      "action": "SCMP_ACT_ALLOW"
    }
  ]
}
```

```yaml
# Cách 1: Dùng Localhost profile tùy chỉnh
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  securityContext:
    seccompProfile:
      type: Localhost
      localhostProfile: my-profile.json  # relative to /var/lib/kubelet/seccomp/
  containers:
  - name: container
    image: nginx:alpine
```

```yaml
# Cách 2 (Khuyến nghị): Dùng RuntimeDefault
apiVersion: v1
kind: Pod
metadata:
  name: runtime-default-seccomp
spec:
  securityContext:
    seccompProfile:
      type: RuntimeDefault   # Mặc định của container runtime
  containers:
  - name: container
    image: nginx:alpine
```

---

### Lab 3.2: AppArmor Configuration

```bash
# Tạo AppArmor profile tại /etc/apparmor.d/nginx-apparmor
#include <tunables/global>

profile nginx-apparmor flags=(attach_disconnected) {
  #include <abstractions/base>

  # Cho phép network
  network inet stream,
  network inet6 stream,

  # Cho phép đọc config và web files
  /etc/nginx/** r,
  /var/www/** r,
  /var/log/nginx/** w,
  /run/nginx.pid w,

  # Capabilities cần thiết
  capability setgid,
  capability setuid,

  # Từ chối truy cập file nhạy cảm
  deny /etc/shadow rwx,
  deny /root/** rwx,

  # Audit các write không được phép
  audit deny /** w,
}
```

```bash
# Load AppArmor profile
sudo apparmor_parser -r /etc/apparmor.d/nginx-apparmor

# Kiểm tra đã load chưa
sudo aa-status | grep nginx
# Output mong đợi: nginx-apparmor (enforce mode)
```

```yaml
# Áp dụng AppArmor vào Pod
apiVersion: v1
kind: Pod
metadata:
  name: nginx-apparmor
spec:
  containers:
  - name: nginx
    image: nginx
    securityContext:
      appArmorProfile:
        type: Localhost
        localhostProfile: nginx-apparmor
```

---

### Lab 3.3: Linux Capabilities Management

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: capabilities-pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 1000
  containers:
  - name: app
    image: nginx:alpine
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL                    # Drop tất cả capabilities
        add:
        - NET_BIND_SERVICE       # Chỉ thêm capability cần thiết (bind port <1024)
      privileged: false
```

---

### Lab 3.4: Kernel Security Parameters (sysctl)

```bash
# /etc/sysctl.d/99-kubernetes-security.conf

# Bảo vệ network
net.ipv4.ip_forward=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.send_redirects=0
net.ipv4.conf.all.accept_source_route=0
net.ipv4.conf.all.accept_redirects=0
net.ipv4.icmp_echo_ignore_broadcasts=1
net.ipv4.conf.all.log_martians=1

# Bảo vệ kernel
kernel.kexec_load_disabled=1
kernel.yama.ptrace_scope=1

# Bảo vệ filesystem
fs.protected_hardlinks=1
fs.protected_symlinks=1
fs.suid_dumpable=0

# Áp dụng
sysctl -p /etc/sysctl.d/99-kubernetes-security.conf
```

---

## Domain 4: Minimize Microservice Vulnerabilities (20%)

**Trọng tâm thi:**
- Pod Security Standards (PSA)
- Secret Management
- Isolation technology (multi-tenancy, sandbox containers)
- Pod-to-Pod Encryption (Cilium, Istio)

| Kỹ năng | Trọng số | Ghi chú |
|---------|---------|---------|
| Pod Security Admission | 40% | PSA 3 cấp độ chuẩn |
| Quét image (Trivy) | 30% | Sử dụng chuyên sâu |
| Security Context | 20% | Pod/container level |
| Resource Strategy | 10% | Restrictions/Quotas |

---

### Lab 4.1: Pod Security Admission (PSA) — Thay thế PSP

```yaml
# Cấp độ 1: Privileged (không giới hạn) — KHÔNG dùng trong production

# Cấp độ 2: Baseline (giới hạn cơ bản)
apiVersion: v1
kind: Namespace
metadata:
  name: baseline-ns
  labels:
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/audit: baseline
    pod-security.kubernetes.io/warn: baseline

---
# Cấp độ 3: Restricted (giới hạn chặt nhất) — Dùng cho production
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

**Baseline level — Không cho phép:**
- `hostPort: true`
- `privileged: true`
- `hostNetwork: true` / `hostPID: true` / `hostIPC: true`
- Arbitrary capabilities
- Chạy với root user

**Restricted level — Bổ sung thêm:**
- `runAsNonRoot: true` (bắt buộc)
- `allowPrivilegeEscalation: false` (bắt buộc)
- `capabilities.drop: [ALL]` (bắt buộc)
- `seccompProfile.type: RuntimeDefault` hoặc `Localhost` (bắt buộc)
- `readOnlyRootFilesystem: true` (bắt buộc)
- Volume types bị giới hạn (không có `hostPath`)

```yaml
# Ví dụ Pod đúng chuẩn Restricted level
apiVersion: v1
kind: Pod
metadata:
  name: restricted-pod
  namespace: production
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: nginx:1.25-alpine
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop:
        - ALL
      readOnlyRootFilesystem: true
    volumeMounts:
    - name: cache
      mountPath: /var/cache/nginx
    - name: run
      mountPath: /var/run
  volumes:
  - name: cache
    emptyDir: {}
  - name: run
    emptyDir: {}
```

---

### Lab 4.2: Trivy - Quét lỗ hổng image

```bash
# Quét cơ bản
trivy image nginx:1.21

# Chỉ hiện HIGH và CRITICAL
trivy image --severity HIGH,CRITICAL nginx:1.21

# Output JSON
trivy image --format json nginx:1.21

# Lưu report ra file
trivy image --output report.txt nginx:1.21

# Quét filesystem
trivy fs /path/to/image

# Quét toàn bộ namespace trong K8s
trivy k8s --namespace production

# Quét một Pod cụ thể
trivy k8s pod --namespace default my-pod
```

---

### Lab 4.3: ResourceQuota & LimitRange

```yaml
# ResourceQuota — Giới hạn tổng tài nguyên namespace
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-resources
  namespace: production
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    persistentvolumeclaims: "4"
---
# LimitRange — Giới hạn mặc định cho từng Pod/Container
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: production
spec:
  limits:
  - default:          # Limit mặc định nếu không khai báo
      cpu: 500m
      memory: 512Mi
    defaultRequest:   # Request mặc định nếu không khai báo
      cpu: 100m
      memory: 128Mi
    max:              # Giới hạn tối đa
      cpu: "2"
      memory: 4Gi
    min:              # Giới hạn tối thiểu
      cpu: 50m
      memory: 64Mi
    type: Container
```

---

## Domain 5: Supply Chain Security (20%)

**Trọng tâm thi:**
- Minimize base image size
- Hiểu supply chain (SBOM, CI/CD, private registry)
- Bảo vệ supply chain (ký và xác thực image)
- Static analysis (Kubesec, KubeLinter)

| Kỹ năng | Trọng số | Ghi chú |
|---------|---------|---------|
| Xác thực chữ ký image | 40% | Sigstore/Cosign |
| Admission controller | 30% | ImagePolicyWebhook |
| Private mirror repository | 20% | Harbor security |
| SBOM Analysis | 10% | Syft |

---

### Lab 5.1: Cosign — Ký và Xác thực Image

```bash
# Cài cosign
go install github.com/sigstore/cosign/v2/cmd/cosign@latest

# Tạo key pair
cosign generate-key-pair

# Ký image
cosign sign myregistry.io/myproject/myimage:v1.0

# Ký với annotations
cosign sign \
  --annotations "version=1.0" \
  --annotations "author=team" \
  myregistry.io/myproject/myimage:v1.0

# Xác thực chữ ký
cosign verify myregistry.io/myproject/myimage:v1.0 \
  --key cosign.pub

# Gắn SBOM vào image
syft myregistry.io/myproject/myimage:v1.0 -o cyclonedx-json > sbom.json
cosign attach sbom --type cyclonedx sbom.json \
  myregistry.io/myproject/myimage:v1.0
```

---

### Lab 5.2: Kyverno Policy — Supply Chain Security

```yaml
# Kyverno ClusterPolicy: Chỉ cho phép image từ registry được phép
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: check-image-registry
  annotations:
    policies.kyverno.io/title: Check Image Registry
    policies.kyverno.io/category: Supply Chain Security
    policies.kyverno.io/severity: medium
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
    validate:
      message: "Images must only be pulled from approved registries"
      pattern:
        spec:
          containers:
          - image: "myregistry.io/* | gcr.io/myproject/*"
---
# Kyverno Policy: Xác thực chữ ký image (Cosign)
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-image-signature
  annotations:
    policies.kyverno.io/title: Verify Image Signature
    policies.kyverno.io/severity: high
spec:
  validationFailureAction: enforce
  rules:
  - name: verify-signature
    match:
      any:
      - resources:
          kinds:
          - Pod
    verifyImages:
    - imageReferences:
      - "myregistry.io/*"
      key: |-
        -----BEGIN PUBLIC KEY-----
        MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE...
        -----END PUBLIC KEY-----
```

---

### Lab 5.3: ImagePolicyWebhook

```bash
# Thêm vào kube-apiserver
--enable-admission-plugins=...,ImagePolicyWebhook
--admission-control-config-file=/etc/kubernetes/image-policy/admission_config.yaml
```

---

### Lab 5.4: SBOM với Syft

```bash
# Cài syft
go install github.com/anchore/syft/cmd/syft@latest

# Tạo SBOM (Software Bill of Materials)
syft myregistry.io/myimage:v1.0 -o cyclonedx-json > sbom.json
syft myimage:v1.0 -o spdx-json > sbom-spdx.json
syft myimage:v1.0 -o table

# Tìm package cụ thể trong SBOM
syft myimage:v1.0 --output json | jq '.artifacts[] | select(.name=="openssl")'
```

---

## Domain 6: Monitoring, Logging & Runtime Security (20%)

**Trọng tâm thi:**
- Phân tích hành vi thực thi để phát hiện hoạt động độc hại
- Phát hiện mối đe dọa trong infrastructure, application, network
- Xác định các giai đoạn tấn công
- Đảm bảo tính bất biến của container lúc runtime
- Monitor bằng Kubernetes audit logs

| Kỹ năng | Trọng số | Ghi chú |
|---------|---------|---------|
| Falco runtime monitoring | 40% | Viết rule và phân tích event |
| Audit log analysis | 30% | Query, Filter, Alert |
| Advanced NetworkPolicy | 20% | Các tình huống phức tạp |
| Threat Detection | 10% | Nhận biết hành vi bất thường |

---

### Lab 6.1: Cài đặt Falco

```bash
# Cài Falco bằng Helm
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update
helm install falco falcosecurity/falco \
  --namespace falco --create-namespace \
  --set driver.kind=ebpf \
  --set tty=true

# Kiểm tra Falco pods
kubectl get pods -n falco

# Xem Falco logs (alerts)
kubectl logs -n falco -l app=falcosecurity-falco
```

---

### Lab 6.2: Viết Falco Rules

```yaml
# falco-custom-rules.yaml

# Rule 1: Phát hiện shell container (backdoor)
- rule: Detect Shell Container
  desc: Detect creation of a shell container (potential backdoor)
  condition: >
    shell_containers and not known_shell_containers
  output: >
    Shell container created (user=%user.name container=%container.name
    shell=%container.shell image=%container.image)
  priority: WARNING
  tags: [container, shell]

- macro: shell_containers
  condition: >
    container.entrypoint in (/bin/sh, /bin/bash, /bin/zsh, /bin/fish)

- macro: known_shell_containers
  condition: >
    container.image.repository in (docker.io/library/alpine,
    docker.io/library/ubuntu)

---
# Rule 2: Phát hiện truy cập file nhạy cảm
- rule: Detect Sensitive File Access
  desc: Detect access to sensitive files like /etc/shadow
  condition: >
    open_read and fd.name in (/etc/shadow, /etc/passwd, /etc/sudoers)
    and not proc.aname in (sshd, login, systemd-logind)
  output: >
    Sensitive file access (user=%user.name command=%proc.cmdline file=%fd.name)
  priority: WARNING
  tags: [filesystem, security]

---
# Rule 3: Phát hiện Privileged Container
- rule: Detect Privileged Container
  desc: Detect privileged container startup
  condition: >
    container.privileged=true and not known_privileged_containers
  output: >
    Privileged container started (user=%user.name container=%container.name
    image=%container.image)
  priority: WARNING
  tags: [container, privilege]

---
# Rule 4: Phát hiện kubectl exec đáng ngờ
- rule: Suspicious kubectl exec
  desc: Multiple kubectl exec to different pods in short time
  condition: >
    spawned_process and proc.name="kubectl"
    and proc.args contains "exec"
    and proc.args contains "-it"
  output: >
    Suspicious kubectl exec detected (user=%user.name pod=%k8s.pod.name
    namespace=%k8s.pod.namespace command=%proc.cmdline)
  priority: WARNING
  tags: [kubernetes, exec]

---
# Rule 5: Phát hiện sửa đổi K8s Secret/ConfigMap
- rule: Detect Kubernetes Secret Modification
  desc: Detect modification to K8s secrets
  condition: >
    kubectl.modify and kubectl.resource in (secret, configmap)
  output: >
    Kubernetes secret/configmap modified (user=%user.name
    command=%kubectl.command resource=%kubectl.resource)
  priority: WARNING
  tags: [kubernetes, audit]
```

```yaml
# Deploy custom Falco rules bằng ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: falco-custom-rules
  namespace: falco
data:
  custom-rules.yaml: |
    # Paste nội dung rules ở trên vào đây
```

---

### Lab 6.3: Audit Log Query & Analysis

```bash
# Tìm các thao tác với Secret
grep '"resource":"secrets"' /var/log/kubernetes/audit.log | \
  jq 'select(.stage=="ResponseComplete") | {user, verb, resource, statusCode}'

# Tìm các request thất bại (401)
jq 'select(.responseStatus.code==401)' /var/log/kubernetes/audit.log

# Tìm tạo/xóa Deployment
jq 'select(.object.kind=="Deployment" and (.verb=="create" or .verb=="delete"))' \
  /var/log/kubernetes/audit.log

# Thống kê user theo tần suất hoạt động
jq -r '.user.username' /var/log/kubernetes/audit.log | \
  sort | uniq -c | sort -rn

# Lọc theo thời gian
jq 'select(.requestReceivedTimestamp >= "2026-01-24T00:00:00Z")' \
  /var/log/kubernetes/audit.log

# Tìm Secret bị xóa
jq 'select(.object.kind=="Secret" and .verb=="delete") |
  {user: .user.username, name: .object.metadata.name,
   namespace: .object.metadata.namespace, time: .requestReceivedTimestamp}' \
  /var/log/kubernetes/audit.log
```

---

### Lab 6.4: CNI Network Encryption (Cilium IPsec)

```yaml
# Cilium ConfigMap — Bật IPsec encryption
apiVersion: v1
kind: ConfigMap
metadata:
  name: cilium-config
  namespace: kube-system
data:
  enable-ipsec: "true"
  ipsec-key-file: "/etc/cilium/ipsec/keys"
  encryption: "ipsec"
  encryption-node-encryption: "true"   # Encrypt cả Pod-to-Pod
  tls-ca-cert: "/var/lib/cilium/tls/ca.crt"
  tls-client-cert: "/var/lib/cilium/tls/client.crt"
  tls-client-key: "/var/lib/cilium/tls/client.key"
```

---

## IV. Lộ Trình Học (12-14 Tuần)

```
Tuần 1-2:   Ôn lại K8s cơ bản + môi trường thực hành
Tuần 3-4:   Cluster Setup + NetworkPolicy
Tuần 5-6:   Cluster Hardening + RBAC
Tuần 7-8:   System Hardening + seccomp/AppArmor
Tuần 9-10:  Microservice Vulnerabilities + PSA
Tuần 11:    Supply Chain Security + Cosign/Kyverno
Tuần 12:    Monitoring + Falco + Audit Log
Tuần 13:    Thi thử toàn bộ
Tuần 14:    Ôn lại điểm yếu + thi thật
```

### Lịch học hàng ngày

| Thời gian | Ngày thường (2-3 giờ) | Cuối tuần (4-6 giờ) |
|-----------|----------------------|---------------------|
| 30 phút | Ôn lại ghi chú hôm qua + đọc docs | Học lý thuyết (docs/video) |
| 60 phút | Lab thực hành (KodeKloud/Killercoda) | Lab thực hành đầy đủ |
| 30 phút | Ghi chú + viết command cheat sheet | Lab tổng hợp |
| 60 phút | Làm câu hỏi thực hành (tuỳ chọn) | Ôn lại câu sai |

---

## V. Checklist Thực Hành

```bash
# ===== Domain 1: Cluster Setup =====
□ Cấu hình NetworkPolicy (deny all + allow specific)
□ Mã hóa etcd với EncryptionConfiguration
□ Cấu hình containerd/CRI-O đúng cách

# ===== Domain 2: Cluster Hardening =====
□ Cấu hình API Server security flags
□ Tạo ServiceAccount + RBAC với quyền tối thiểu
□ Bật Audit Logging đúng policy
□ Bảo mật Kubelet config

# ===== Domain 3: System Hardening =====
□ Tạo và áp dụng seccomp profile
□ Tạo và áp dụng AppArmor profile
□ Drop ALL capabilities trong Pod
□ Cấu hình kernel sysctl parameters

# ===== Domain 4: Microservice Vulnerabilities =====
□ Cấu hình Pod Security Admission (3 cấp độ)
□ Quét image với Trivy (chỉ HIGH, CRITICAL)
□ Viết Pod spec đúng chuẩn Restricted level
□ Tạo ResourceQuota + LimitRange

# ===== Domain 5: Supply Chain Security =====
□ Ký image với Cosign
□ Xác thực image với Cosign
□ Cấu hình ImagePolicyWebhook
□ Viết Kyverno policy kiểm soát registry
□ Tạo SBOM với Syft

# ===== Domain 6: Monitoring & Runtime Security =====
□ Cài và cấu hình Falco
□ Viết custom Falco rules (ít nhất 3 loại)
□ Query và phân tích Audit Log với jq
□ Cấu hình CNI encryption (Cilium)
□ Phát hiện và xử lý threat scenarios
```

---

## VI. Quick Reference Commands

```bash
# ===== RBAC =====
kubectl create serviceaccount sa-name -n ns
kubectl create role role-name --verb=get,list --resource=pods -n ns
kubectl create rolebinding rb-name --role=role-name --serviceaccount=ns:sa-name -n ns
kubectl auth can-i delete secrets -n default --as=system:anonymous
kubectl auth can-i get secrets --all-namespaces

# ===== NetworkPolicy =====
kubectl create networkpolicy default-deny -n ns
kubectl get networkpolicies -A

# ===== Pod Security =====
kubectl label ns default pod-security.kubernetes.io/enforce=restricted
kubectl describe ns default | grep pod-security

# ===== Image Scanning =====
trivy image nginx:latest --severity HIGH,CRITICAL
trivy k8s all-namespaces

# ===== Audit Logs =====
kubectl logs -n kube-system kube-apiserver-master

# ===== Falco =====
kubectl logs -n falco -l app=falcosecurity-falco

# ===== Cosign =====
cosign sign myregistry.io/image:tag
cosign verify myregistry.io/image:tag --key cosign.pub

# ===== Certificates =====
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -dates

# ===== Shortcuts hữu ích trong thi =====
alias k=kubectl
alias kg='kubectl get'
alias kd='kubectl delete'
alias ka='kubectl apply -f'

# Chuyển context
kubectl config use-context <context-name>

# Tạo YAML template nhanh
kubectl run my-pod --image=nginx --dry-run=client -o yaml
kubectl create deployment my-deploy --image=nginx --replicas=3 --dry-run=client -o yaml
```

---

## VII. Mẹo Thi

### Quản lý thời gian (20 câu / 120 phút)

```
- Câu dễ   (5-6 phút): 3-4 câu  → làm trước
- Câu trung (8-10 phút): 6-7 câu
- Câu khó  (4-5 phút): 8-10 phút
- Câu bỏ qua: 10 phút cuối
Tổng: 120 phút | Nghỉ: 10 phút
```

### Lỗi thường gặp & Cách tránh

| Lỗi | Cách tránh |
|-----|-----------|
| Sai namespace | Đọc kỹ đề chỉ định ns |
| Sai tên resource | Copy-paste tên từ đề bài |
| Quên verify sau khi làm | Dùng `kubectl get` kiểm tra ngay sau mỗi câu |
| YAML indent sai | Dùng 2 spaces; editor tự format |
| Quên chuyển context | Kiểm tra `kubectl config current-context` đầu mỗi câu |

### Chuẩn bị trước ngày thi

- [ ] Kiểm tra Chrome browser (yêu cầu)
- [ ] Tốc độ internet ≥ 10Mbps
- [ ] Phòng yên tĩnh + đủ ánh sáng
- [ ] Cài PSI Bridge
- [ ] Có ID hợp lệ
- [ ] Làm sạch bàn làm việc
- [ ] CKA certificate còn hiệu lực

---

## VIII. Tài Nguyên Học Tập

### Tài nguyên chính thức

| Tài nguyên | Link | Ghi chú |
|-----------|------|---------|
| CNCF CKS | cncf.io/training/certification/cks | Trang chứng chỉ chính thức |
| CNCF Curriculum | github.com/cncf/curriculum | Syllabus mã nguồn mở |
| CKS Updates | cncf.io/blog | Ghi chú cập nhật 2024 |

### Nền tảng thực hành

| Nền tảng | Link | Miễn phí | Đánh giá |
|---------|------|---------|---------|
| **KodeKloud** | kodekloud.com | Hoàn toàn miễn phí | ★★★★★ |
| **Killercoda** | killercoda.com | Hoàn toàn miễn phí | ★★★★★ |
| O'Reilly | oreilly.com | Có phí | ★★★★☆ |
| Udemy | udemy.com | Có phí | ★★★★☆ |

### Mock Exams (trong repo này)

| Mock Exam | Chủ đề | Thư mục |
|-----------|--------|---------|
| Mock Exam 1 | Toàn diện — tất cả domain | `mock-exams/mock-exam-1/` |
| Mock Exam 2 | Troubleshooting — tìm và sửa cấu hình sai | `mock-exams/mock-exam-2/` |
| Mock Exam 3 | Advanced — tình huống nâng cao, sát đề thi thực tế | `mock-exams/mock-exam-3/` |

**Cách chạy mock exam:**
```bash
# Bước 1: Khởi tạo môi trường
cd mock-exams/mock-exam-3
bash setup.sh

# Bước 2: Bấm giờ 120 phút, làm bài theo README.md

# Bước 3: Xem đáp án
cat solutions/answers.md

# Bước 4: Dọn dẹp
bash cleanup.sh
```

**Lưu ý Mock Exam 3:**
- Q2, Q3, Q8, Q10 yêu cầu quyền truy cập control plane (`/etc/kubernetes/manifests/`)
- Q13 yêu cầu quyền ghi vào `/etc/falco/rules.d/`
- Nên chạy trực tiếp trên control plane node (bastion → master node)

### Tools cần download

```bash
# Trivy — Quét lỗ hổng image
https://github.com/aquasecurity/trivy/releases

# Falco — Runtime security
https://github.com/falcosecurity/falco/releases

# Cosign — Ký image
https://github.com/sigstore/cosign/releases

# Syft — Tạo SBOM
https://github.com/anchore/syft/releases
```

---

## Appendix: Bảng So Sánh Pod Security Standards

| Control Point | Privileged | Baseline | Restricted |
|--------------|-----------|---------|-----------|
| hostProcess | Cho phép | **Cấm** | **Cấm** |
| hostNetwork | Cho phép | **Cấm** | **Cấm** |
| hostPID | Cho phép | **Cấm** | **Cấm** |
| hostIPC | Cho phép | **Cấm** | **Cấm** |
| privileged | Cho phép | **Cấm** | **Cấm** |
| Capabilities | Cho phép tất cả | Default | **Drop ALL** |
| allowPrivilegeEscalation | Cho phép | Cho phép | **Cấm** |
| readOnlyRootFilesystem | Không yêu cầu | Không yêu cầu | **Bắt buộc** |
| RunAsNonRoot | Không yêu cầu | Không yêu cầu | **Bắt buộc** |
| RunAsUser | Cho phép root | Cho phép root | **Yêu cầu non-root** |
| Seccomp | Không yêu cầu | Cho phép unconfined | **RuntimeDefault bắt buộc** |
| Volume type | Bất kỳ | Giới hạn | **Hạn chế hơn (không có hostPath)** |

---

*Tài liệu này được tổng hợp từ bài viết CSDN của "Little White who was..." (2026)*  
*Nguồn gốc: CNCF CKS Certification — Official Certification Page (v1.34)*
