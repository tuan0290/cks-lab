# Giải pháp – Lab 5.2 Static Analysis

## Bước 1: Xem manifest có vấn đề

```bash
cat /tmp/insecure-manifest.yaml
```

Output:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: insecure-pod
  namespace: static-lab
spec:
  hostPID: true          # VẤN ĐỀ: chia sẻ PID namespace với host
  containers:
  - name: app
    image: nginx:1.25-alpine
    securityContext:
      privileged: true   # VẤN ĐỀ: container có toàn quyền truy cập host
```

## Bước 2: Phân tích bằng kubesec

```bash
kubesec scan /tmp/insecure-manifest.yaml
```

Output mẫu:
```json
[
  {
    "object": "Pod/insecure-pod.static-lab",
    "valid": true,
    "fileName": "/tmp/insecure-manifest.yaml",
    "message": "Failed with a score of -30 points",
    "score": -30,
    "scoring": {
      "critical": [
        {
          "id": "Privileged",
          "selector": "containers[] .securityContext .privileged == true",
          "reason": "Privileged containers can allow almost completely unrestricted host access",
          "points": -30
        }
      ],
      "advise": [
        {
          "id": "CapDropAny",
          "selector": "containers[] .securityContext .capabilities .drop | length > 0",
          "reason": "Reducing kernel capabilities available to a container limits its attack surface",
          "points": 1
        }
      ]
    }
  }
]
```

## Bước 3: Phân tích bằng trivy config (thay thế)

```bash
trivy config /tmp/insecure-manifest.yaml
```

Output mẫu:
```
/tmp/insecure-manifest.yaml (kubernetes)

Tests: 10 (SUCCESSES: 7, FAILURES: 3, EXCEPTIONS: 0)
Failures: 3 (HIGH: 2, CRITICAL: 1)

CRITICAL: Container 'app' of Pod 'insecure-pod' should set 'securityContext.privileged' to false
HIGH: Pod 'insecure-pod' should not run with 'hostPID'
```

## Bước 4: Tạo manifest đã sửa

```bash
cat > /tmp/fixed-manifest.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
  namespace: static-lab
  labels:
    app: secure-app
spec:
  hostPID: false
  containers:
  - name: app
    image: nginx:1.25-alpine
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      runAsNonRoot: true
      runAsUser: 1000
      capabilities:
        drop:
        - ALL
    ports:
    - containerPort: 80
EOF
```

## Bước 5: Xác minh manifest đã sửa

```bash
# Kiểm tra bằng kubesec
kubesec scan /tmp/fixed-manifest.yaml

# Hoặc trivy config
trivy config /tmp/fixed-manifest.yaml
```

Output mong đợi (kubesec):
```json
{
  "score": 7,
  "scoring": {
    "critical": [],
    "advise": [...]
  }
}
```

## Bước 6: Chạy verify script

```bash
bash verify.sh
```

Output mong đợi:
```
[PASS] File /tmp/fixed-manifest.yaml tồn tại
[PASS] File /tmp/fixed-manifest.yaml không chứa 'privileged: true'
[PASS] File /tmp/fixed-manifest.yaml không chứa 'hostPID: true'
---
Kết quả: 3/3 tiêu chí đạt
```

## Ví dụ Dockerfile multi-stage build tối giản

```dockerfile
# Stage 1: Build
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o app .

# Stage 2: Runtime (distroless)
FROM gcr.io/distroless/static:nonroot
COPY --from=builder /app/app /app
USER nonroot:nonroot
ENTRYPOINT ["/app"]
```

Lợi ích của multi-stage build:
- Image cuối không chứa build tools (compiler, package manager)
- Kích thước nhỏ hơn → ít attack surface hơn
- Không có shell trong distroless image → khó exploit hơn

## Tóm tắt các vấn đề bảo mật phổ biến trong manifest

| Vấn đề | Rủi ro | Cách sửa |
|--------|--------|----------|
| `privileged: true` | Container có toàn quyền host | Đặt `privileged: false` |
| `hostPID: true` | Thấy tất cả process host | Xóa hoặc đặt `hostPID: false` |
| `hostNetwork: true` | Dùng network interface host | Xóa hoặc đặt `hostNetwork: false` |
| `allowPrivilegeEscalation: true` | Có thể leo thang đặc quyền | Đặt `allowPrivilegeEscalation: false` |
| Không có `runAsNonRoot` | Container chạy với root | Thêm `runAsNonRoot: true` |
| Không drop capabilities | Có nhiều kernel capabilities | Thêm `capabilities.drop: [ALL]` |
