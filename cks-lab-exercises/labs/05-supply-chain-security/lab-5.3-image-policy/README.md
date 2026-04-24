# Lab 5.3 – ImagePolicyWebhook Setup

**Domain:** Supply Chain Security (20%)
**Thời gian ước tính:** 30 phút
**Độ khó:** Nâng cao

---

## Mục tiêu

- Hoàn thiện cấu hình **ImagePolicyWebhook** — built-in admission plugin của Kubernetes
- Cấu hình `admission_config.json` với đúng `allowTTL` và `defaultAllow`
- Cấu hình `kubeconf` trỏ đến external webhook service tại `https://localhost:1234`
- Đăng ký `ImagePolicyWebhook` vào kube-apiserver
- Xác minh tất cả Pod bị từ chối khi external service không reachable

---

## Lý thuyết

### ImagePolicyWebhook là gì?

**ImagePolicyWebhook** là built-in admission plugin của Kubernetes. Khi được bật, mọi request tạo Pod sẽ được gửi đến một external HTTP service để quyết định allow/deny dựa trên image.

```
kubectl run pod --image=nginx
        ↓
API Server → ImagePolicyWebhook → External Service (https://localhost:1234)
                                          ↓
                                   Allow / Deny
```

Khác với OPA/Gatekeeper (cài thêm), ImagePolicyWebhook là tính năng có sẵn trong Kubernetes — không cần cài thêm gì.

### Các file cấu hình

**admission_config.json** — cấu hình plugin:
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

**kubeconf** — cấu hình kết nối đến external service:
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

### Tham số quan trọng

| Tham số | Ý nghĩa |
|---------|---------|
| `allowTTL` | Cache (giây) cho quyết định "allow" từ external service |
| `denyTTL` | Cache (giây) cho quyết định "deny" |
| `defaultAllow: false` | Block tất cả Pod nếu external service không reachable ✅ |
| `defaultAllow: true` | Cho phép tất cả Pod nếu external service không reachable ❌ |

---

## Bối cảnh

Một cấu hình ImagePolicyWebhook đã được thiết lập một nửa trên cluster. Nhiệm vụ của bạn là hoàn thiện nó:

- Thư mục cấu hình tại `/etc/kubernetes/policywebhook`
- `admission_config.json` cần sửa `allowTTL=100` và `defaultAllow=false`
- `kubeconf` cần trỏ đúng đến `https://localhost:1234`
- External service sẽ ở `https://localhost:1234` trong tương lai — hiện chưa tồn tại, nên mọi Pod phải bị từ chối
- Đăng ký đúng admission plugin vào kube-apiserver

---

## Yêu cầu môi trường

- Kubernetes cluster >= 1.29
- Chạy trực tiếp trên **control plane node** (cần truy cập `/etc/kubernetes/manifests/`)
- `kubectl` đã được cấu hình

Chạy script khởi tạo môi trường:

```bash
bash setup.sh
```

Script sẽ tạo sẵn:
- `/etc/kubernetes/policywebhook/admission_config.json` (cần hoàn thiện)
- `/etc/kubernetes/policywebhook/kubeconf`
- `/etc/kubernetes/policywebhook/external-cert.pem`

---

## Các bước thực hiện

### Bước 1: Sửa admission_config.json

```bash
vi /etc/kubernetes/policywebhook/admission_config.json
```

Cần sửa hai giá trị:
- `allowTTL`: đặt thành `100`
- `defaultAllow`: đặt thành `false`

### Bước 2: Kiểm tra kubeconf

```bash
cat /etc/kubernetes/policywebhook/kubeconf
```

Đảm bảo `server:` trỏ đúng đến `https://localhost:1234`.

### Bước 3: Cấu hình kube-apiserver

```bash
vi /etc/kubernetes/manifests/kube-apiserver.yaml
```

Thêm hai flag vào phần `command`:

```yaml
- --enable-admission-plugins=NodeRestriction,ImagePolicyWebhook
- --admission-control-config-file=/etc/kubernetes/policywebhook/admission_config.json
```

### Bước 4: Chờ apiserver restart

```bash
watch crictl ps
```

Chờ container `kube-apiserver` restart và ở trạng thái `Running`.

### Bước 5: Kiểm tra hoạt động

```bash
kubectl run test-pod --image=nginx --restart=Never
```

Output mong đợi:
```
Error from server (Forbidden): pods "test-pod" is forbidden: Post "https://localhost:1234/?timeout=30s": dial tcp 127.0.0.1:1234: connect: connection refused
```

### Bước 6: Chạy verify script

```bash
bash verify.sh
```

---

## Tiêu chí kiểm tra

- [ ] `admission_config.json` có `allowTTL=100`
- [ ] `admission_config.json` có `defaultAllow=false`
- [ ] `kubeconf` trỏ đến `https://localhost:1234`
- [ ] kube-apiserver bật `ImagePolicyWebhook` trong `--enable-admission-plugins`
- [ ] kube-apiserver có `--admission-control-config-file` trỏ đến đúng file
- [ ] Tạo Pod bị từ chối (external service không reachable)

---

## Gợi ý

<details>
<summary>Gợi ý 1: Kiểm tra apiserver đã nhận config chưa</summary>

```bash
# Xem log của apiserver
crictl logs $(crictl ps | grep kube-apiserver | awk '{print $1}')

# Hoặc kiểm tra process
ps aux | grep kube-apiserver | grep ImagePolicyWebhook
```

</details>

<details>
<summary>Gợi ý 2: apiserver không restart sau khi sửa manifest</summary>

kubelet tự động watch thư mục `/etc/kubernetes/manifests/`. Nếu apiserver không restart:

```bash
# Kiểm tra kubelet đang chạy
systemctl status kubelet

# Xem log kubelet
journalctl -u kubelet -n 50
```

Nếu manifest có lỗi YAML syntax, apiserver sẽ không restart được.

</details>

<details>
<summary>Gợi ý 3: Lỗi "connection refused" là đúng hay sai?</summary>

`connection refused` khi tạo Pod là **kết quả đúng** trong lab này. Nó có nghĩa là:
- ImagePolicyWebhook đang hoạt động
- Nó cố gắng gọi external service tại `https://localhost:1234`
- Service chưa tồn tại → connection refused
- `defaultAllow=false` → Pod bị block

Nếu Pod được tạo thành công, có nghĩa là `defaultAllow=true` hoặc plugin chưa được bật.

</details>

---

## Giải pháp mẫu

<details>
<summary>Xem giải pháp đầy đủ (chỉ mở sau khi đã thử)</summary>

Xem file [solution/solution.md](solution/solution.md)

</details>

---

## Tham khảo

- [Kubernetes ImagePolicyWebhook](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#imagepolicywebhook)
- [Admission Controllers Reference](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/)
- [CKS Exam – Supply Chain Security](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/)
