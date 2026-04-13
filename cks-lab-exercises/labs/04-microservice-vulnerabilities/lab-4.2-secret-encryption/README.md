# Lab 4.2 – Secret Encryption at Rest

**Domain:** Minimize Microservice Vulnerabilities (20%)
**Thời gian ước tính:** 30 phút
**Độ khó:** Nâng cao

---

## Mục tiêu

- Tạo `EncryptionConfiguration` với provider `aescbc` để mã hóa Secret at-rest trong etcd
- Cấu hình kube-apiserver sử dụng `--encryption-provider-config` flag
- Xác minh Secret được lưu trữ dưới dạng mã hóa trong etcd (không phải plaintext)
- Hiểu sự khác biệt giữa Secret được mã hóa và không mã hóa trong etcd

---

## Bối cảnh

Bạn là kỹ sư bảo mật tại một công ty fintech. Sau khi audit, bạn phát hiện rằng các Kubernetes Secret đang được lưu trữ dưới dạng **base64 plaintext** trong etcd — bất kỳ ai có quyền truy cập etcd đều có thể đọc được nội dung Secret.

Nhiệm vụ của bạn là:
1. Tạo `EncryptionConfiguration` với provider `aescbc` và key ngẫu nhiên
2. Cấu hình kube-apiserver để sử dụng encryption configuration
3. Tạo Secret mới và xác minh nó được mã hóa trong etcd
4. Re-encrypt các Secret cũ bằng cách chạy `kubectl get secrets --all-namespaces -o json | kubectl replace -f -`

---

## Yêu cầu môi trường

- Kubernetes cluster >= 1.29 với quyền truy cập control-plane node
- `kubectl` đã được cấu hình và kết nối đến cluster
- Quyền SSH vào control-plane node để chỉnh sửa kube-apiserver manifest
- `etcdctl` đã được cài đặt (tùy chọn, để xác minh mã hóa trong etcd)

Chạy script khởi tạo môi trường:

```bash
bash setup.sh
```

---

## Các bước thực hiện

### Bước 1: Tạo EncryptionConfiguration

SSH vào control-plane node và tạo thư mục cấu hình:

```bash
sudo mkdir -p /etc/kubernetes/enc
```

Tạo key ngẫu nhiên 32 bytes (base64-encoded):

```bash
head -c 32 /dev/urandom | base64
# Ví dụ output: phedMep7r6xnFkpFqRnSGMkivGnFkpFqRnSGMkivGnF=
```

Tạo file `/etc/kubernetes/enc/encryption-config.yaml`:

```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: <BASE64_ENCODED_32_BYTE_KEY>
      - identity: {}
```

**Lưu ý:** Provider `identity: {}` ở cuối cho phép đọc Secret chưa được mã hóa (cần thiết khi migration).

### Bước 2: Cấu hình kube-apiserver

Chỉnh sửa file manifest của kube-apiserver tại `/etc/kubernetes/manifests/kube-apiserver.yaml`:

Thêm flag vào phần `command`:
```yaml
- --encryption-provider-config=/etc/kubernetes/enc/encryption-config.yaml
```

Thêm volume mount:
```yaml
volumeMounts:
- name: enc
  mountPath: /etc/kubernetes/enc
  readOnly: true
```

Thêm volume:
```yaml
volumes:
- name: enc
  hostPath:
    path: /etc/kubernetes/enc
    type: DirectoryOrCreate
```

### Bước 3: Chờ kube-apiserver khởi động lại

```bash
# Theo dõi kube-apiserver pod
kubectl get pod -n kube-system -l component=kube-apiserver -w

# Hoặc kiểm tra trực tiếp trên node
sudo crictl pods | grep kube-apiserver
```

### Bước 4: Tạo Secret mới và xác minh mã hóa

```bash
# Tạo Secret mới
kubectl create secret generic test-secret \
  --from-literal=password=supersecret123 \
  -n encryption-lab

# Xác minh Secret trong etcd (cần etcdctl)
ETCDCTL_API=3 etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/encryption-lab/test-secret | hexdump -C | head -20
```

Secret được mã hóa sẽ bắt đầu bằng `k8s:enc:aescbc:v1:` thay vì `k8s:enc:identity:v1:`.

### Bước 5: Re-encrypt tất cả Secret hiện có

```bash
kubectl get secrets --all-namespaces -o json | kubectl replace -f -
```

### Bước 6: Chạy verify script

```bash
bash verify.sh
```

---

## Tiêu chí kiểm tra

- [ ] File `EncryptionConfiguration` tồn tại tại `/etc/kubernetes/enc/encryption-config.yaml` hoặc `/tmp/encryption-config.yaml` và chứa provider `aescbc`
- [ ] kube-apiserver manifest tại `/etc/kubernetes/manifests/kube-apiserver.yaml` có flag `--encryption-provider-config`
- [ ] Secret `sample-secret` tồn tại trong namespace `encryption-lab`

---

## Gợi ý

<details>
<summary>Gợi ý 1: Tạo key ngẫu nhiên cho aescbc</summary>

Provider `aescbc` yêu cầu key có độ dài chính xác:
- **16 bytes** → AES-128
- **24 bytes** → AES-192
- **32 bytes** → AES-256 (khuyến nghị)

Tạo key 32 bytes:
```bash
head -c 32 /dev/urandom | base64
```

Key phải được base64-encode trước khi đặt vào EncryptionConfiguration.

</details>

<details>
<summary>Gợi ý 2: Cấu trúc EncryptionConfiguration đầy đủ</summary>

```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
      - configmaps   # Tùy chọn: mã hóa cả ConfigMap
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: <BASE64_32_BYTES>
      - identity: {}  # Fallback để đọc Secret chưa mã hóa
```

**Quan trọng:** Provider đầu tiên trong danh sách được dùng để **mã hóa** khi ghi. Các provider còn lại được thử khi **đọc** (theo thứ tự).

</details>

<details>
<summary>Gợi ý 3: Xác minh mã hóa bằng etcdctl</summary>

```bash
# Lấy raw data từ etcd
ETCDCTL_API=3 etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/<namespace>/<secret-name> | hexdump -C

# Secret CHƯA mã hóa: bắt đầu bằng "k8s\x00\n\x0c" và có thể đọc được
# Secret ĐÃ mã hóa: bắt đầu bằng "k8s:enc:aescbc:v1:" và là binary không đọc được
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

### Tại sao cần mã hóa Secret at-rest?

Mặc định, Kubernetes Secret chỉ được **base64-encode** — không phải mã hóa. Bất kỳ ai có quyền đọc etcd đều có thể decode và xem nội dung Secret. Điều này vi phạm nguyên tắc defense-in-depth.

### Các provider mã hóa trong Kubernetes

| Provider | Mô tả | Khuyến nghị |
|----------|-------|-------------|
| `identity` | Không mã hóa (base64) | Không dùng cho production |
| `aescbc` | AES-CBC với PKCS#7 padding | Tốt, nhưng không authenticated |
| `aesgcm` | AES-GCM với random nonce | Tốt hơn aescbc |
| `secretbox` | XSalsa20 + Poly1305 | Tốt |
| `kms` | Tích hợp với KMS provider (AWS KMS, GCP KMS) | Tốt nhất cho production |

### Lưu ý quan trọng

- Sau khi bật mã hóa, chỉ Secret **mới tạo** mới được mã hóa
- Cần chạy `kubectl get secrets --all-namespaces -o json | kubectl replace -f -` để re-encrypt Secret cũ
- Nếu mất key, **không thể** khôi phục Secret đã mã hóa — backup key cẩn thận!

---

## Tham khảo

- [Kubernetes Encrypting Secret Data at Rest](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/)
- [EncryptionConfiguration API Reference](https://kubernetes.io/docs/reference/config-api/apiserver-encryption.v1/)
- [CKS Exam Curriculum – Minimize Microservice Vulnerabilities](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/)
