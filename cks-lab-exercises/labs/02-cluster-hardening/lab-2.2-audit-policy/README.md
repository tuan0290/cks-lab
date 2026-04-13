# Lab 2.2 – Audit Policy

**Domain:** Cluster Hardening (15%)
**Thời gian ước tính:** 25 phút
**Độ khó:** Nâng cao

---

## Mục tiêu

- Hiểu cấu trúc và các mức độ (level) của Kubernetes Audit Policy
- Tạo Audit Policy ghi lại thao tác trên Secret ở mức `RequestResponse`
- Cấu hình các thao tác khác ở mức `Metadata`
- Cấu hình log backend ghi audit log ra file trên kube-apiserver
- Xác minh audit log được ghi đúng định dạng

---

## Bối cảnh

Bạn là kỹ sư bảo mật tại một công ty fintech. Sau một sự cố bảo mật, ban lãnh đạo yêu cầu bật audit logging trên Kubernetes cluster để theo dõi mọi thao tác liên quan đến Secret (credentials, API keys, certificates). Đặc biệt, cần ghi lại đầy đủ nội dung request và response khi có ai đó đọc hoặc sửa Secret, trong khi các thao tác khác chỉ cần ghi metadata để tiết kiệm dung lượng.

Nhiệm vụ của bạn là:
1. Tạo Audit Policy file với các rule phù hợp
2. Cấu hình kube-apiserver để sử dụng policy file và ghi log ra file
3. Xác minh audit log được tạo ra và chứa đúng thông tin

---

## Yêu cầu môi trường

- Kubernetes cluster >= 1.29 (có quyền truy cập control-plane node)
- `kubectl` đã được cấu hình và kết nối đến cluster
- Quyền SSH vào control-plane node (để chỉnh sửa kube-apiserver manifest)
- Quyền đọc/ghi file trên control-plane node tại `/etc/kubernetes/`

Chạy script khởi tạo môi trường:

```bash
bash setup.sh
```

---

## Các bước thực hiện

### Bước 1: Hiểu cấu trúc Audit Policy

Kubernetes Audit Policy định nghĩa các rule theo thứ tự ưu tiên. Mỗi request được so khớp với rule đầu tiên phù hợp. Các mức độ ghi log:

| Level | Ghi gì |
|-------|--------|
| `None` | Không ghi |
| `Metadata` | Chỉ ghi metadata (user, timestamp, resource, verb) — không ghi body |
| `Request` | Ghi metadata + request body |
| `RequestResponse` | Ghi metadata + request body + response body |

### Bước 2: Tạo thư mục và Audit Policy file

Trên control-plane node, tạo thư mục chứa policy:

```bash
sudo mkdir -p /etc/kubernetes/audit
```

Tạo file `/etc/kubernetes/audit/audit-policy.yaml`:

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  # Ghi lại đầy đủ request và response cho Secret
  - level: RequestResponse
    resources:
    - group: ""
      resources: ["secrets"]

  # Bỏ qua các request từ system components không cần thiết
  - level: None
    users: ["system:kube-proxy"]
    verbs: ["watch"]
    resources:
    - group: ""
      resources: ["endpoints", "services", "services/status"]

  - level: None
    users: ["system:unsecured"]
    namespaces: ["kube-system"]
    verbs: ["get"]
    resources:
    - group: ""
      resources: ["configmaps"]

  - level: None
    users: ["kubelet"]
    verbs: ["get"]
    resources:
    - group: ""
      resources: ["nodes", "nodes/status"]

  - level: None
    userGroups: ["system:nodes"]
    verbs: ["get"]
    resources:
    - group: ""
      resources: ["nodes", "nodes/status"]

  # Ghi Metadata cho tất cả thao tác còn lại
  - level: Metadata
    omitStages:
    - "RequestReceived"
```

### Bước 3: Cấu hình kube-apiserver

Chỉnh sửa file manifest của kube-apiserver tại `/etc/kubernetes/manifests/kube-apiserver.yaml`.

Thêm các flag sau vào phần `command` của container:

```yaml
- --audit-policy-file=/etc/kubernetes/audit/audit-policy.yaml
- --audit-log-path=/var/log/kubernetes/audit/audit.log
- --audit-log-maxage=30
- --audit-log-maxbackup=10
- --audit-log-maxsize=100
```

Thêm volume mount để kube-apiserver có thể đọc policy file và ghi log:

```yaml
# Trong spec.containers[0].volumeMounts:
- mountPath: /etc/kubernetes/audit
  name: audit-policy
  readOnly: true
- mountPath: /var/log/kubernetes/audit
  name: audit-log

# Trong spec.volumes:
- hostPath:
    path: /etc/kubernetes/audit
    type: DirectoryOrCreate
  name: audit-policy
- hostPath:
    path: /var/log/kubernetes/audit
    type: DirectoryOrCreate
  name: audit-log
```

### Bước 4: Tạo thư mục log và khởi động lại kube-apiserver

```bash
# Tạo thư mục log
sudo mkdir -p /var/log/kubernetes/audit

# kube-apiserver là static pod — tự động restart khi manifest thay đổi
# Chờ kube-apiserver khởi động lại (khoảng 30-60 giây)
kubectl wait --for=condition=Ready pod -l component=kube-apiserver \
  -n kube-system --timeout=120s
```

### Bước 5: Kiểm tra audit log

```bash
# Thực hiện thao tác trên Secret để tạo audit event
kubectl get secret -n audit-lab
kubectl describe secret sample-secret -n audit-lab

# Xem audit log
sudo tail -f /var/log/kubernetes/audit/audit.log | python3 -m json.tool | head -50

# Tìm các event liên quan đến Secret
sudo grep '"resource":"secrets"' /var/log/kubernetes/audit/audit.log | \
  python3 -m json.tool | grep -E '"level"|"verb"|"resource"'
```

---

## Tiêu chí kiểm tra

- [ ] File audit policy tồn tại tại `/etc/kubernetes/audit/audit-policy.yaml` (hoặc `/tmp/audit-policy.yaml`) và chứa rule `RequestResponse` cho secrets
- [ ] File audit policy chứa rule `Metadata` cho các thao tác còn lại
- [ ] Audit log được ghi ra file (hoặc policy file được cấu hình đúng cú pháp YAML)

---

## Gợi ý

<details>
<summary>Gợi ý 1: Thứ tự rule trong Audit Policy rất quan trọng</summary>

Kubernetes áp dụng rule đầu tiên khớp với request. Vì vậy:
- Đặt rule cụ thể (như Secret) **trước** rule tổng quát (Metadata cho tất cả)
- Đặt rule `None` cho system components **trước** rule Metadata để tránh log noise
- Rule cuối cùng thường là `level: Metadata` để bắt tất cả còn lại

```yaml
rules:
  - level: RequestResponse   # 1. Secret — cụ thể nhất
    resources:
    - group: ""
      resources: ["secrets"]
  - level: None              # 2. Loại trừ system noise
    users: ["system:kube-proxy"]
    ...
  - level: Metadata          # 3. Bắt tất cả còn lại — tổng quát nhất
```

</details>

<details>
<summary>Gợi ý 2: Cách chỉnh sửa kube-apiserver manifest an toàn</summary>

kube-apiserver là static pod, được quản lý bởi kubelet. Khi bạn chỉnh sửa file manifest, kubelet tự động restart pod:

```bash
# Backup trước khi chỉnh sửa
sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml \
  /etc/kubernetes/kube-apiserver.yaml.bak

# Chỉnh sửa
sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml

# Theo dõi quá trình restart
watch kubectl get pods -n kube-system
```

Nếu kube-apiserver không khởi động được (do lỗi cú pháp), kiểm tra:
```bash
sudo crictl ps -a | grep apiserver
sudo crictl logs <container-id>
```

</details>

<details>
<summary>Gợi ý 3: Các flag audit logging của kube-apiserver</summary>

| Flag | Mô tả | Giá trị khuyến nghị |
|------|-------|---------------------|
| `--audit-policy-file` | Đường dẫn đến policy file | `/etc/kubernetes/audit/audit-policy.yaml` |
| `--audit-log-path` | Đường dẫn file log | `/var/log/kubernetes/audit/audit.log` |
| `--audit-log-maxage` | Số ngày giữ log cũ | `30` |
| `--audit-log-maxbackup` | Số file backup tối đa | `10` |
| `--audit-log-maxsize` | Kích thước tối đa mỗi file (MB) | `100` |

Nếu `--audit-log-path` là `-`, log được ghi ra stdout.

</details>

---

## Giải pháp mẫu

<details>
<summary>Xem giải pháp đầy đủ (chỉ mở sau khi đã thử)</summary>

Xem file [solution/solution.md](solution/solution.md) để có các bước chi tiết và giải thích.

</details>

---

## Giải thích

### Tại sao cần Audit Logging?

Audit logging là lớp bảo vệ quan trọng trong Kubernetes, cho phép:
- **Phát hiện xâm nhập**: Ai đã đọc Secret chứa credentials?
- **Điều tra sự cố**: Thao tác nào đã xảy ra trước khi cluster bị compromise?
- **Tuân thủ compliance**: PCI-DSS, SOC2, ISO 27001 đều yêu cầu audit trail
- **Forensics**: Tái hiện chuỗi sự kiện sau một cuộc tấn công

### Tại sao Secret cần mức RequestResponse?

Mức `RequestResponse` ghi lại cả nội dung request và response, bao gồm **giá trị thực của Secret** (dạng base64). Điều này cho phép:
- Biết chính xác dữ liệu nào đã bị đọc
- Phát hiện nếu Secret bị sửa đổi (so sánh giá trị trước/sau)
- Cung cấp bằng chứng đầy đủ cho điều tra pháp lý

**Lưu ý bảo mật:** File audit log chứa giá trị Secret — cần bảo vệ file log với quyền truy cập hạn chế.

### Tại sao các thao tác khác chỉ cần Metadata?

Mức `Metadata` tiết kiệm dung lượng đáng kể trong khi vẫn cung cấp đủ thông tin để:
- Biết ai đã làm gì, khi nào, trên resource nào
- Phát hiện pattern bất thường (nhiều request từ một user)
- Đáp ứng yêu cầu audit cơ bản

Ghi `RequestResponse` cho tất cả sẽ tạo ra lượng log khổng lồ và ảnh hưởng hiệu năng.

### Audit Policy trong CKS Exam

Trong kỳ thi CKS, bạn thường được yêu cầu:
1. Tạo policy file với các rule cụ thể
2. Thêm flags vào kube-apiserver manifest
3. Xác minh log được tạo ra

Thời gian thực hiện trên exam: khoảng 10-15 phút nếu đã thực hành.

---

## Tham khảo

- [Kubernetes Auditing Documentation](https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/)
- [Audit Policy Reference](https://kubernetes.io/docs/reference/config-api/apiserver-audit.v1/)
- [kube-apiserver Audit Flags](https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/)
- [CKS Exam Curriculum – Cluster Hardening](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/)
