# Giải pháp – Lab 5.3 ImagePolicyWebhook Setup

## Bước 1: Chạy setup.sh

```bash
bash setup.sh
```

Script tạo sẵn:
- `/etc/kubernetes/policywebhook/admission_config.json` (cần sửa)
- `/etc/kubernetes/policywebhook/kubeconf` (cần kiểm tra)
- `/etc/kubernetes/policywebhook/external-cert.pem`

---

## Bước 2: Sửa admission_config.json

```bash
vi /etc/kubernetes/policywebhook/admission_config.json
```

Nội dung đúng:

```json
{
  "apiVersion": "apiserver.config.k8s.io/v1",
  "kind": "AdmissionConfiguration",
  "plugins": [
    {
      "name": "ImagePolicyWebhook",
      "configuration": {
        "imagePolicy": {
          "kubeConfigFile": "/etc/kubernetes/policywebhook/kubeconf",
          "allowTTL": 100,
          "denyTTL": 50,
          "retryBackoff": 500,
          "defaultAllow": false
        }
      }
    }
  ]
}
```

Hai điểm cần sửa so với file mẫu:
- `allowTTL`: `50` → `100`
- `defaultAllow`: `true` → `false`

---

## Bước 3: Kiểm tra kubeconf

```bash
cat /etc/kubernetes/policywebhook/kubeconf
```

Nội dung đúng:

```yaml
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority: /etc/kubernetes/policywebhook/external-cert.pem
    server: https://localhost:1234
  name: image-checker
users:
- name: api-server
  user: {}
contexts:
- context:
    cluster: image-checker
    user: api-server
  name: image-checker
current-context: image-checker
```

Đảm bảo `server: https://localhost:1234` đúng.

---

## Bước 4: Cấu hình kube-apiserver

```bash
vi /etc/kubernetes/manifests/kube-apiserver.yaml
```

Thêm hai dòng vào phần `command`:

```yaml
spec:
  containers:
  - command:
    - kube-apiserver
    - --enable-admission-plugins=NodeRestriction,ImagePolicyWebhook
    - --admission-control-config-file=/etc/kubernetes/policywebhook/admission_config.json
    # ... các flag khác
```

Lưu ý: nếu `--enable-admission-plugins` đã có sẵn, chỉ cần thêm `,ImagePolicyWebhook` vào cuối.

---

## Bước 5: Chờ apiserver restart

Sau khi sửa manifest, kubelet sẽ tự động restart apiserver container:

```bash
watch crictl ps
```

Chờ đến khi thấy container `kube-apiserver` ở trạng thái `Running` với AGE mới.

---

## Bước 6: Kiểm tra hoạt động

```bash
kubectl run test-pod --image=nginx --restart=Never
```

Output mong đợi (external service chưa tồn tại → bị từ chối):

```
Error from server (Forbidden): pods "test-pod" is forbidden: Post "https://localhost:1234/?timeout=30s": dial tcp 127.0.0.1:1234: connect: connection refused
```

Đây là kết quả đúng — `defaultAllow=false` nên khi không liên lạc được external service, Pod bị block.

---

## Bước 7: Chạy verify script

```bash
bash verify.sh
```

Output mong đợi:

```
[PASS] admission_config.json có allowTTL=100
[PASS] admission_config.json có defaultAllow=false
[PASS] kubeconf trỏ đến https://localhost:1234
[PASS] kube-apiserver có --enable-admission-plugins chứa ImagePolicyWebhook
[PASS] kube-apiserver có --admission-control-config-file được cấu hình
[PASS] Pod bị từ chối — ImagePolicyWebhook đang hoạt động đúng
---
Kết quả: 6/6 tiêu chí đạt
```

---

## Giải thích các tham số

| Tham số | Ý nghĩa |
|---------|---------|
| `allowTTL` | Cache thời gian (giây) cho quyết định "allow" từ external service |
| `denyTTL` | Cache thời gian (giây) cho quyết định "deny" |
| `retryBackoff` | Thời gian chờ (ms) trước khi retry khi external service lỗi |
| `defaultAllow: false` | Block tất cả Pod nếu external service không reachable |
| `defaultAllow: true` | Cho phép tất cả Pod nếu external service không reachable (không an toàn) |
