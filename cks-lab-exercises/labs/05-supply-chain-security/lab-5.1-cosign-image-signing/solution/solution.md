# Giải pháp – Lab 5.1 cosign Image Signing

## Bước 1: Tạo cosign key pair

```bash
# Tạo thư mục làm việc
mkdir -p /tmp/cosign-lab
cd /tmp/cosign-lab

# Tạo key pair (nhấn Enter để dùng passphrase trống trong lab)
cosign generate-key-pair
```

Output mong đợi:
```
Enter password for private key:
Enter password for private key again:
Private key written to cosign.key
Public key written to cosign.pub
```

Kết quả:
- `cosign.key`: Private key (giữ bí mật, dùng để ký)
- `cosign.pub`: Public key (chia sẻ công khai, dùng để xác minh)

## Bước 2: Ký image nginx:1.25-alpine

```bash
# Ký image bằng private key (passphrase trống)
COSIGN_PASSWORD="" cosign sign --key /tmp/cosign-lab/cosign.key nginx:1.25-alpine
```

Output mong đợi:
```
Pushing signature to: index.docker.io/library/nginx
```

**Lưu ý:** cosign ký theo image digest (SHA256), không phải tag. Chữ ký được lưu trong registry dưới dạng OCI artifact.

## Bước 3: Xác minh chữ ký

```bash
# Xác minh chữ ký bằng public key
cosign verify --key /tmp/cosign-lab/cosign.pub nginx:1.25-alpine
```

Output mong đợi:
```
Verification for index.docker.io/library/nginx:1.25-alpine --
The following checks were performed on each of these signatures:
  - The cosign claims were validated
  - The signatures were verified against the specified public key

[{"critical":{"identity":{"docker-reference":"index.docker.io/library/nginx"},"image":{"docker-manifest-digest":"sha256:..."},"type":"cosign container image signature"},"optional":null}]
```

## Bước 4: Xem thông tin chi tiết về chữ ký

```bash
# Xem digest reference của chữ ký
cosign triangulate nginx:1.25-alpine

# Xác minh và xuất kết quả dạng JSON
cosign verify --key /tmp/cosign-lab/cosign.pub nginx:1.25-alpine | jq .
```

## Bước 5: Chạy verify script

```bash
bash verify.sh
```

Output mong đợi:
```
[PASS] File cosign.key và cosign.pub tồn tại trong /tmp/cosign-lab/
[PASS] cosign xác minh chữ ký của nginx:1.25-alpine thành công
[PASS] Namespace 'cosign-lab' tồn tại trong cluster
---
Kết quả: 3/3 tiêu chí đạt
```

## Tóm tắt lệnh cosign quan trọng

| Lệnh | Mục đích |
|------|----------|
| `cosign generate-key-pair` | Tạo key pair (cosign.key + cosign.pub) |
| `cosign sign --key cosign.key <image>` | Ký image bằng private key |
| `cosign verify --key cosign.pub <image>` | Xác minh chữ ký bằng public key |
| `cosign triangulate <image>` | Xem vị trí lưu chữ ký trong registry |
| `cosign download signature <image>` | Tải chữ ký về |
| `cosign attest --key cosign.key <image>` | Đính kèm attestation (SBOM, SLSA) |

## Keyless Signing (nâng cao)

Trong môi trường CI/CD, có thể dùng keyless signing với OIDC:

```bash
# Ký không cần key (dùng OIDC identity từ GitHub Actions, GitLab CI, v.v.)
cosign sign --identity-token=$(cat $ACTIONS_ID_TOKEN_REQUEST_TOKEN) <image>

# Xác minh keyless signature
cosign verify --certificate-identity=<email> --certificate-oidc-issuer=<issuer> <image>
```

## Tích hợp với Kubernetes (Sigstore Policy Controller)

```yaml
# ClusterImagePolicy để enforce image signing
apiVersion: policy.sigstore.dev/v1beta1
kind: ClusterImagePolicy
metadata:
  name: require-signed-images
spec:
  images:
  - glob: "**"
  authorities:
  - key:
      data: |
        -----BEGIN PUBLIC KEY-----
        <nội dung cosign.pub>
        -----END PUBLIC KEY-----
```

## Giải thích bảo mật

### Tại sao ký image theo digest?

cosign ký theo image digest (SHA256 hash của manifest), không phải tag. Điều này đảm bảo:
- Tag có thể bị thay đổi (mutable), nhưng digest là bất biến
- Chữ ký gắn với nội dung cụ thể của image, không phải tên tag
- Nếu image bị thay đổi, digest thay đổi → chữ ký không còn hợp lệ

### Lưu trữ private key an toàn

Trong production, không nên lưu private key dưới dạng file. Thay vào đó:
- **KMS**: `cosign sign --key gcpkms://...` hoặc `--key awskms://...`
- **Hardware token**: `cosign sign --key pkcs11://...`
- **Keyless**: Dùng OIDC identity trong CI/CD pipeline
