# Lab 4.3 – Secret Volume Mount

**Domain:** Minimize Microservice Vulnerabilities (20%)
**Thời gian ước tính:** 15 phút
**Độ khó:** Cơ bản

---

## Mục tiêu

- Hiểu sự khác biệt giữa mount Secret qua environment variable và volume mount
- Sửa pod đang dùng Secret qua env var thành mount Secret dưới dạng volume
- Cấu hình `defaultMode: 0400` để giới hạn quyền đọc file Secret
- Xác minh Secret được mount đúng cách và không bị lộ qua `kubectl describe pod`

---

## Lý thuyết

### Kubernetes Secret là gì?

**Kubernetes Secret** là object lưu trữ dữ liệu nhạy cảm (password, API key, certificate...) dưới dạng base64-encoded. Secret tách biệt dữ liệu nhạy cảm khỏi pod spec — không cần hardcode trong image hay manifest.

### 2 cách mount Secret vào pod

**Cách 1: Environment Variable (KHÔNG khuyến nghị)**
```yaml
env:
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: my-secret
      key: password
```

**Cách 2: Volume Mount (KHUYẾN NGHỊ)**
```yaml
volumeMounts:
- name: secret-vol
  mountPath: /etc/secrets
  readOnly: true
volumes:
- name: secret-vol
  secret:
    secretName: my-secret
    defaultMode: 0400  # Chỉ owner đọc được
```

### Tại sao env var không an toàn?

| Vấn đề | Env Var | Volume Mount |
|--------|---------|--------------|
| Hiển thị trong `kubectl describe pod` | Tên env var lộ | Không lộ |
| Kế thừa bởi child process | ✅ Có | ❌ Không |
| Ghi vào crash dump/log | Có thể | Không |
| Rotation không restart pod | ❌ Không | ✅ Có (tự động) |
| Kiểm soát permission | ❌ Không | ✅ Có (defaultMode) |

### defaultMode là gì?

`defaultMode` là octal permission cho file Secret được mount:

```yaml
volumes:
- name: secret-vol
  secret:
    secretName: my-secret
    defaultMode: 0400  # r-------- (chỉ owner đọc)
```

| Giá trị | Permission | Ý nghĩa |
|---------|-----------|---------|
| `0400` | `r--------` | Chỉ owner đọc (khuyến nghị) |
| `0440` | `r--r-----` | Owner và group đọc |
| `0444` | `r--r--r--` | Tất cả đọc (không khuyến nghị) |

### Secret rotation

Khi Secret được mount dưới dạng volume, Kubernetes **tự động cập nhật** file trong container khi Secret thay đổi (sau ~1-2 phút). Không cần restart pod — đây là ưu điểm lớn so với env var.

---

## Bối cảnh

Bạn là kỹ sư bảo mật đang review cấu hình của một ứng dụng trong namespace `secret-lab`. Bạn phát hiện pod `insecure-app` đang mount Secret `app-credentials` qua **environment variable** — cách này không an toàn vì:

1. Giá trị env var hiển thị rõ ràng trong `kubectl describe pod`
2. Env var được kế thừa bởi tất cả child process
3. Env var thường bị ghi vào log khi ứng dụng crash

Nhiệm vụ của bạn là tạo pod `secure-app` sử dụng cùng Secret nhưng mount dưới dạng **volume** với `defaultMode: 0400`.

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

### Bước 1: Kiểm tra pod hiện tại (cách sai)

```bash
# Xem pod đang dùng env var
kubectl get pod insecure-app -n secret-lab -o yaml

# Xem Secret bị lộ qua describe
kubectl describe pod insecure-app -n secret-lab
# Chú ý phần "Environment:" — Secret value hiển thị rõ ràng!
```

### Bước 2: Xem Secret hiện có

```bash
kubectl get secret app-credentials -n secret-lab -o yaml
kubectl describe secret app-credentials -n secret-lab
```

### Bước 3: Tạo pod secure-app với Secret volume mount

Tạo pod `secure-app` trong namespace `secret-lab` với Secret được mount dưới dạng volume:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: secure-app
  namespace: secret-lab
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    volumeMounts:
    - name: credentials
      mountPath: /etc/secrets
      readOnly: true
  volumes:
  - name: credentials
    secret:
      secretName: app-credentials
      defaultMode: 0400
EOF
```

### Bước 4: Xác minh Secret được mount đúng cách

```bash
# Kiểm tra pod đang Running
kubectl get pod secure-app -n secret-lab

# Xem file Secret trong container
kubectl exec secure-app -n secret-lab -- ls -la /etc/secrets/
# Kết quả mong đợi: file có permission 0400 (r--------)

# Đọc nội dung Secret
kubectl exec secure-app -n secret-lab -- cat /etc/secrets/username
kubectl exec secure-app -n secret-lab -- cat /etc/secrets/password

# Xác minh Secret KHÔNG hiển thị trong describe
kubectl describe pod secure-app -n secret-lab
# Phần "Environment:" phải trống hoặc không có Secret value
```

### Bước 5: Chạy verify script

```bash
bash verify.sh
```

---

## Tiêu chí kiểm tra

- [ ] Pod `secure-app` trong namespace `secret-lab` mount Secret `app-credentials` dưới dạng volume (không phải env var)
- [ ] Volume mount có `defaultMode: 0400` (chỉ owner được đọc)
- [ ] Pod `secure-app` đang ở trạng thái `Running`

---

## Gợi ý

<details>
<summary>Gợi ý 1: Cú pháp Secret volume mount</summary>

```yaml
spec:
  containers:
  - name: app
    volumeMounts:
    - name: credentials      # Phải khớp với tên volume bên dưới
      mountPath: /etc/secrets  # Đường dẫn trong container
      readOnly: true           # Khuyến nghị: mount read-only
  volumes:
  - name: credentials
    secret:
      secretName: app-credentials  # Tên Secret trong Kubernetes
      defaultMode: 0400            # Octal: chỉ owner đọc được (r--------)
```

**Lưu ý về defaultMode:**
- `0400` = `r--------` (chỉ owner đọc)
- `0440` = `r--r-----` (owner và group đọc)
- `0444` = `r--r--r--` (tất cả đọc)
- Giá trị phải là **octal** (bắt đầu bằng 0)

</details>

<details>
<summary>Gợi ý 2: Tại sao env var không an toàn?</summary>

Khi dùng env var:
```yaml
env:
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: app-credentials
      key: password
```

Vấn đề:
1. `kubectl describe pod` hiển thị tên env var (dù không hiển thị value, nhưng vẫn lộ thông tin)
2. Env var được truyền vào tất cả child process — nếu ứng dụng spawn subprocess, subprocess cũng có Secret
3. Nhiều framework logging tự động log tất cả env var khi startup
4. Env var không thể rotate mà không restart pod

Volume mount an toàn hơn vì:
- File có thể được rotate mà không cần restart pod (Kubernetes tự động cập nhật)
- Có thể kiểm soát permission chặt chẽ với `defaultMode`
- Không bị kế thừa bởi child process

</details>

<details>
<summary>Gợi ý 3: Mount từng key cụ thể từ Secret</summary>

Thay vì mount toàn bộ Secret, có thể mount từng key:

```yaml
volumes:
- name: credentials
  secret:
    secretName: app-credentials
    items:
    - key: password        # Chỉ mount key "password"
      path: db-password    # Tên file trong container
      mode: 0400
    - key: username
      path: db-username
      mode: 0400
```

Kết quả: `/etc/secrets/db-password` và `/etc/secrets/db-username`

</details>

---

## Giải pháp mẫu

<details>
<summary>Xem giải pháp đầy đủ (chỉ mở sau khi đã thử)</summary>

Xem file [solution/solution.md](solution/solution.md) để có các bước chi tiết và giải thích.

</details>

---

## Giải thích

### So sánh env var vs volume mount

| Tiêu chí | Env Var | Volume Mount |
|----------|---------|--------------|
| Hiển thị trong `describe pod` | Tên env var lộ | Không lộ |
| Kế thừa bởi child process | Có | Không |
| Rotation không restart | Không | Có (tự động) |
| Kiểm soát permission | Không | Có (defaultMode) |
| Dễ đọc trong container | Dễ | Cần đọc file |
| Khuyến nghị CKS | Không | Có |

### defaultMode: 0400 là gì?

`0400` là octal permission:
- `4` = read (đọc)
- `0` = không có quyền gì
- `0` = không có quyền gì

Tương đương với `r--------` trong `ls -la`:
- Owner: read only
- Group: không có quyền
- Others: không có quyền

Điều này đảm bảo chỉ process chạy với UID của container mới đọc được file Secret.

### Kubernetes Secret rotation

Khi Secret được mount dưới dạng volume, Kubernetes tự động cập nhật file trong container khi Secret thay đổi (sau khoảng 1-2 phút). Điều này cho phép rotation Secret mà không cần restart pod.

---

## Tham khảo

- [Kubernetes Secrets Documentation](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Using Secrets as Files](https://kubernetes.io/docs/concepts/configuration/secret/#using-secrets-as-files-from-a-pod)
- [CKS Exam Curriculum – Minimize Microservice Vulnerabilities](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/)
