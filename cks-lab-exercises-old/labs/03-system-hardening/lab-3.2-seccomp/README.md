# Lab 3.2 – Seccomp

**Domain:** System Hardening (10%)
**Thời gian ước tính:** 25 phút
**Độ khó:** Nâng cao

---

## Mục tiêu

- Tạo Seccomp profile JSON chặn syscall nguy hiểm: `mkdir`, `chmod`, `chown` và các biến thể
- Đặt profile vào đúng đường dẫn trên node: `/var/lib/kubelet/seccomp/profiles/deny-write.json`
- Tạo pod `hardened-pod` trong namespace `seccomp-lab` với `securityContext.seccompProfile` sử dụng profile đó
- Cấu hình SecurityContext đầy đủ theo nguyên tắc least-privilege: `runAsNonRoot`, `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`, `capabilities.drop: [ALL]`

---

## Lý thuyết

### System Call (Syscall) là gì?

Mọi chương trình khi cần tài nguyên hệ thống (đọc file, tạo process, kết nối mạng...) phải gọi **system call** — giao diện giữa user space và kernel. Ví dụ:
- `open()` — mở file
- `execve()` — chạy chương trình mới
- `connect()` — tạo kết nối mạng
- `mkdir()` — tạo thư mục

Container chia sẻ kernel với host — nếu container có thể gọi bất kỳ syscall nào, kẻ tấn công có thể khai thác lỗ hổng kernel để escape container.

### Seccomp là gì?

**Seccomp (Secure Computing Mode)** là tính năng Linux kernel cho phép **lọc system call** mà một tiến trình có thể thực hiện. Seccomp profile định nghĩa:
- Syscall nào được phép (`SCMP_ACT_ALLOW`)
- Syscall nào bị chặn (`SCMP_ACT_ERRNO` — trả về lỗi)
- Syscall nào kill process (`SCMP_ACT_KILL`)

### Cấu trúc Seccomp profile (JSON)

```json
{
  "defaultAction": "SCMP_ACT_ALLOW",   // Cho phép tất cả mặc định
  "syscalls": [
    {
      "names": ["mkdir", "chmod", "chown"],  // Danh sách syscall cần chặn
      "action": "SCMP_ACT_ERRNO"             // Trả về lỗi EPERM
    }
  ]
}
```

**2 chiến lược:**

| Chiến lược | defaultAction | Danh sách | Ưu điểm | Nhược điểm |
|-----------|--------------|-----------|---------|------------|
| **Denylist** | `SCMP_ACT_ALLOW` | Syscall bị chặn | Dễ viết | Ít an toàn hơn |
| **Allowlist** | `SCMP_ACT_ERRNO` | Syscall được phép | An toàn hơn | Khó viết, dễ break app |

### Đường dẫn Seccomp profile trên node

Kubelet tìm kiếm Seccomp profile tại:
```
/var/lib/kubelet/seccomp/
```

Khi khai báo trong pod:
```yaml
seccompProfile:
  type: Localhost
  localhostProfile: profiles/my-profile.json
```
→ Kubelet tìm file tại: `/var/lib/kubelet/seccomp/profiles/my-profile.json`

### Cách áp dụng Seccomp vào pod

```yaml
spec:
  securityContext:
    seccompProfile:
      type: Localhost                          # Dùng profile tùy chỉnh
      localhostProfile: profiles/deny-write.json  # Đường dẫn tương đối
  containers:
  - name: app
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop: [ALL]
```

### 3 loại Seccomp profile

| Type | Mô tả | Khi nào dùng |
|------|-------|--------------|
| `Unconfined` | Không giới hạn syscall | Development |
| `RuntimeDefault` | Profile mặc định của container runtime | Baseline security |
| `Localhost` | Profile tùy chỉnh trên node | Khi cần kiểm soát chi tiết |

### SecurityContext — Defense in Depth

Seccomp thường kết hợp với các SecurityContext settings khác:

```yaml
securityContext:
  seccompProfile:
    type: RuntimeDefault      # Lọc syscall nguy hiểm
  runAsNonRoot: true          # Không chạy với UID 0
  allowPrivilegeEscalation: false  # Ngăn setuid/setgid
  readOnlyRootFilesystem: true     # Filesystem chỉ đọc
  capabilities:
    drop: [ALL]               # Bỏ tất cả Linux capabilities
```

Mỗi lớp bảo vệ một vector tấn công khác nhau — kết hợp tạo thành **defense in depth**.

---

## Bối cảnh

Bạn là kỹ sư bảo mật tại một công ty đang vận hành Kubernetes cluster. Sau khi phân tích rủi ro, bạn xác định rằng các container không nên có khả năng tạo thư mục (`mkdir`), thay đổi quyền file (`chmod`), hoặc thay đổi chủ sở hữu file (`chown`) — đây là các syscall thường bị lạm dụng trong các cuộc tấn công leo thang đặc quyền và persistence.

Nhiệm vụ của bạn là:
1. Tạo Seccomp profile JSON chặn syscall `mkdir`, `mkdirat`, `chmod`, `fchmod`, `fchmodat`, `chown`, `fchown`, `fchownat`, `lchown`
2. Copy profile vào đúng đường dẫn trên node worker: `/var/lib/kubelet/seccomp/profiles/deny-write.json`
3. Tạo pod `hardened-pod` trong namespace `seccomp-lab` với seccompProfile loại `Localhost` trỏ đến profile đó
4. Đảm bảo pod có đầy đủ SecurityContext theo nguyên tắc least-privilege

---

## Yêu cầu môi trường

- Kubernetes cluster >= 1.29
- `kubectl` đã được cấu hình và kết nối đến cluster
- Quyền SSH vào node worker để copy file vào `/var/lib/kubelet/seccomp/profiles/`
- Kubelet trên node worker hỗ trợ custom seccomp profiles

Chạy script khởi tạo môi trường:

```bash
bash setup.sh
```

---

## Các bước thực hiện

### Bước 1: Tạo Seccomp profile JSON

Tạo file profile tại `/tmp/deny-write.json`:

```bash
cat > /tmp/deny-write.json <<'EOF'
{
  "defaultAction": "SCMP_ACT_ALLOW",
  "syscalls": [
    {
      "names": [
        "mkdir",
        "mkdirat",
        "chmod",
        "fchmod",
        "fchmodat",
        "chown",
        "fchown",
        "fchownat",
        "lchown"
      ],
      "action": "SCMP_ACT_ERRNO"
    }
  ]
}
EOF
```

### Bước 2: Copy profile vào đúng đường dẫn trên node

Kubelet tìm kiếm Seccomp profile tại `/var/lib/kubelet/seccomp/`. Bạn cần copy file vào thư mục `profiles/` bên trong:

```bash
# Tạo thư mục nếu chưa tồn tại (trên node worker)
ssh <user>@<node-ip> 'sudo mkdir -p /var/lib/kubelet/seccomp/profiles'

# Copy profile lên node
scp /tmp/deny-write.json <user>@<node-ip>:/tmp/deny-write.json
ssh <user>@<node-ip> 'sudo cp /tmp/deny-write.json /var/lib/kubelet/seccomp/profiles/deny-write.json'

# Xác minh file đã được copy
ssh <user>@<node-ip> 'ls -la /var/lib/kubelet/seccomp/profiles/'
```

Nếu đang dùng single-node cluster (kind, minikube, kubeadm trên local):

```bash
sudo mkdir -p /var/lib/kubelet/seccomp/profiles
sudo cp /tmp/deny-write.json /var/lib/kubelet/seccomp/profiles/deny-write.json
```

### Bước 3: Tạo pod với Seccomp profile và SecurityContext đầy đủ

Tạo pod `hardened-pod` trong namespace `seccomp-lab`:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: hardened-pod
  namespace: seccomp-lab
spec:
  securityContext:
    seccompProfile:
      type: Localhost
      localhostProfile: profiles/deny-write.json
    runAsNonRoot: true
    runAsUser: 1000
  containers:
  - name: hardened-container
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
EOF
```

### Bước 4: Xác minh Seccomp profile hoạt động

```bash
# Kiểm tra pod đang Running
kubectl get pod hardened-pod -n seccomp-lab

# Thử chạy mkdir trong container — phải bị từ chối
kubectl exec hardened-pod -n seccomp-lab -- mkdir /tmp/testdir
# Kết quả mong đợi: mkdir: can't create directory '/tmp/testdir': Operation not permitted

# Thử chạy chmod trong container — phải bị từ chối
kubectl exec hardened-pod -n seccomp-lab -- chmod 777 /etc/hostname
# Kết quả mong đợi: chmod: /etc/hostname: Operation not permitted

# Chạy verify script
bash verify.sh
```

---

## Tiêu chí kiểm tra

- [ ] Pod `hardened-pod` tồn tại trong namespace `seccomp-lab` và đang ở trạng thái `Running`
- [ ] Pod có `securityContext.seccompProfile.type=Localhost` và `localhostProfile=profiles/deny-write.json`
- [ ] Pod có đầy đủ SecurityContext: `runAsNonRoot: true`, `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`, `capabilities.drop` chứa `ALL`

---

## Gợi ý

<details>
<summary>Gợi ý 1: Cấu trúc Seccomp profile JSON</summary>

Seccomp profile có hai trường chính:

- `defaultAction`: hành động mặc định cho tất cả syscall không được liệt kê
  - `SCMP_ACT_ALLOW`: cho phép (dùng khi muốn chặn một số syscall cụ thể)
  - `SCMP_ACT_ERRNO`: trả về lỗi (dùng khi muốn chặn tất cả trừ một số)
  - `SCMP_ACT_LOG`: ghi log nhưng không chặn
- `syscalls`: danh sách các rule ghi đè cho syscall cụ thể

Ví dụ profile chặn `mkdir`, `chmod`, `chown`:

```json
{
  "defaultAction": "SCMP_ACT_ALLOW",
  "syscalls": [
    {
      "names": ["mkdir", "mkdirat", "chmod", "fchmod", "fchmodat", "chown", "fchown", "fchownat", "lchown"],
      "action": "SCMP_ACT_ERRNO"
    }
  ]
}
```

</details>

<details>
<summary>Gợi ý 2: Đường dẫn Seccomp profile trên node</summary>

Kubelet tìm kiếm Seccomp profile tại thư mục gốc `/var/lib/kubelet/seccomp/`.

Khi bạn khai báo trong pod:
```yaml
seccompProfile:
  type: Localhost
  localhostProfile: profiles/deny-write.json
```

Kubelet sẽ tìm file tại:
```
/var/lib/kubelet/seccomp/profiles/deny-write.json
```

Đường dẫn trong `localhostProfile` là **tương đối** so với `/var/lib/kubelet/seccomp/`.

</details>

<details>
<summary>Gợi ý 3: Cú pháp seccompProfile và SecurityContext đầy đủ</summary>

Từ Kubernetes 1.19+, dùng field `seccompProfile` trong `securityContext`:

```yaml
spec:
  securityContext:
    seccompProfile:
      type: Localhost
      localhostProfile: profiles/deny-write.json
    runAsNonRoot: true
    runAsUser: 1000
  containers:
  - name: hardened-container
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
```

Lưu ý: `seccompProfile` và `runAsNonRoot` đặt ở pod-level `spec.securityContext`, còn `allowPrivilegeEscalation`, `readOnlyRootFilesystem`, `capabilities` đặt ở container-level `spec.containers[].securityContext`.

</details>

---

## Giải pháp mẫu

<details>
<summary>Xem giải pháp đầy đủ (chỉ mở sau khi đã thử)</summary>

Xem file [solution/solution.md](solution/solution.md) để có các bước chi tiết và giải thích.

</details>

---

## Giải thích

### Seccomp là gì và tại sao quan trọng?

Seccomp (Secure Computing Mode) là tính năng Linux kernel cho phép lọc system call mà một tiến trình có thể thực hiện. Trong Kubernetes, Seccomp cung cấp lớp bảo vệ quan trọng:

- **Giảm attack surface**: Chặn các syscall nguy hiểm mà container không cần dùng
- **Ngăn leo thang đặc quyền**: Các syscall như `chmod`, `chown`, `setuid` thường bị lạm dụng để leo thang đặc quyền
- **Ngăn persistence**: `mkdir` bị chặn ngăn kẻ tấn công tạo thư mục để cài backdoor
- **Defense in depth**: Kết hợp với AppArmor và SecurityContext để tạo nhiều lớp bảo vệ

### Tại sao chặn mkdir, chmod và chown?

- `mkdir`/`mkdirat`: Tạo thư mục — kẻ tấn công dùng để tạo thư mục chứa malware hoặc backdoor
- `chmod`/`fchmod`/`fchmodat`: Thay đổi quyền file — có thể làm file executable hoặc world-writable
- `chown`/`fchown`/`fchownat`/`lchown`: Thay đổi chủ sở hữu file — có thể chiếm quyền sở hữu file nhạy cảm

Cần chặn tất cả biến thể vì mỗi syscall phục vụ một trường hợp khác nhau (theo đường dẫn, theo file descriptor, với AT_* flags, với symlink).

### SecurityContext best practices

Kết hợp Seccomp với các SecurityContext settings khác tạo thành defense in depth:

```yaml
securityContext:
  seccompProfile:
    type: Localhost
    localhostProfile: profiles/deny-write.json
  runAsNonRoot: true          # Không chạy với UID 0
  allowPrivilegeEscalation: false  # Ngăn setuid/setgid
  readOnlyRootFilesystem: true     # Filesystem chỉ đọc
  capabilities:
    drop:
    - ALL                     # Bỏ tất cả Linux capabilities
```

### Các loại Seccomp profile

| Type | Mô tả | Khi nào dùng |
|------|-------|--------------|
| `Unconfined` | Không giới hạn syscall | Development, debugging |
| `RuntimeDefault` | Profile mặc định của runtime (containerd/cri-o) | Baseline security |
| `Localhost` | Profile tùy chỉnh trên node | Khi cần kiểm soát chi tiết |

---

## Tham khảo

- [Kubernetes Seccomp Documentation](https://kubernetes.io/docs/tutorials/security/seccomp/)
- [Seccomp Security Profiles](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [Linux Seccomp Man Page](https://man7.org/linux/man-pages/man2/seccomp.2.html)
- [CKS Exam Curriculum – System Hardening](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/)
- [OCI Runtime Spec – Seccomp](https://github.com/opencontainers/runtime-spec/blob/main/config-linux.md#seccomp)
