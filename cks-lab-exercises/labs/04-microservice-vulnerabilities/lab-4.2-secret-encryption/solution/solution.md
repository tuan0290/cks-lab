# Giải pháp – Lab 4.2 Secret Encryption at Rest

## Bước 1: Tạo thư mục và EncryptionConfiguration

SSH vào control-plane node:

```bash
# Tạo thư mục cấu hình
sudo mkdir -p /etc/kubernetes/enc

# Tạo key ngẫu nhiên 32 bytes
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
echo "Key: $ENCRYPTION_KEY"

# Tạo EncryptionConfiguration
sudo tee /etc/kubernetes/enc/encryption-config.yaml <<EOF
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF

# Bảo vệ file (chỉ root đọc được)
sudo chmod 600 /etc/kubernetes/enc/encryption-config.yaml
sudo chown root:root /etc/kubernetes/enc/encryption-config.yaml
```

**Giải thích EncryptionConfiguration:**
- `resources: [secrets]`: Áp dụng mã hóa cho tất cả Secret
- `aescbc`: Provider mã hóa AES-CBC với PKCS#7 padding
- `key1`: Tên key (dùng để identify khi rotation)
- `secret`: Key 32 bytes được base64-encode
- `identity: {}`: Fallback provider — cho phép đọc Secret chưa mã hóa

## Bước 2: Cấu hình kube-apiserver

Chỉnh sửa manifest:

```bash
sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml
```

Thêm flag vào phần `spec.containers[0].command`:

```yaml
spec:
  containers:
  - command:
    - kube-apiserver
    - --advertise-address=...
    - --encryption-provider-config=/etc/kubernetes/enc/encryption-config.yaml  # THÊM DÒNG NÀY
    ...
```

Thêm volumeMount vào `spec.containers[0].volumeMounts`:

```yaml
    volumeMounts:
    - mountPath: /etc/kubernetes/enc
      name: enc
      readOnly: true
    # ... các volumeMounts khác
```

Thêm volume vào `spec.volumes`:

```yaml
  volumes:
  - hostPath:
      path: /etc/kubernetes/enc
      type: DirectoryOrCreate
    name: enc
  # ... các volumes khác
```

## Bước 3: Chờ kube-apiserver khởi động lại

Sau khi lưu file manifest, kubelet sẽ tự động restart kube-apiserver:

```bash
# Theo dõi pod kube-apiserver
watch kubectl get pod -n kube-system -l component=kube-apiserver

# Hoặc kiểm tra trực tiếp
sudo crictl pods --name kube-apiserver

# Kiểm tra kube-apiserver đang chạy với flag mới
sudo crictl inspect $(sudo crictl pods --name kube-apiserver -q) | grep encryption
```

## Bước 4: Tạo Secret mới và xác minh mã hóa

```bash
# Tạo Secret mới
kubectl create secret generic test-encrypted \
  --from-literal=password=supersecret123 \
  -n encryption-lab

# Xác minh trong etcd — Secret phải bắt đầu bằng "k8s:enc:aescbc:v1:"
ETCDCTL_API=3 etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/encryption-lab/test-encrypted | hexdump -C | head -5
```

Output mong đợi (Secret đã mã hóa):
```
00000000  6b 38 73 3a 65 6e 63 3a  61 65 73 63 62 63 3a 76  |k8s:enc:aescbc:v|
00000010  31 3a 6b 65 79 31 3a ...                           |1:key1:...(binary)|
```

Output nếu CHƯA mã hóa (base64 plaintext):
```
00000000  6b 38 73 00 0a 0c ...                              |k8s.....(readable)|
```

## Bước 5: Re-encrypt tất cả Secret hiện có

```bash
# Re-encrypt tất cả Secret trong cluster
kubectl get secrets --all-namespaces -o json | kubectl replace -f -
```

Lệnh này đọc tất cả Secret và ghi lại — kube-apiserver sẽ mã hóa chúng với provider mới.

## Bước 6: Xác minh Secret cũ đã được re-encrypt

```bash
ETCDCTL_API=3 etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/encryption-lab/sample-secret | hexdump -C | head -5
# Phải bắt đầu bằng "k8s:enc:aescbc:v1:"
```

## Tóm tắt các lệnh quan trọng

| Lệnh | Mục đích |
|------|----------|
| `head -c 32 /dev/urandom \| base64` | Tạo key ngẫu nhiên 32 bytes |
| `kubectl get secrets --all-namespaces -o json \| kubectl replace -f -` | Re-encrypt tất cả Secret |
| `etcdctl get /registry/secrets/<ns>/<name>` | Xem raw data trong etcd |
| `grep encryption-provider-config /etc/kubernetes/manifests/kube-apiserver.yaml` | Kiểm tra flag đã được thêm |

## Key Rotation

Khi cần rotate key:

1. Thêm key mới vào đầu danh sách providers (key mới sẽ được dùng để mã hóa)
2. Giữ key cũ ở vị trí thứ hai (để đọc Secret đã mã hóa bằng key cũ)
3. Restart kube-apiserver
4. Re-encrypt tất cả Secret: `kubectl get secrets --all-namespaces -o json | kubectl replace -f -`
5. Xóa key cũ khỏi danh sách providers
6. Restart kube-apiserver lần nữa

```yaml
# Trong quá trình rotation:
providers:
  - aescbc:
      keys:
        - name: key2        # Key mới — dùng để mã hóa
          secret: <NEW_KEY>
        - name: key1        # Key cũ — chỉ dùng để đọc
          secret: <OLD_KEY>
  - identity: {}
```
