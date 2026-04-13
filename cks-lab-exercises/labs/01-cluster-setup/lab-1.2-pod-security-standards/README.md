# Lab 1.2 – Pod Security Standards (PSS)

**Domain:** Cluster Setup (15%)
**Thời gian ước tính:** 20 phút
**Độ khó:** Trung bình

---

## Mục tiêu

- Cấu hình namespace `pss-lab` với Pod Security Standards (PSS) ở mức `restricted`
- Hiểu sự khác biệt giữa ba mức PSS: `privileged`, `baseline`, `restricted`
- Xác nhận rằng pod vi phạm (chạy với `privileged: true`) bị từ chối bởi admission controller
- So sánh hành vi giữa namespace `restricted` và namespace `baseline`

---

## Bối cảnh

Bạn là kỹ sư bảo mật tại một công ty thương mại điện tử. Sau một cuộc kiểm tra bảo mật, nhóm bảo mật yêu cầu tất cả workload production phải tuân thủ tiêu chuẩn bảo mật pod ở mức `restricted` — mức cao nhất trong Pod Security Standards của Kubernetes.

Nhiệm vụ của bạn là:
1. Gắn nhãn PSS `restricted` lên namespace `pss-lab`
2. Thử deploy một pod vi phạm (chạy với `privileged: true`) và xác nhận bị từ chối
3. Hiểu tại sao PSS quan trọng trong môi trường production

---

## Yêu cầu môi trường

- Kubernetes cluster >= 1.29 (PSS được GA từ Kubernetes 1.25)
- `kubectl` đã được cấu hình và kết nối đến cluster
- Quyền tạo namespace và gắn label

Chạy script khởi tạo môi trường:

```bash
bash setup.sh
```

---

## Các bước thực hiện

### Bước 1: Kiểm tra môi trường

```bash
# Xác nhận namespace đã được tạo
kubectl get namespaces | grep -E 'pss-lab|pss-baseline'

# Xem labels hiện tại của namespace pss-lab
kubectl get namespace pss-lab --show-labels
```

### Bước 2: Gắn nhãn PSS restricted lên namespace `pss-lab`

Sử dụng `kubectl label` để thêm nhãn Pod Security Standards:

```bash
kubectl label namespace pss-lab \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=latest
```

Xác nhận nhãn đã được gắn:

```bash
kubectl get namespace pss-lab --show-labels
```

### Bước 3: Thử deploy pod hợp lệ trong `pss-lab`

Tạo pod tuân thủ PSS restricted:

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
      type: RuntimeDefault
  containers:
  - name: nginx
    image: nginx:1.25-alpine
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop: ["ALL"]
EOF
```

### Bước 4: Thử deploy pod vi phạm trong `pss-lab`

Tạo pod với `privileged: true` — đây là vi phạm PSS restricted:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: privileged-pod
  namespace: pss-lab
spec:
  containers:
  - name: nginx
    image: nginx:1.25-alpine
    securityContext:
      privileged: true
EOF
```

Pod này **phải bị từ chối** với thông báo lỗi từ admission controller.

### Bước 5: So sánh với namespace `pss-baseline`

Namespace `pss-baseline` đã được cấu hình với mức `baseline`. Thử deploy pod privileged vào đó:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: privileged-pod
  namespace: pss-baseline
spec:
  containers:
  - name: nginx
    image: nginx:1.25-alpine
    securityContext:
      privileged: true
EOF
```

Quan sát sự khác biệt — pod privileged bị từ chối ở cả `baseline` lẫn `restricted`, nhưng vì lý do khác nhau.

### Bước 6: Xác minh kết quả

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
<summary>Gợi ý 1: Cú pháp kubectl label để gắn PSS</summary>

Dùng `kubectl label namespace` với các key PSS chuẩn:

```bash
kubectl label namespace <tên-namespace> \
  pod-security.kubernetes.io/enforce=<level> \
  pod-security.kubernetes.io/enforce-version=<version>
```

Trong đó `<level>` là một trong: `privileged`, `baseline`, `restricted`.
`<version>` thường dùng `latest` hoặc phiên bản cụ thể như `v1.29`.

</details>

<details>
<summary>Gợi ý 2: Ba chế độ PSS (enforce, audit, warn)</summary>

PSS có ba chế độ hoạt động độc lập:

- `enforce`: Từ chối pod vi phạm (admission controller block)
- `audit`: Ghi log vi phạm vào audit log nhưng vẫn cho phép pod chạy
- `warn`: Hiển thị cảnh báo cho người dùng nhưng vẫn cho phép pod chạy

Trong bài lab này, chúng ta dùng `enforce` để pod vi phạm thực sự bị từ chối.

</details>

<details>
<summary>Gợi ý 3: Kiểm tra label namespace</summary>

```bash
# Xem tất cả labels
kubectl get namespace pss-lab -o yaml | grep -A 10 labels

# Hoặc dùng --show-labels
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

### Pod Security Standards là gì?

Pod Security Standards (PSS) là cơ chế built-in của Kubernetes (từ v1.25 GA) thay thế cho PodSecurityPolicy (đã bị xóa từ v1.25). PSS định nghĩa ba mức bảo mật:

| Mức | Mô tả | Dùng khi nào |
|-----|-------|--------------|
| `privileged` | Không hạn chế gì | Workload hệ thống, CNI plugins |
| `baseline` | Ngăn các escalation rõ ràng | Workload thông thường |
| `restricted` | Tuân thủ best practices bảo mật | Workload production nhạy cảm |

### Tại sao PSS restricted quan trọng?

Mức `restricted` yêu cầu pod phải:
- Không chạy với `privileged: true`
- Không cho phép privilege escalation (`allowPrivilegeEscalation: false`)
- Chạy với user non-root (`runAsNonRoot: true`)
- Drop tất cả Linux capabilities (`capabilities.drop: [ALL]`)
- Sử dụng Seccomp profile (`RuntimeDefault` hoặc `Localhost`)

Những yêu cầu này ngăn chặn nhiều vector tấn công phổ biến trong container.

### PSS vs PodSecurityPolicy

PodSecurityPolicy (PSP) đã bị deprecated từ v1.21 và xóa hoàn toàn từ v1.25. PSS là sự thay thế chính thức, đơn giản hơn và được tích hợp sẵn mà không cần cài thêm gì.

---

## Tham khảo

- [Kubernetes Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [Pod Security Admission](https://kubernetes.io/docs/concepts/security/pod-security-admission/)
- [Migrate from PodSecurityPolicy to PSS](https://kubernetes.io/docs/tasks/configure-pod-container/migrate-from-psp/)
- [CKS Exam Curriculum – Cluster Setup](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/)
