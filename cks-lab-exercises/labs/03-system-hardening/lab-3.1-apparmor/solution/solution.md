# Giải pháp – Lab 3.1 AppArmor

## Bước 1: Tạo AppArmor profile

Tạo file profile tại `/tmp/k8s-deny-write` trên node worker:

```bash
cat > /tmp/k8s-deny-write <<'EOF'
#include <tunables/global>

profile k8s-deny-write flags=(attach_disconnected) {
  #include <abstractions/base>

  # Cho phép đọc mọi file
  file,

  # Chặn tất cả thao tác ghi và append file
  deny /** w,
  deny /** a,
}
EOF
```

**Giải thích profile:**
- `#include <tunables/global>`: Import các biến toàn cục của AppArmor
- `flags=(attach_disconnected)`: Cho phép profile hoạt động với container network namespace bị tách biệt
- `#include <abstractions/base>`: Import các quy tắc cơ bản (đọc thư viện hệ thống, v.v.)
- `file,`: Cho phép đọc tất cả file (không có mode = read-only)
- `deny /** w,`: Chặn ghi vào mọi đường dẫn (recursive)
- `deny /** a,`: Chặn append vào mọi đường dẫn (recursive)

## Bước 2: Load profile bằng apparmor_parser

SSH vào node worker và chạy:

```bash
# Load (hoặc reload) profile vào kernel
sudo apparmor_parser -r -W /tmp/k8s-deny-write
```

**Giải thích các flag:**
- `-r`: Replace — reload profile nếu đã tồn tại
- `-W`: Write cache — ghi profile vào cache để tự động load khi reboot

## Bước 3: Xác minh profile đã được load

```bash
sudo aa-status | grep k8s-deny-write
```

Output mong đợi:
```
   k8s-deny-write
```

Hoặc xem toàn bộ trạng thái:
```bash
sudo aa-status
```

## Bước 4: Tạo pod với AppArmor annotation

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
  namespace: apparmor-lab
  annotations:
    container.apparmor.security.beta.kubernetes.io/secure-container: localhost/k8s-deny-write
spec:
  containers:
  - name: secure-container
    image: busybox:1.36
    command: ["sleep", "3600"]
```

Áp dụng:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
  namespace: apparmor-lab
  annotations:
    container.apparmor.security.beta.kubernetes.io/secure-container: localhost/k8s-deny-write
spec:
  containers:
  - name: secure-container
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF
```

**Giải thích annotation:**
- Key: `container.apparmor.security.beta.kubernetes.io/<container-name>`
- Value: `localhost/<profile-name>` — tiền tố `localhost/` chỉ định profile đã được load trên node

## Bước 5: Xác minh profile đang hoạt động

### Kiểm tra pod Running

```bash
kubectl get pod secure-pod -n apparmor-lab
# NAME         READY   STATUS    RESTARTS   AGE
# secure-pod   1/1     Running   0          30s
```

### Kiểm tra ghi file bị chặn

```bash
kubectl exec secure-pod -n apparmor-lab -c secure-container -- \
  sh -c "echo test > /tmp/testfile"
# sh: can't create /tmp/testfile: Permission denied
```

### Kiểm tra đọc file vẫn hoạt động

```bash
kubectl exec secure-pod -n apparmor-lab -c secure-container -- \
  sh -c "cat /etc/hostname"
# secure-pod
```

### Xác minh profile trên node với aa-status

```bash
# SSH vào node worker
sudo aa-status

# Output sẽ hiển thị:
# X profiles are in enforce mode.
#    k8s-deny-write
```

### Kiểm tra profile được gắn vào process container

```bash
# Lấy PID của process trong container
kubectl exec secure-pod -n apparmor-lab -c secure-container -- cat /proc/1/attr/current
# k8s-deny-write (enforce)
```

## Tóm tắt các lệnh quan trọng

| Lệnh | Mục đích |
|------|----------|
| `apparmor_parser -r -W <file>` | Load/reload profile vào kernel |
| `apparmor_parser -R <file>` | Unload profile khỏi kernel |
| `aa-status` | Xem tất cả profile đang được load |
| `aa-enforce <profile>` | Chuyển profile sang enforce mode |
| `aa-complain <profile>` | Chuyển profile sang complain mode (log nhưng không chặn) |
| `cat /proc/<pid>/attr/current` | Xem AppArmor profile của một process |
