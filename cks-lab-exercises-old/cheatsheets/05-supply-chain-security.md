# Cheatsheet 05 – Supply Chain Security (20%)

## cosign (Image Signing & Verification)

### Generate key pair
```bash
cosign generate-key-pair

# Output: cosign.key (private), cosign.pub (public)
# Store cosign.key securely — never commit to git
```

### Sign an image
```bash
# Sign with local key
cosign sign --key cosign.key <registry>/<image>:<tag>

# Sign with digest (recommended — immutable reference)
cosign sign --key cosign.key <registry>/<image>@sha256:<digest>

# Example
cosign sign --key cosign.key docker.io/myrepo/myapp:v1.0
```

### Verify a signature
```bash
# Verify with public key
cosign verify --key cosign.pub <registry>/<image>:<tag>

# Verify and output JSON
cosign verify --key cosign.pub <registry>/<image>:<tag> | jq .

# Verify with output format
cosign verify --key cosign.pub \
  --output-file verify-result.json \
  <registry>/<image>:<tag>
```

### Attach SBOM / attestation
```bash
# Generate SBOM with syft
syft <image> -o spdx-json > sbom.spdx.json

# Attach SBOM as attestation
cosign attest --key cosign.key \
  --predicate sbom.spdx.json \
  --type spdxjson \
  <registry>/<image>:<tag>

# Verify attestation
cosign verify-attestation --key cosign.pub \
  --type spdxjson \
  <registry>/<image>:<tag>
```

---

## kubesec (Static Analysis)

```bash
# Scan a manifest file
kubesec scan pod.yaml

# Scan from stdin
cat pod.yaml | kubesec scan /dev/stdin

# Scan via HTTP API
curl -sSX POST --data-binary @pod.yaml https://v2.kubesec.io/scan

# Scan and check score
kubesec scan pod.yaml | jq '.[0].score'

# Get critical issues
kubesec scan pod.yaml | jq '.[0].scoring.critical'
```

### kubesec score interpretation
| Score | Meaning |
|-------|---------|
| < 0 | Critical security issues |
| 0 | Baseline (no bonus, no penalty) |
| > 0 | Security best practices applied |

---

## trivy config (Manifest Scanning)

```bash
# Scan a Kubernetes manifest
trivy config pod.yaml

# Scan a directory of manifests
trivy config ./manifests/

# Scan with severity filter
trivy config --severity HIGH,CRITICAL pod.yaml

# Scan Dockerfile
trivy config Dockerfile

# Scan Helm chart
trivy config ./my-chart/

# Exit with error if issues found
trivy config --exit-code 1 --severity CRITICAL pod.yaml

# Output as JSON
trivy config --format json --output results.json pod.yaml
```

---

## OPA / Gatekeeper

### ConstraintTemplate skeleton
```yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequiredlabels
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredLabels
      validation:
        openAPIV3Schema:
          type: object
          properties:
            labels:
              type: array
              items:
                type: string
  targets:
  - target: admission.k8s.gatekeeper.sh
    rego: |
      package k8srequiredlabels

      violation[{"msg": msg}] {
        provided := {label | input.review.object.metadata.labels[label]}
        required := {label | label := input.parameters.labels[_]}
        missing := required - provided
        count(missing) > 0
        msg := sprintf("Missing required labels: %v", [missing])
      }
```

### Constraint (instance of ConstraintTemplate)
```yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: require-app-label
spec:
  match:
    kinds:
    - apiGroups: [""]
      kinds: ["Pod"]
    namespaces:
    - production
  parameters:
    labels:
    - app
    - owner
```

### Gatekeeper commands
```bash
kubectl get constrainttemplate
kubectl get constraints
kubectl describe constraint <name>

# Check violations
kubectl get constraint <name> -o jsonpath='{.status.violations}'
```

### ImagePolicyWebhook config (alternative to Gatekeeper)
```yaml
# /etc/kubernetes/admission/image-policy-config.yaml
imagePolicy:
  kubeConfigFile: /etc/kubernetes/admission/kubeconfig.yaml
  allowTTL: 50
  denyTTL: 50
  retryBackoff: 500
  defaultAllow: false   # Deny if webhook unavailable
```

---

## Dockerfile – Multi-Stage Build

```dockerfile
# Stage 1: Build
FROM golang:1.21-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o myapp .

# Stage 2: Runtime (minimal image)
FROM gcr.io/distroless/static:nonroot

# Copy only the binary
COPY --from=builder /app/myapp /myapp

# Run as non-root (distroless nonroot = UID 65532)
USER nonroot:nonroot

EXPOSE 8080
ENTRYPOINT ["/myapp"]
```

### Dockerfile security best practices
```dockerfile
# Use specific digest instead of tag
FROM nginx@sha256:abc123...

# Create non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

# Minimize layers and clean up
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
  && rm -rf /var/lib/apt/lists/*

# Don't copy secrets into image
# Use build args for non-sensitive config only
ARG APP_VERSION
ENV APP_VERSION=${APP_VERSION}

# Set read-only filesystem hint
VOLUME ["/tmp"]
```

---

## Quick Reference

| Task | Command |
|------|---------|
| Generate cosign keys | `cosign generate-key-pair` |
| Sign image | `cosign sign --key cosign.key <image>` |
| Verify signature | `cosign verify --key cosign.pub <image>` |
| kubesec scan | `kubesec scan manifest.yaml` |
| trivy config scan | `trivy config --severity HIGH,CRITICAL manifest.yaml` |
| List ConstraintTemplates | `kubectl get constrainttemplate` |
| List Constraints | `kubectl get constraints` |
| Check Gatekeeper violations | `kubectl get constraint <name> -o jsonpath='{.status.violations}'` |
| Build multi-stage image | `docker build -t myapp:v1 .` |

---

## syft (SBOM Generation)

```bash
# Tạo SBOM ở định dạng SPDX-JSON
syft <image> -o spdx-json=sbom.json

# Ví dụ
syft nginx:1.25-alpine -o spdx-json=/tmp/nginx-sbom.json

# Tạo SBOM ở định dạng CycloneDX
syft <image> -o cyclonedx-json=sbom.json

# Xem tóm tắt packages
syft <image>

# Quét SBOM bằng trivy
trivy sbom /tmp/nginx-sbom.json
trivy sbom /tmp/nginx-sbom.json --severity CRITICAL,HIGH
```

---

## kube-linter (Kubernetes Manifest Linting)

### Cài đặt

```bash
# Linux (amd64)
curl -sSL https://github.com/stackrox/kube-linter/releases/latest/download/kube-linter-linux.tar.gz | tar xz
sudo mv kube-linter /usr/local/bin/

# macOS
brew install kube-linter

# Kiểm tra
kube-linter version
```

### Sử dụng

```bash
# Lint một file manifest
kube-linter lint deployment.yaml

# Lint một thư mục
kube-linter lint ./k8s/

# Lint với config file
kube-linter lint --config .kube-linter.yaml deployment.yaml

# Output JSON
kube-linter lint deployment.yaml --format json | jq .

# Xem tất cả checks có sẵn
kube-linter checks list
```

### Cấu hình .kube-linter.yaml

```yaml
# .kube-linter.yaml
checks:
  addAllBuiltIn: true    # Dùng tất cả checks mặc định

  # Bỏ qua checks không phù hợp
  exclude:
    - "latest-tag"       # Cho phép image tag latest (dev only)

  # Hoặc chỉ chạy checks cụ thể
  # include:
  #   - "run-as-non-root"
  #   - "read-only-root-filesystem"
  #   - "unset-cpu-requirements"
  #   - "unset-memory-requirements"
```

### Các checks quan trọng

| Check | Mô tả | Fix |
|-------|-------|-----|
| `run-as-non-root` | Container chạy với UID 0 | `runAsNonRoot: true` |
| `read-only-root-filesystem` | Filesystem root có thể ghi | `readOnlyRootFilesystem: true` |
| `privileged-container` | Container chạy privileged | `privileged: false` |
| `unset-cpu-requirements` | Không có CPU limits | Thêm `resources.limits.cpu` |
| `unset-memory-requirements` | Không có memory limits | Thêm `resources.limits.memory` |
| `latest-tag` | Image dùng tag `latest` | Dùng tag cụ thể |

### So sánh KubeLinter vs kubesec vs trivy config

| | KubeLinter | kubesec | trivy config |
|---|---|---|---|
| Output | Danh sách lỗi + remediation | JSON score | Severity levels |
| Checks | 30+ K8s-specific | ~20 Pod security | Hàng trăm (K8s+Terraform+Docker) |
| Tùy chỉnh | `.kube-linter.yaml` | Hạn chế | `.trivyignore` |
| Khi nào dùng | Lint K8s manifest | Cần điểm số | Scan toàn bộ IaC |

### Quick Reference – kube-linter

| Task | Command |
|------|---------|
| Lint file | `kube-linter lint manifest.yaml` |
| Lint directory | `kube-linter lint ./k8s/` |
| Lint with config | `kube-linter lint --config .kube-linter.yaml manifest.yaml` |
| List all checks | `kube-linter checks list` |
| Output JSON | `kube-linter lint manifest.yaml --format json` |
| Generate SBOM | `syft <image> -o spdx-json=sbom.json` |
| Scan SBOM | `trivy sbom sbom.json --severity CRITICAL,HIGH` |
