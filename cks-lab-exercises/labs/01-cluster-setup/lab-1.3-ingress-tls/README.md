# Lab 1.3 – Ingress TLS

**Domain:** Cluster Setup (15%)
**Thời gian ước tính:** 25 phút
**Độ khó:** Trung bình

---

## Mục tiêu

- Tạo self-signed TLS certificate bằng `openssl`
- Tạo Kubernetes Secret kiểu `kubernetes.io/tls` từ certificate và private key
- Cấu hình Ingress resource với TLS termination
- Xác minh kết nối HTTPS hoạt động đúng qua Ingress

---

## Bối cảnh

Bạn là kỹ sư bảo mật tại một công ty fintech. Nhóm DevOps vừa triển khai một ứng dụng web trong namespace `tls-lab`, nhưng hiện tại chỉ có HTTP. Yêu cầu bảo mật nội bộ bắt buộc tất cả traffic phải được mã hóa qua HTTPS.

Nhiệm vụ của bạn là:
1. Tạo self-signed TLS certificate cho domain `app.tls-lab.local`
2. Lưu certificate vào Kubernetes Secret kiểu `kubernetes.io/tls`
3. Cấu hình Ingress với TLS termination sử dụng Secret đó
4. Xác minh Ingress có cấu hình TLS đúng

---

## Yêu cầu môi trường

- Kubernetes cluster >= 1.29
- `kubectl` đã được cấu hình và kết nối đến cluster
- `openssl` đã được cài đặt
- Ingress controller đã được cài đặt trong cluster (ví dụ: nginx-ingress)

Chạy script khởi tạo môi trường:

```bash
bash setup.sh
```

---

## Các bước thực hiện

### Bước 1: Kiểm tra môi trường

```bash
# Xác nhận namespace và deployment đã được tạo
kubectl get all -n tls-lab

# Kiểm tra openssl có sẵn
openssl version
```

### Bước 2: Tạo self-signed TLS certificate

Dùng `openssl` để tạo private key và self-signed certificate:

```bash
# Tạo thư mục làm việc
mkdir -p /tmp/tls-lab

# Tạo private key và certificate trong một lệnh
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /tmp/tls-lab/tls.key \
  -out /tmp/tls-lab/tls.crt \
  -subj "/CN=app.tls-lab.local/O=tls-lab"
```

Xác nhận file đã được tạo:

```bash
ls -la /tmp/tls-lab/
openssl x509 -in /tmp/tls-lab/tls.crt -text -noout | grep -E "Subject:|Not After"
```

### Bước 3: Tạo Kubernetes Secret kiểu TLS

Dùng `kubectl create secret tls` để tạo Secret từ certificate:

```bash
kubectl create secret tls tls-secret \
  --cert=/tmp/tls-lab/tls.crt \
  --key=/tmp/tls-lab/tls.key \
  -n tls-lab
```

Xác nhận Secret đã được tạo với đúng type:

```bash
kubectl get secret tls-secret -n tls-lab
kubectl describe secret tls-secret -n tls-lab
```

Output mong đợi: `Type: kubernetes.io/tls`

### Bước 4: Tạo Ingress với TLS

Tạo Ingress resource có cấu hình TLS:

```bash
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tls-ingress
  namespace: tls-lab
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  tls:
  - hosts:
    - app.tls-lab.local
    secretName: tls-secret
  rules:
  - host: app.tls-lab.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx-service
            port:
              number: 80
EOF
```

### Bước 5: Xác minh cấu hình

```bash
# Kiểm tra Ingress đã được tạo
kubectl get ingress tls-ingress -n tls-lab

# Xem chi tiết cấu hình TLS
kubectl describe ingress tls-ingress -n tls-lab

# Xem spec.tls trong YAML
kubectl get ingress tls-ingress -n tls-lab -o jsonpath='{.spec.tls}' | python3 -m json.tool
```

### Bước 6: Kiểm tra kết quả

```bash
bash verify.sh
```

---

## Tiêu chí kiểm tra

- [ ] Secret `tls-secret` tồn tại trong namespace `tls-lab` với type `kubernetes.io/tls`
- [ ] Ingress `tls-ingress` tồn tại trong namespace `tls-lab`
- [ ] Ingress `tls-ingress` có cấu hình TLS (spec.tls không rỗng)

---

## Gợi ý

<details>
<summary>Gợi ý 1: Cú pháp openssl tạo self-signed cert</summary>

Lệnh `openssl req -x509` tạo self-signed certificate trực tiếp (không cần CA):

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key \
  -out tls.crt \
  -subj "/CN=<domain>/O=<org>"
```

- `-x509`: tạo self-signed certificate (không phải CSR)
- `-nodes`: không mã hóa private key bằng passphrase
- `-days 365`: certificate có hiệu lực 365 ngày
- `-newkey rsa:2048`: tạo RSA key 2048-bit mới
- `-subj`: thông tin subject, `/CN=` là Common Name (domain)

</details>

<details>
<summary>Gợi ý 2: Tạo TLS Secret bằng kubectl</summary>

Có hai cách tạo TLS Secret:

**Cách 1 – kubectl create secret tls (khuyến nghị):**
```bash
kubectl create secret tls <tên-secret> \
  --cert=<đường-dẫn-tls.crt> \
  --key=<đường-dẫn-tls.key> \
  -n <namespace>
```

**Cách 2 – kubectl create secret generic với base64:**
```bash
kubectl create secret generic <tên-secret> \
  --from-file=tls.crt=<đường-dẫn-tls.crt> \
  --from-file=tls.key=<đường-dẫn-tls.key> \
  --type=kubernetes.io/tls \
  -n <namespace>
```

Cách 1 tự động set `type: kubernetes.io/tls` và validate format.

</details>

<details>
<summary>Gợi ý 3: Cấu trúc spec.tls trong Ingress</summary>

Phần `spec.tls` trong Ingress có cấu trúc:

```yaml
spec:
  tls:
  - hosts:
    - <domain>          # phải khớp với host trong spec.rules
    secretName: <tên-secret>   # Secret kiểu kubernetes.io/tls
  rules:
  - host: <domain>
    http:
      paths: [...]
```

Lưu ý: `hosts` trong `spec.tls` phải khớp với `host` trong `spec.rules` để TLS hoạt động đúng.

</details>

---

## Giải pháp mẫu

<details>
<summary>Xem giải pháp đầy đủ (chỉ mở sau khi đã thử)</summary>

Xem file [solution/solution.md](solution/solution.md) để có lệnh đầy đủ và giải thích chi tiết.

</details>

---

## Giải thích

### TLS Termination tại Ingress là gì?

Khi Ingress controller nhận HTTPS request từ client, nó:
1. **Giải mã (decrypt)** traffic TLS bằng private key trong Secret
2. **Chuyển tiếp** request dưới dạng HTTP thuần đến backend Service
3. Backend Service và Pod không cần biết về TLS

Đây gọi là **TLS termination** — TLS kết thúc tại Ingress, không phải tại Pod.

```
Client --[HTTPS]--> Ingress Controller --[HTTP]--> Service --> Pod
                    (TLS terminated here)
```

### Tại sao dùng Secret kiểu kubernetes.io/tls?

Kubernetes có type Secret đặc biệt cho TLS:
- `tls.crt`: certificate (public key + metadata)
- `tls.key`: private key

Type `kubernetes.io/tls` giúp Kubernetes và Ingress controller nhận biết đây là TLS credential và xử lý đúng cách.

### Self-signed vs CA-signed Certificate

| Loại | Dùng khi nào | Trình duyệt tin tưởng? |
|------|-------------|----------------------|
| Self-signed | Lab, internal testing | Không (cần thêm vào trust store) |
| CA-signed (Let's Encrypt, v.v.) | Production | Có |
| Internal CA | Enterprise internal | Có (nếu CA được deploy) |

Trong kỳ thi CKS, self-signed certificate là đủ để kiểm tra cấu hình TLS.

### Ingress TLS và CKS Exam

Trong kỳ thi CKS, bạn có thể được yêu cầu:
- Tạo TLS Secret từ cert/key cho sẵn
- Cấu hình Ingress với TLS section
- Xác minh Ingress đang dùng đúng Secret

Lệnh quan trọng cần nhớ:
```bash
kubectl create secret tls <name> --cert=tls.crt --key=tls.key -n <ns>
```

---

## Tham khảo

- [Kubernetes Ingress TLS](https://kubernetes.io/docs/concepts/services-networking/ingress/#tls)
- [TLS Secrets](https://kubernetes.io/docs/concepts/configuration/secret/#tls-secrets)
- [NGINX Ingress Controller – TLS/HTTPS](https://kubernetes.github.io/ingress-nginx/user-guide/tls/)
- [openssl req man page](https://www.openssl.org/docs/man1.1.1/man1/req.html)
- [CKS Exam Curriculum – Cluster Setup](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/)
