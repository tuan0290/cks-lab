# Lab 1.2 – Pod Security Standards (PSS)

**Domain:** Cluster Setup (15%)
**Thời gian ước tính:** 30 phút
**Độ khó:** Trung bình

---

## Mục tiêu

- Cấu hình namespace `pss-lab` với Pod Security Standards (PSS) ở mức `restricted`
- Hiểu sự khác biệt giữa ba mức PSS: `privileged`, `baseline`, `restricted`
- Hiểu **Linux Capabilities** là gì và tại sao cần `drop: [ALL]`
- Hiểu **Seccomp** là gì và tại sao PSS restricted yêu cầu `seccompProfile`
- Thực hành tạo, sửa, xóa pod với các cấu hình SecurityContext khác nhau
- Xác nhận pod vi phạm bị từ chối và pod hợp lệ chạy được

---

## Lý thuyết

### Pod Security Standards (PSS) là gì?

Trước Kubernetes 1.25, việc kiểm soát bảo mật pod được thực hiện qua **PodSecurityPolicy (PSP)** — một cơ chế phức tạp và khó cấu hình. Từ K8s 1.25, PSP bị xóa hoàn toàn và thay thế bằng **Pod Security Standards (PSS)** — đơn giản hơn, built-in, không cần cài thêm gì.

PSS định nghĩa **3 mức bảo mật** cho pod:

| Mức | Tên | Mô tả | Dùng khi nào |
|-----|-----|-------|--------------|
| 1 | `privileged` | Không hạn chế gì | CNI plugins, storage drivers, workload hệ thống |
| 2 | `baseline` | Ngăn các leo thang đặc quyền rõ ràng | Workload thông thường |
| 3 | `restricted` | Tuân thủ đầy đủ best practices | Workload production nhạy cảm |

### 3 chế độ hoạt động

PSS có 3 chế độ, áp dụng độc lập cho từng namespace qua **label**:

| Chế độ | Label key | Hành vi |
|--------|-----------|---------|
| `enforce` | `pod-security.kubernetes.io/enforce` | **Từ chối** pod vi phạm — pod không được tạo |
| `audit` | `pod-security.kubernetes.io/audit` | Ghi log vi phạm vào audit log, **vẫn cho phép** pod chạy |
| `warn` | `pod-security.kubernetes.io/warn` | Hiển thị **cảnh báo** cho người dùng, vẫn cho phép |

### Linux Capabilities là gì?

**Linux Capabilities** là cơ chế chia nhỏ quyền root thành các đặc quyền riêng biệt. Thay vì "tất cả hoặc không có gì" như root/non-root, capabilities cho phép cấp từng quyền cụ thể.

Ví dụ một số capabilities:

| Capability | Cho phép làm gì | Rủi ro nếu bị lạm dụng |
|-----------|----------------|------------------------|
| `CAP_NET_ADMIN` | Cấu hình network interfaces, firewall | Thay đổi routing, sniff traffic |
| `CAP_SYS_ADMIN` | Gần như toàn quyền hệ thống | Mount filesystem, thay đổi kernel params |
| `CAP_SYS_PTRACE` | Debug process khác | Đọc memory của process khác |
| `CAP_NET_RAW` | Tạo raw socket | Sniff network traffic |
| `CAP_CHOWN` | Thay đổi chủ sở hữu file | Chiếm quyền sở hữu file nhạy cảm |

**Mặc định**, container được cấp một số capabilities nhất định (NET_BIND_SERVICE, CHOWN, DAC_OVERRIDE, FOWNER, FSETID, KILL, SETGID, SETUID, SETPCAP, NET_RAW, SYS_CHROOT, MKNOD, AUDIT_WRITE, SETFCAP). Đây là nhiều hơn mức cần thiết cho hầu hết ứng dụng.

**PSS restricted yêu cầu `drop: [ALL]`** — bỏ tất cả capabilities, sau đó chỉ thêm lại những gì thực sự cần:

```yaml
securityContext:
  capabilities:
    drop: [ALL]          # Bỏ tất cả capabilities
    add: [NET_BIND_SERVICE]  # Chỉ thêm lại nếu cần bind port < 1024
```

### Seccomp là gì?

**Seccomp (Secure Computing Mode)** là tính năng Linux kernel lọc **system calls** mà container có thể thực hiện. Mỗi hành động của process (đọc file, tạo socket, fork process...) đều phải gọi syscall vào kernel — Seccomp kiểm soát syscall nào được phép.

**Tại sao PSS restricted yêu cầu Seccomp?**

Container chia sẻ kernel với host. Nếu không có Seccomp, container có thể gọi bất kỳ syscall nào — kể cả các syscall nguy hiểm có thể khai thác lỗ hổng kernel để escape container.

**3 loại Seccomp profile trong Kubernetes:**

| Type | Mô tả | Khi nào dùng |
|------|-------|--------------|
| `Unconfined` | Không lọc syscall | Development (không dùng production) |
| `RuntimeDefault` | Profile mặc định của container runtime | Baseline security — đủ cho hầu hết workload |
| `Localhost` | Profile tùy chỉnh trên node | Khi cần kiểm soát chi tiết |

**PSS restricted yêu cầu ít nhất `RuntimeDefault`:**

```yaml
securityContext:
  seccompProfile:
    type: RuntimeDefault   # Hoặc Localhost với profile cụ thể
```

### Tất cả yêu cầu của PSS restricted

Pod muốn chạy trong namespace `restricted` phải có **đầy đủ** các trường sau:

```yaml
# Pod-level securityContext
spec:
  securityContext:
    runAsNonRoot: true              # Không chạy với UID 0 (root)
    runAsUser: 1000                 # UID cụ thể (khuyến nghị)
    seccompProfile:
      type: RuntimeDefault          # Seccomp profile bắt buộc

  containers:
  - securityContext:
      allowPrivilegeEscalation: false  # Không cho phép leo thang đặc quyền
      readOnlyRootFilesystem: true     # Filesystem chỉ đọc (khuyến nghị)
      capabilities:
        drop: [ALL]                    # Drop tất cả Linux capabilities
```

Nếu thiếu bất kỳ trường nào → pod bị từ chối với thông báo lỗi chi tiết liệt kê từng vi phạm.

### Cách gắn/sửa/xóa label PSS

```bash
# Gắn label PSS restricted
kubectl label namespace <ns> \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=latest

# Sửa label (thay đổi mức)
kubectl label namespace <ns> \
  pod-security.kubernetes.io/enforce=baseline \
  --overwrite

# Xóa label (tắt PSS enforcement)
kubectl label namespace <ns> pod-security.kubernetes.io/enforce-

# Kiểm tra label hiện tại
kubectl get namespace <ns> --show-labels
```

---

## Bối cảnh

Bạn là kỹ sư bảo mật tại một công ty thương mại điện tử. Sau một cuộc kiểm tra bảo mật, nhóm bảo mật yêu cầu tất cả workload production phải tuân thủ tiêu chuẩn bảo mật pod ở mức `restricted`. Bạn cần hiểu rõ từng yêu cầu của PSS restricted — đặc biệt là Seccomp và Linux Capabilities — để có thể cấu hình đúng và giải thích cho team developer.

---

## Yêu cầu môi trường

- Kubernetes cluster >= 1.29 (PSS được GA từ Kubernetes 1.25)
- `kubectl` đã được cấu hình và kết nối đến cluster

Chạy script khởi tạo môi trường:

```bash
bash setup.sh
```

---

## Các bước thực hiện

### Bước 1: Kiểm tra môi trường

```bash
kubectl get namespaces | grep -E 'pss-lab|pss-baseline'
kubectl get namespace pss-lab --show-labels
```

---

### Bước 2: Gắn PSS restricted lên namespace

```bash
kubectl label namespace pss-lab \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=latest
```

Xác nhận:
```bash
kubectl get namespace pss-lab --show-labels
```

---

### Bước 3: Thử deploy pod vi phạm — quan sát lỗi chi tiết

Tạo pod **không có** SecurityContext (vi phạm nhiều yêu cầu cùng lúc):

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: bad-pod
  namespace: pss-lab
spec:
  containers:
  - name: app
    image: nginx:1.25-alpine
EOF
```

**Đọc kỹ thông báo lỗi** — PSS liệt kê từng vi phạm cụ thể:
```
Error from server (Forbidden): error when creating "STDIN":
pods "bad-pod" is forbidden: violates PodSecurity "restricted:latest":
  allowPrivilegeEscalation != false (container "app" must set securityContext.allowPrivilegeEscalation=false),
  unrestricted capabilities (container "app" must set securityContext.capabilities.drop=["ALL"]),
  runAsNonRoot != true (pod or container "app" must set securityContext.runAsNonRoot=true),
  seccompProfile (pod or container "app" must set securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")
```

---

### Bước 4: Sửa từng vi phạm một — hiểu từng yêu cầu

**Thử 1: Chỉ thêm `runAsNonRoot`** — vẫn còn vi phạm khác:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: partial-pod
  namespace: pss-lab
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
  containers:
  - name: app
    image: nginx:1.25-alpine
EOF
```

Quan sát: vẫn bị từ chối vì thiếu `allowPrivilegeEscalation`, `capabilities.drop`, `seccompProfile`.

**Thử 2: Thêm `allowPrivilegeEscalation: false`** — vẫn còn vi phạm:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: partial-pod2
  namespace: pss-lab
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
  containers:
  - name: app
    image: nginx:1.25-alpine
    securityContext:
      allowPrivilegeEscalation: false
EOF
```

**Thử 3: Thêm `capabilities.drop: [ALL]`** — vẫn thiếu Seccomp:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: partial-pod3
  namespace: pss-lab
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
  containers:
  - name: app
    image: nginx:1.25-alpine
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: [ALL]
EOF
```

Lỗi còn lại: `seccompProfile (pod or container "app" must set securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")`

---

### Bước 5: Pod hoàn chỉnh — đủ tất cả yêu cầu PSS restricted

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: compliant-pod
  namespace: pss-lab
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault    # Seccomp: lọc syscall nguy hiểm
  volumes:
  - name: cache
    emptyDir: {}
  - name: run
    emptyDir: {}
  containers:
  - name: app
    image: nginx:1.25-alpine
    securityContext:
      allowPrivilegeEscalation: false   # Không leo thang đặc quyền
      readOnlyRootFilesystem: true      # Filesystem chỉ đọc
      capabilities:
        drop: [ALL]                     # Drop tất cả Linux capabilities
    volumeMounts:
    - name: cache
      mountPath: /var/cache/nginx
    - name: run
      mountPath: /var/run
EOF
```

Kiểm tra pod đang chạy:
```bash
kubectl get pod compliant-pod -n pss-lab
```

---

### Bước 6: Xác minh Seccomp đang hoạt động

```bash
# Xem seccompProfile trong pod spec
kubectl get pod compliant-pod -n pss-lab \
  -o jsonpath='{.spec.securityContext.seccompProfile}' | python3 -m json.tool

# Xem capabilities đã drop
kubectl get pod compliant-pod -n pss-lab \
  -o jsonpath='{.spec.containers[0].securityContext.capabilities}'
```

---

### Bước 7: Thực hành sửa và xóa pod

**Sửa pod** — thử thêm capability bị cấm:

```bash
# Xóa pod cũ
kubectl delete pod compliant-pod -n pss-lab

# Tạo lại với capability NET_ADMIN (vi phạm PSS restricted)
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: cap-test-pod
  namespace: pss-lab
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
      capabilities:
        drop: [ALL]
        add: [NET_ADMIN]    # Vi phạm! PSS restricted không cho phép add capabilities
EOF
```

Quan sát lỗi: `unrestricted capabilities (container "app" must not include "NET_ADMIN" in securityContext.capabilities.add)`

**Xóa pod:**
```bash
kubectl delete pod cap-test-pod -n pss-lab --ignore-not-found
```

---

### Bước 8: Thử thay đổi PSS level — sửa label

Hạ xuống `baseline` để pod không có Seccomp vẫn chạy được:

```bash
# Sửa label từ restricted → baseline
kubectl label namespace pss-lab \
  pod-security.kubernetes.io/enforce=baseline \
  --overwrite

# Bây giờ pod không có seccompProfile vẫn được tạo
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: baseline-pod
  namespace: pss-lab
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
  containers:
  - name: app
    image: nginx:1.25-alpine
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: [ALL]
EOF

kubectl get pod baseline-pod -n pss-lab
```

Nâng lại về `restricted`:
```bash
kubectl label namespace pss-lab \
  pod-security.kubernetes.io/enforce=restricted \
  --overwrite

# Xóa pod không tuân thủ restricted
kubectl delete pod baseline-pod -n pss-lab
```

---

### Bước 9: Xác minh kết quả

```bash
bash verify.sh
```

---

## Tiêu chí kiểm tra

- [ ] Namespace `pss-lab` có label `pod-security.kubernetes.io/enforce: restricted`
- [ ] Namespace `pss-lab` có label `pod-security.kubernetes.io/enforce-version: latest`
- [ ] Pod privileged bị từ chối khi tạo trong namespace `pss-lab`

---

## Gợi ý

<details>
<summary>Gợi ý 1: Đọc thông báo lỗi PSS để biết thiếu gì</summary>

Khi pod bị từ chối, PSS liệt kê **từng vi phạm cụ thể**. Ví dụ:

```
violates PodSecurity "restricted:latest":
  allowPrivilegeEscalation != false (...)
  unrestricted capabilities (... must set capabilities.drop=["ALL"])
  runAsNonRoot != true (...)
  seccompProfile (... must set seccompProfile.type to "RuntimeDefault" or "Localhost")
```

Đọc từng dòng và thêm field tương ứng vào pod spec.

</details>

<details>
<summary>Gợi ý 2: Tại sao cần emptyDir khi dùng readOnlyRootFilesystem?</summary>

`readOnlyRootFilesystem: true` làm cho toàn bộ filesystem của container chỉ đọc. Nhưng nginx cần ghi vào `/var/cache/nginx` và `/var/run` khi khởi động.

Giải pháp: mount `emptyDir` volume vào các thư mục cần ghi:

```yaml
volumes:
- name: cache
  emptyDir: {}
containers:
- volumeMounts:
  - name: cache
    mountPath: /var/cache/nginx
```

`emptyDir` là volume tạm thời — được tạo khi pod khởi động, bị xóa khi pod bị xóa.

</details>

<details>
<summary>Gợi ý 3: Seccomp RuntimeDefault làm gì?</summary>

`RuntimeDefault` là Seccomp profile mặc định của container runtime (containerd/CRI-O). Profile này:
- Cho phép ~300 syscall thông thường (read, write, open, connect...)
- Chặn ~100 syscall nguy hiểm (reboot, kexec_load, mount...)

Bạn không cần tạo profile thủ công — chỉ cần khai báo `type: RuntimeDefault` và runtime tự áp dụng.

</details>

<details>
<summary>Gợi ý 4: Khi nào cần add lại capability?</summary>

Sau khi `drop: [ALL]`, nếu ứng dụng cần capability cụ thể, thêm lại bằng `add`:

```yaml
capabilities:
  drop: [ALL]
  add: [NET_BIND_SERVICE]  # Cho phép bind port < 1024 (ví dụ: port 80)
```

**Lưu ý:** PSS restricted **không cho phép** add bất kỳ capability nào ngoài `NET_BIND_SERVICE`. Nếu ứng dụng cần capability khác, phải dùng PSS `baseline` hoặc `privileged`.

</details>

<details>
<summary>Gợi ý 5: Cú pháp kubectl label để sửa/xóa</summary>

```bash
# Sửa label (thêm --overwrite)
kubectl label namespace pss-lab \
  pod-security.kubernetes.io/enforce=baseline \
  --overwrite

# Xóa label (thêm dấu - sau tên label)
kubectl label namespace pss-lab \
  pod-security.kubernetes.io/enforce-

# Kiểm tra
kubectl get namespace pss-lab --show-labels
```

</details>

---

## Giải pháp mẫu

<details>
<summary>Xem giải pháp đầy đủ (chỉ mở sau khi đã thử)</summary>

Xem file [solution/solution.md](solution/solution.md) để có lệnh đầy đủ và giải thích chi tiết.

</details>

---

## Giải thích

### Tại sao PSS restricted yêu cầu cả 4 trường?

Mỗi yêu cầu ngăn chặn một vector tấn công khác nhau:

| Yêu cầu | Ngăn chặn gì |
|---------|-------------|
| `runAsNonRoot: true` | Container chạy với UID 0 có thể escape ra host với quyền root |
| `allowPrivilegeEscalation: false` | Ngăn process con có thêm quyền qua setuid/setgid binary |
| `capabilities.drop: [ALL]` | Ngăn lạm dụng Linux capabilities để tấn công kernel/network |
| `seccompProfile: RuntimeDefault` | Ngăn gọi syscall nguy hiểm có thể khai thác lỗ hổng kernel |

### Linux Capabilities — tại sao drop ALL?

Container mặc định có ~14 capabilities. Một số nguy hiểm:
- `CAP_NET_RAW`: Tạo raw socket → sniff network traffic
- `CAP_SYS_ADMIN`: Gần như toàn quyền → mount filesystem, thay đổi kernel params
- `CAP_CHOWN`: Thay đổi chủ sở hữu file → chiếm quyền file nhạy cảm

`drop: [ALL]` loại bỏ tất cả, sau đó chỉ thêm lại những gì thực sự cần. Đây là nguyên tắc **least privilege** ở tầng kernel.

### Seccomp — tại sao cần?

Container chia sẻ kernel với host. Không có Seccomp, container có thể gọi bất kỳ syscall nào — kể cả `reboot`, `kexec_load`, `ptrace`... Nếu có lỗ hổng kernel, kẻ tấn công có thể escape container.

`RuntimeDefault` chặn ~100 syscall nguy hiểm nhất mà không ảnh hưởng đến ứng dụng thông thường.

### PSS vs PodSecurityPolicy

PodSecurityPolicy (PSP) đã bị deprecated từ v1.21 và xóa hoàn toàn từ v1.25. PSS là sự thay thế chính thức, đơn giản hơn và được tích hợp sẵn.

---

## Tham khảo

- [Kubernetes Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [Pod Security Admission](https://kubernetes.io/docs/concepts/security/pod-security-admission/)
- [Linux Capabilities man page](https://man7.org/linux/man-pages/man7/capabilities.7.html)
- [Kubernetes Seccomp Documentation](https://kubernetes.io/docs/tutorials/security/seccomp/)
- [CKS Exam Curriculum – Cluster Setup](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/)
