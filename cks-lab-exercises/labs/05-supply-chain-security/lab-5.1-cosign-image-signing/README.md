# Lab 5.1 – cosign Image Signing

**Domain:** Supply Chain Security (20%)
**Thời gian ước tính:** 25 phút
**Độ khó:** Trung bình

---

## Mục tiêu

- Sử dụng `cosign` để tạo key pair (public/private key)
- Ký container image `nginx:1.25-alpine` bằng private key
- Xác minh chữ ký image trước khi deploy lên cluster

---

## Bối cảnh

Bạn là kỹ sư bảo mật tại một công ty đang triển khai quy trình bảo mật chuỗi cung ứng phần mềm. Yêu cầu mới từ team security là tất cả container image phải được ký số trước khi deploy lên production để đảm bảo tính toàn vẹn và nguồn gốc của image.

Nhiệm vụ của bạn là:
1. Tạo cosign key pair để ký image
2. Ký image `nginx:1.25-alpine` bằng private key
3. Xác minh chữ ký bằng public key trước khi deploy
4. Hiểu cách tích hợp cosign vào CI/CD pipeline

---

## Yêu cầu môi trường

- Kubernetes cluster >= 1.29
- `kubectl` đã được cấu hình và kết nối đến cluster
- `cosign` đã được cài đặt: [https://docs.sigstore.dev/cosign/system_config/installation/](https://docs.sigstore.dev/cosign/system_config/installation/)
- Kết nối internet để pull image

Chạy script khởi tạo môi trường:

```bash
bash setup.sh
```

---

## Các bước thực hiện

### Bước 1: Tạo cosign key pair

```bash
# Tạo thư mục làm việc
mkdir -p /tmp/cosign-lab
cd /tmp/cosign-lab

# Tạo key pair (sẽ hỏi passphrase — có thể để trống cho lab)
cosign generate-key-pair

# Kết quả: cosign.key (private key) và cosign.pub (public key)
ls -la /tmp/cosign-lab/
```

### Bước 2: Ký image nginx:1.25-alpine

```bash
# Ký image bằng private key
# Lưu ý: cosign ký theo digest, không phải tag
cosign sign --key /tmp/cosign-lab/cosign.key nginx:1.25-alpine

# Nếu dùng passphrase trống:
COSIGN_PASSWORD="" cosign sign --key /tmp/cosign-lab/cosign.key nginx:1.25-alpine
```

### Bước 3: Xác minh chữ ký

```bash
# Xác minh chữ ký bằng public key
cosign verify --key /tmp/cosign-lab/cosign.pub nginx:1.25-alpine

# Xem thông tin chi tiết về chữ ký
cosign verify --key /tmp/cosign-lab/cosign.pub nginx:1.25-alpine | jq .
```

### Bước 4: Kiểm tra chữ ký trong registry

```bash
# Xem tất cả chữ ký của image
cosign triangulate nginx:1.25-alpine

# Xem metadata của chữ ký
cosign verify --key /tmp/cosign-lab/cosign.pub nginx:1.25-alpine --output-file /tmp/cosign-lab/verify-output.json
```

### Bước 5: Chạy verify script

```bash
bash verify.sh
```

---

## Tiêu chí kiểm tra

- [ ] File `cosign.key` và `cosign.pub` tồn tại trong `/tmp/cosign-lab/`
- [ ] `cosign` có thể xác minh chữ ký của image `nginx:1.25-alpine` bằng public key
- [ ] Namespace `cosign-lab` tồn tại trong cluster

---

## Gợi ý

<details>
<summary>Gợi ý 1: Cài đặt cosign</summary>

```bash
# Linux (amd64)
curl -O -L "https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64"
sudo mv cosign-linux-amd64 /usr/local/bin/cosign
sudo chmod +x /usr/local/bin/cosign

# Kiểm tra cài đặt
cosign version
```

</details>

<details>
<summary>Gợi ý 2: Xử lý passphrase khi ký image</summary>

Khi chạy `cosign sign`, nếu bạn đặt passphrase cho private key, cần cung cấp passphrase:

```bash
# Cách 1: Nhập passphrase khi được hỏi
cosign sign --key cosign.key nginx:1.25-alpine

# Cách 2: Dùng biến môi trường (cho automation)
COSIGN_PASSWORD="your-passphrase" cosign sign --key cosign.key nginx:1.25-alpine

# Cách 3: Passphrase trống (chỉ dùng cho lab/dev)
COSIGN_PASSWORD="" cosign sign --key cosign.key nginx:1.25-alpine
```

</details>

<details>
<summary>Gợi ý 3: cosign lưu chữ ký ở đâu?</summary>

cosign lưu chữ ký dưới dạng OCI artifact trong cùng registry với image. Ví dụ:
- Image: `docker.io/library/nginx:1.25-alpine`
- Chữ ký: `docker.io/library/nginx:sha256-<digest>.sig`

Khi verify, cosign tự động tìm chữ ký trong registry dựa trên digest của image.

Để xem digest của image:
```bash
cosign triangulate nginx:1.25-alpine
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

### Tại sao ký image quan trọng?

Trong chuỗi cung ứng phần mềm, image có thể bị giả mạo hoặc thay thế trong quá trình truyền tải. Ký số image đảm bảo:
- **Tính toàn vẹn**: Image không bị thay đổi sau khi ký
- **Xác thực nguồn gốc**: Chỉ người có private key mới có thể ký
- **Không thể phủ nhận**: Có bằng chứng về người đã ký image

### cosign và Sigstore

cosign là một phần của dự án [Sigstore](https://www.sigstore.dev/) — một tiêu chuẩn mở cho việc ký và xác minh phần mềm. Sigstore bao gồm:
- **cosign**: Ký và xác minh container image
- **Fulcio**: Certificate Authority cho code signing
- **Rekor**: Transparency log lưu trữ chữ ký

### Tích hợp với Kubernetes

Để enforce image signing trong Kubernetes, có thể dùng:
- **Sigstore Policy Controller**: Admission webhook kiểm tra chữ ký trước khi deploy
- **Kyverno**: Policy engine hỗ trợ xác minh cosign signature
- **OPA/Gatekeeper**: Kiểm tra image signature qua policy

### Best practices

- Lưu private key trong secret manager (Vault, AWS KMS, GCP KMS)
- Dùng keyless signing với OIDC trong CI/CD pipeline
- Tích hợp verify vào admission webhook để enforce tự động

---

## Tham khảo

- [cosign Documentation](https://docs.sigstore.dev/cosign/overview/)
- [Sigstore Project](https://www.sigstore.dev/)
- [cosign GitHub](https://github.com/sigstore/cosign)
- [CKS Exam – Supply Chain Security](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/)
