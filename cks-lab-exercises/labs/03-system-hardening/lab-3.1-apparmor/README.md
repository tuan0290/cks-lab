# Lab 3.1 – AppArmor

**Domain:** System Hardening (10%)
**Thời gian ước tính:** 25 phút
**Độ khó:** Nâng cao

---

## Mục tiêu

- Tạo AppArmor profile `k8s-deny-write` chặn quyền ghi file trên node
- Tải profile lên node bằng `apparmor_parser`
- Tạo pod `secure-pod` trong namespace `apparmor-lab` với annotation gắn AppArmor profile
- Xác minh profile đang hoạt động bằng `aa-status` và kiểm tra hành vi trong container

---

## Bối cảnh

Bạn là kỹ sư bảo mật tại một công ty đang vận hành Kubernetes cluster trên Linux. Sau khi audit, bạn phát hiện một số container có thể ghi file tùy ý vào filesystem — đây là rủi ro bảo mật nghiêm trọng nếu container bị compromise.

Nhiệm vụ của bạn là:
1. Tạo AppArmor profile `k8s-deny-write` chặn toàn bộ thao tác ghi file
2. Tải profile lên node worker bằng `apparmor_parser`
3. Tạo pod `secure-pod` trong namespace `apparmor-lab` với container `secure-container`, gắn profile qua annotation
4. Xác minh profile đang được enforce và container không thể ghi file

---

## Yêu cầu môi trường

- Kubernetes cluster >= 1.29 chạy trên Linux (AppArmor phải được bật trên node)
- `kubectl` đã được cấu hình và kết nối đến cluster
- Quyền SSH vào node worker để chạy `apparmor_parser`
- AppArmor kernel module đã được load: `cat /sys/module/apparmor/parameters/enabled` trả về `Y`

Chạy script khởi tạo môi trường:

```bash
bash setup.sh
```

---

## Các bước thực hiện

### Bước 1: Kiểm tra AppArmor trên node

SSH vào node worker và kiểm tra AppArmor đang hoạt động:

```bash
# Kiểm tra AppArmor được bật
cat /sys/module/apparmor/parameters/enabled
# Kết quả mong đợi: Y

# Xem các profile đang được load
sudo aa-status
```

### Bước 2: Tạo AppArmor profile

Tạo file profile tại `/tmp/k8s-deny-write` trên node worker:

```bash
cat > /tmp/k8s-deny-write <<'EOF'
#include <tunables/global>

profile k8s-deny-write flags=(attach_disconnected) {
  #include <abstractions/base>

  # Cho phép đọc mọi file
  file,

  # Chặn tất cả thao tác ghi file
  deny /** w,
  deny /** a,
}
EOF
```

### Bước 3: Tải profile lên node

Trên node worker, tải profile bằng `apparmor_parser`:

```bash
sudo apparmor_parser -r -W /tmp/k8s-deny-write

# Xác minh profile đã được load
sudo aa-status | grep k8s-deny-write
```

### Bước 4: Tạo pod với AppArmor annotation

Tạo pod `secure-pod` trong namespace `apparmor-lab` với annotation gắn profile:

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

### Bước 5: Xác minh profile hoạt động

```bash
# Kiểm tra pod đang Running
kubectl get pod secure-pod -n apparmor-lab

# Thử ghi file trong container — phải bị từ chối
kubectl exec secure-pod -n apparmor-lab -c secure-container -- \
  sh -c "echo test > /tmp/testfile"
# Kết quả mong đợi: sh: can't create /tmp/testfile: Permission denied

# Kiểm tra đọc file vẫn hoạt động
kubectl exec secure-pod -n apparmor-lab -c secure-container -- \
  sh -c "cat /etc/hostname"

# Chạy verify script
bash verify.sh
```

---

## Tiêu chí kiểm tra

- [ ] Pod `secure-pod` tồn tại trong namespace `apparmor-lab` và đang ở trạng thái `Running`
- [ ] Pod có annotation `container.apparmor.security.beta.kubernetes.io/secure-container=localhost/k8s-deny-write`
- [ ] AppArmor profile `k8s-deny-write` đã được load trên node (xác minh bằng `aa-status`)

---

## Gợi ý

<details>
<summary>Gợi ý 1: Cú pháp annotation AppArmor trong pod</summary>

Annotation AppArmor có format:

```
container.apparmor.security.beta.kubernetes.io/<container-name>: localhost/<profile-name>
```

- `<container-name>`: tên container trong spec (không phải tên pod)
- `localhost/`: tiền tố bắt buộc khi dùng profile đã load trên node
- `<profile-name>`: tên profile như khai báo trong file profile (dòng `profile <name>`)

Ví dụ:
```yaml
annotations:
  container.apparmor.security.beta.kubernetes.io/secure-container: localhost/k8s-deny-write
```

</details>

<details>
<summary>Gợi ý 2: Cách load AppArmor profile lên node</summary>

```bash
# Load profile lần đầu
sudo apparmor_parser -a /tmp/k8s-deny-write

# Reload profile (nếu đã tồn tại)
sudo apparmor_parser -r /tmp/k8s-deny-write

# Load và ghi vào cache (-W)
sudo apparmor_parser -r -W /tmp/k8s-deny-write

# Xác minh profile đã được load
sudo aa-status | grep k8s-deny-write
```

Lưu ý: Profile phải được load trên **đúng node** mà pod sẽ chạy. Trong môi trường multi-node, cần load trên tất cả node worker hoặc dùng DaemonSet.

</details>

<details>
<summary>Gợi ý 3: Cấu trúc AppArmor profile cơ bản</summary>

```
#include <tunables/global>

profile <tên-profile> flags=(attach_disconnected) {
  #include <abstractions/base>

  # Cho phép đọc
  file,

  # Chặn ghi (deny override allow)
  deny /** w,
  deny /** a,
}
```

- `flags=(attach_disconnected)`: cho phép profile hoạt động với container namespace
- `deny /** w,`: chặn ghi vào mọi file
- `deny /** a,`: chặn append vào mọi file
- Quy tắc `deny` luôn ưu tiên hơn `allow`

</details>

---

## Giải pháp mẫu

<details>
<summary>Xem giải pháp đầy đủ (chỉ mở sau khi đã thử)</summary>

Xem file [solution/solution.md](solution/solution.md) để có các bước chi tiết và giải thích.

</details>

---

## Giải thích

### AppArmor là gì và tại sao quan trọng?

AppArmor (Application Armor) là Linux Security Module (LSM) cho phép giới hạn quyền của tiến trình theo profile. Trong Kubernetes, AppArmor cung cấp lớp bảo vệ bổ sung cho container:

- **Giới hạn filesystem access**: Chặn container ghi vào các đường dẫn nhạy cảm
- **Giới hạn network access**: Kiểm soát kết nối mạng của container
- **Giới hạn capability**: Ngăn container sử dụng Linux capabilities nguy hiểm

### Tại sao chặn ghi file quan trọng?

Nếu container bị compromise (ví dụ: RCE vulnerability), kẻ tấn công thường cần ghi file để:
- Cài backdoor hoặc malware
- Sửa đổi cấu hình ứng dụng
- Ghi script để duy trì persistence

Profile `k8s-deny-write` ngăn chặn hoàn toàn các hành động này.

### AppArmor vs Seccomp

| Tính năng | AppArmor | Seccomp |
|---|---|---|
| Kiểm soát | File, network, capability | System calls |
| Cú pháp | Profile text file | JSON |
| Phạm vi | Đường dẫn cụ thể | Syscall cụ thể |
| Kết hợp | Có thể dùng cùng nhau | Có thể dùng cùng nhau |

### Lưu ý về Kubernetes version

- Kubernetes < 1.30: Dùng annotation `container.apparmor.security.beta.kubernetes.io/<container>`
- Kubernetes >= 1.30: Có thể dùng field `securityContext.appArmorProfile` (GA)

---

## Tham khảo

- [Kubernetes AppArmor Documentation](https://kubernetes.io/docs/tutorials/security/apparmor/)
- [AppArmor Profile Language](https://gitlab.com/apparmor/apparmor/-/wikis/QuickProfileLanguage)
- [CKS Exam Curriculum – System Hardening](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/)
- [Linux AppArmor Wiki](https://wiki.ubuntu.com/AppArmor)
