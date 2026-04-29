# Lab 6.3 – Immutable Containers

**Domain:** Monitoring, Logging and Runtime Security (20%)
**Thời gian ước tính:** 15 phút
**Độ khó:** Cơ bản

---

## Mục tiêu

- Hiểu khái niệm immutable container và tại sao nó quan trọng
- Cấu hình pod với `readOnlyRootFilesystem: true`
- Mount `emptyDir` volumes cho các thư mục cần ghi (`/tmp`, `/var/run`)
- Xác minh container không thể ghi vào filesystem gốc

---

## Lý thuyết

### Immutable Infrastructure là gì?

**Immutable Infrastructure** là nguyên tắc: sau khi deploy, không sửa đổi trực tiếp — thay vào đó, tạo mới và thay thế. Áp dụng cho container: container không nên ghi vào filesystem của nó sau khi khởi động.

**Tại sao immutable container quan trọng?**

Nếu container có thể ghi vào filesystem, kẻ tấn công sau khi xâm nhập có thể:
- Cài backdoor hoặc malware vào `/usr/bin/`
- Sửa đổi binary của ứng dụng
- Ghi script để duy trì persistence
- Thay đổi cấu hình để leo thang đặc quyền

### readOnlyRootFilesystem

`readOnlyRootFilesystem: true` mount root filesystem của container ở chế độ **read-only**:

```yaml
containers:
- name: app
  securityContext:
    readOnlyRootFilesystem: true  # Root filesystem chỉ đọc
```

Khi bật, mọi write operation vào filesystem gốc sẽ bị từ chối:
```
sh: can't create /etc/test: Read-only file system
```

### emptyDir — Cho phép ghi vào thư mục cụ thể

Ứng dụng thường cần ghi vào một số thư mục (`/tmp`, `/var/run`, `/var/cache`). Dùng `emptyDir` volume để mount thư mục có thể ghi riêng biệt:

```yaml
spec:
  containers:
  - name: app
    securityContext:
      readOnlyRootFilesystem: true
    volumeMounts:
    - name: tmp-dir
      mountPath: /tmp        # Cho phép ghi vào /tmp
    - name: run-dir
      mountPath: /var/run    # Cho phép ghi vào /var/run
  volumes:
  - name: tmp-dir
    emptyDir: {}             # Tạo thư mục tạm thời trên node
  - name: run-dir
    emptyDir: {}
```

**emptyDir** là volume tạm thời:
- Được tạo khi pod khởi động
- Bị xóa khi pod bị xóa
- Không persist qua pod restart

### Kiểm tra immutability

```bash
# Thử ghi vào root filesystem (phải fail)
kubectl exec <pod> -- touch /etc/test
# Expected: touch: /etc/test: Read-only file system

# Thử ghi vào emptyDir (phải thành công)
kubectl exec <pod> -- touch /tmp/test
# Expected: thành công

# Kiểm tra securityContext
kubectl get pod <pod> -o jsonpath='{.spec.containers[0].securityContext.readOnlyRootFilesystem}'
# Expected: true
```

### Defense in Depth với immutable containers

```yaml
securityContext:
  readOnlyRootFilesystem: true   # Không ghi vào filesystem
  runAsNonRoot: true             # Không chạy với root
  allowPrivilegeEscalation: false  # Không leo thang đặc quyền
  capabilities:
    drop: [ALL]                  # Drop tất cả capabilities
```

---

## Bối cảnh

Bạn là kỹ sư bảo mật đang review cấu hình pod trong namespace `immutable-lab`. Pod `mutable-app` hiện tại có thể ghi vào bất kỳ đâu trong filesystem — đây là rủi ro bảo mật vì kẻ tấn công có thể ghi malware hoặc thay đổi binary trong container.

Nhiệm vụ của bạn là:
1. Xem pod `mutable-app` hiện tại (không có readOnlyRootFilesystem)
2. Tạo pod `immutable-app` với `readOnlyRootFilesystem: true`
3. Mount `emptyDir` cho `/tmp` và `/var/run` để ứng dụng vẫn hoạt động
4. Xác minh container không thể ghi vào filesystem gốc

---

## Yêu cầu môi trường

- Kubernetes cluster >= 1.29
- `kubectl` đã được cấu hình và kết nối đến cluster

Chạy script khởi tạo môi trường:

```bash
bash setup.sh
```

---

## Các bước thực hiện

### Bước 1: Xem pod mutable-app hiện tại

```bash
# Xem cấu hình pod mutable-app
kubectl get pod mutable-app -n immutable-lab -o yaml

# Thử ghi vào filesystem (sẽ thành công)
kubectl exec mutable-app -n immutable-lab -- sh -c "echo 'test' > /tmp/test.txt && echo 'Ghi thành công'"
kubectl exec mutable-app -n immutable-lab -- sh -c "echo 'test' > /etc/test.txt && echo 'Ghi thành công'" 2>&1 || echo "Bị từ chối"
```

### Bước 2: Tạo pod immutable-app

Tạo file `immutable-pod.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: immutable-app
  namespace: immutable-lab
spec:
  containers:
  - name: app
    image: nginx:1.25-alpine
    securityContext:
      readOnlyRootFilesystem: true
    volumeMounts:
    - name: tmp-dir
      mountPath: /tmp
    - name: run-dir
      mountPath: /var/run
  volumes:
  - name: tmp-dir
    emptyDir: {}
  - name: run-dir
    emptyDir: {}
```

```bash
kubectl apply -f immutable-pod.yaml
```

### Bước 3: Xác minh immutable container

```bash
# Chờ pod sẵn sàng
kubectl wait --for=condition=Ready pod/immutable-app -n immutable-lab --timeout=60s

# Thử ghi vào /tmp (phải thành công vì có emptyDir)
kubectl exec immutable-app -n immutable-lab -- sh -c "echo 'test' > /tmp/test.txt && echo 'Ghi /tmp thành công'"

# Thử ghi vào /etc (phải thất bại vì readOnlyRootFilesystem)
kubectl exec immutable-app -n immutable-lab -- sh -c "echo 'test' > /etc/test.txt" 2>&1 || echo "Bị từ chối - đúng như mong đợi"

# Thử ghi vào /usr (phải thất bại)
kubectl exec immutable-app -n immutable-lab -- sh -c "echo 'test' > /usr/test.txt" 2>&1 || echo "Bị từ chối - đúng như mong đợi"
```

### Bước 4: Chạy verify script

```bash
bash verify.sh
```

---

## Tiêu chí kiểm tra

- [ ] Pod `immutable-app` trong namespace `immutable-lab` có `readOnlyRootFilesystem: true`
- [ ] Pod `immutable-app` có emptyDir volume mounts cho `/tmp` và `/var/run`
- [ ] Pod `immutable-app` đang ở trạng thái `Running`

---

## Gợi ý

<details>
<summary>Gợi ý 1: Tại sao nginx cần /tmp và /var/run?</summary>

nginx cần ghi vào một số thư mục khi khởi động:
- `/tmp`: Thư mục tạm thời
- `/var/run`: PID file và socket file
- `/var/cache/nginx`: Cache (có thể cần thêm)

Nếu không mount emptyDir cho các thư mục này, nginx sẽ fail khi khởi động với lỗi:
```
nginx: [emerg] mkdir() "/var/cache/nginx/client_temp" failed (30: Read-only file system)
```

Giải pháp: Mount emptyDir cho tất cả thư mục nginx cần ghi.

</details>

<details>
<summary>Gợi ý 2: Kiểm tra pod bị crash do readOnlyRootFilesystem</summary>

Nếu pod bị CrashLoopBackOff sau khi thêm readOnlyRootFilesystem:

```bash
# Xem logs để biết lỗi
kubectl logs immutable-app -n immutable-lab

# Xem events
kubectl describe pod immutable-app -n immutable-lab
```

Thêm emptyDir cho thư mục bị lỗi:
```yaml
volumeMounts:
- name: cache-dir
  mountPath: /var/cache/nginx
volumes:
- name: cache-dir
  emptyDir: {}
```

</details>

<details>
<summary>Gợi ý 3: Xác minh readOnlyRootFilesystem bằng kubectl</summary>

```bash
# Kiểm tra securityContext của container
kubectl get pod immutable-app -n immutable-lab \
  -o jsonpath='{.spec.containers[0].securityContext.readOnlyRootFilesystem}'
# Mong đợi: true

# Kiểm tra volume mounts
kubectl get pod immutable-app -n immutable-lab \
  -o jsonpath='{.spec.containers[0].volumeMounts[*].mountPath}'
# Mong đợi: /tmp /var/run (hoặc tương tự)
```

</details>

---

## Giải pháp mẫu

<details>
<summary>Xem giải pháp đầy đủ (chỉ mở sau khi đã thử)</summary>

Xem file [solution/solution.md](solution/solution.md) để có các bước chi tiết và giải thích.

</details>

---

## Giải thích

### Immutable Container là gì?

Immutable container là container không thể ghi vào filesystem của nó sau khi khởi động. Điều này đảm bảo:
- **Tính toàn vẹn**: Binary và config không thể bị thay đổi trong runtime
- **Phát hiện tấn công**: Kẻ tấn công không thể cài malware vào container
- **Reproducibility**: Container luôn chạy đúng như image gốc

### readOnlyRootFilesystem hoạt động như thế nào?

Khi `readOnlyRootFilesystem: true`:
- Kernel mount root filesystem của container ở chế độ read-only
- Bất kỳ write operation nào vào filesystem gốc sẽ bị từ chối với lỗi `Read-only file system`
- emptyDir volumes được mount riêng biệt và vẫn có thể ghi

### emptyDir vs tmpfs

```yaml
# emptyDir thông thường (lưu trên disk của node)
volumes:
- name: tmp-dir
  emptyDir: {}

# emptyDir dùng RAM (tmpfs) - nhanh hơn, không persist khi pod restart
volumes:
- name: tmp-dir
  emptyDir:
    medium: Memory
    sizeLimit: 64Mi
```

### Kết hợp với các security controls khác

Immutable container thường được kết hợp với:
```yaml
securityContext:
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  runAsUser: 1000
  allowPrivilegeEscalation: false
  capabilities:
    drop:
    - ALL
```

---

## Tham khảo

- [Kubernetes Security Context](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/)
- [Immutable Infrastructure](https://www.hashicorp.com/resources/what-is-mutable-vs-immutable-infrastructure)
- [CKS Exam – Monitoring, Logging and Runtime Security](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/)
