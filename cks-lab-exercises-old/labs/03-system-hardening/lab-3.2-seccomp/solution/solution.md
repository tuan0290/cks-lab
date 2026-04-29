# Giải pháp – Lab 3.2 – Seccomp

## Bước 1: Tạo Seccomp profile JSON

Tạo file `/tmp/deny-write.json` với nội dung sau:

```json
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
```

Lệnh tạo file:

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

**Giải thích profile:**
- `defaultAction: SCMP_ACT_ALLOW`: cho phép tất cả syscall theo mặc định (denylist approach)
- `syscalls[].action: SCMP_ACT_ERRNO`: trả về lỗi `EPERM` (Operation not permitted) cho các syscall được liệt kê
- `mkdir`/`mkdirat`: chặn tạo thư mục — ngăn kẻ tấn công tạo thư mục để cài backdoor
- `chmod`/`fchmod`/`fchmodat`: chặn thay đổi quyền file
- `chown`/`fchown`/`fchownat`/`lchown`: chặn thay đổi chủ sở hữu file

## Bước 2: Copy profile vào đúng đường dẫn trên node

Kubelet tìm kiếm Seccomp profile tại `/var/lib/kubelet/seccomp/`. Đường dẫn đầy đủ phải là:

```
/var/lib/kubelet/seccomp/profiles/deny-write.json
```

Lệnh copy (thay `<user>` và `<node-ip>` phù hợp với môi trường của bạn):

```bash
# Tạo thư mục trên node worker
ssh <user>@<node-ip> 'sudo mkdir -p /var/lib/kubelet/seccomp/profiles'

# Copy file profile lên node
scp /tmp/deny-write.json <user>@<node-ip>:/tmp/deny-write.json
ssh <user>@<node-ip> 'sudo cp /tmp/deny-write.json /var/lib/kubelet/seccomp/profiles/deny-write.json'

# Xác minh
ssh <user>@<node-ip> 'ls -la /var/lib/kubelet/seccomp/profiles/'
```

Nếu đang dùng single-node cluster (kind, minikube, kubeadm trên local):

```bash
sudo mkdir -p /var/lib/kubelet/seccomp/profiles
sudo cp /tmp/deny-write.json /var/lib/kubelet/seccomp/profiles/deny-write.json
```

## Bước 3: Tạo pod với Seccomp profile và SecurityContext đầy đủ

```yaml
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
```

Lệnh apply:

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

**Giải thích SecurityContext:**
- `seccompProfile.type: Localhost`: dùng profile tùy chỉnh đã đặt trên node
- `seccompProfile.localhostProfile: profiles/deny-write.json`: đường dẫn tương đối so với `/var/lib/kubelet/seccomp/`
- `runAsNonRoot: true`: container phải chạy với UID khác 0
- `runAsUser: 1000`: chạy với UID 1000 cụ thể
- `allowPrivilegeEscalation: false`: ngăn tiến trình con có thêm quyền hơn tiến trình cha (chặn setuid/setgid)
- `readOnlyRootFilesystem: true`: mount root filesystem ở chế độ read-only
- `capabilities.drop: [ALL]`: bỏ tất cả Linux capabilities

## Bước 4: Xác minh

```bash
# Kiểm tra pod Running
kubectl get pod hardened-pod -n seccomp-lab

# Xác minh seccompProfile được áp dụng
kubectl get pod hardened-pod -n seccomp-lab \
  -o jsonpath='{.spec.securityContext.seccompProfile}' | jq .

# Thử mkdir — phải bị từ chối
kubectl exec hardened-pod -n seccomp-lab -- mkdir /tmp/testdir
# Kết quả: mkdir: can't create directory '/tmp/testdir': Operation not permitted

# Thử chmod — phải bị từ chối
kubectl exec hardened-pod -n seccomp-lab -- chmod 777 /etc/hostname
# Kết quả: chmod: /etc/hostname: Operation not permitted

# Thử chown — phải bị từ chối
kubectl exec hardened-pod -n seccomp-lab -- chown 0:0 /etc/hostname
# Kết quả: chown: /etc/hostname: Operation not permitted

# Chạy verify script
bash verify.sh
```

---

## Giải thích về các loại Seccomp profile

### defaultAction

| Giá trị | Ý nghĩa |
|---------|---------|
| `SCMP_ACT_ALLOW` | Cho phép syscall (dùng khi muốn chặn một số cụ thể) |
| `SCMP_ACT_ERRNO` | Trả về lỗi `EPERM` (Operation not permitted) |
| `SCMP_ACT_KILL` | Kill tiến trình ngay lập tức |
| `SCMP_ACT_LOG` | Ghi log nhưng không chặn |
| `SCMP_ACT_TRAP` | Gửi SIGSYS signal |

### Chiến lược profile

**Allowlist (whitelist)**: `defaultAction: SCMP_ACT_ERRNO`, liệt kê các syscall được phép
- An toàn hơn nhưng khó viết — cần biết chính xác container cần syscall nào
- Dùng cho workload production quan trọng

**Denylist (blacklist)**: `defaultAction: SCMP_ACT_ALLOW`, liệt kê các syscall bị chặn
- Dễ viết hơn — chỉ cần chặn các syscall nguy hiểm đã biết
- Dùng trong bài lab này: cho phép tất cả trừ `mkdir`, `chmod`, `chown` và các biến thể

### Tại sao cần chặn cả các biến thể syscall?

Mỗi syscall phục vụ một trường hợp khác nhau:
- `mkdir(path, mode)`: tạo thư mục theo đường dẫn
- `mkdirat(dirfd, path, mode)`: tạo thư mục với AT_* flags
- `chmod(path, mode)`: thay đổi quyền theo đường dẫn
- `fchmod(fd, mode)`: thay đổi quyền theo file descriptor
- `fchmodat(dirfd, path, mode, flags)`: thay đổi quyền với AT_* flags
- `chown(path, uid, gid)`: thay đổi chủ sở hữu theo đường dẫn
- `fchown(fd, uid, gid)`: thay đổi chủ sở hữu theo file descriptor
- `fchownat(dirfd, path, uid, gid, flags)`: thay đổi chủ sở hữu với AT_* flags
- `lchown(path, uid, gid)`: thay đổi chủ sở hữu của symlink (không follow)

Nếu chỉ chặn `mkdir` mà không chặn `mkdirat`, kẻ tấn công vẫn có thể dùng `mkdirat` để đạt mục đích tương tự.
