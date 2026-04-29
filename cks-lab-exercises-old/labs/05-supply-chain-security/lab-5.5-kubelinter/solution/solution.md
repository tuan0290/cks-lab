# Giải pháp – Lab 5.5 KubeLinter Static Analysis

## Bước 1: Cài đặt kube-linter

```bash
# Linux (amd64)
curl -sSL https://github.com/stackrox/kube-linter/releases/latest/download/kube-linter-linux.tar.gz | tar xz
sudo mv kube-linter /usr/local/bin/

# Kiểm tra
kube-linter version
```

## Bước 2: Xem manifest có vấn đề

```bash
cat /tmp/kubelinter-lab/insecure-deployment.yaml
```

Output:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: insecure-app
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: insecure-app
  template:
    metadata:
      labels:
        app: insecure-app
    spec:
      containers:
      - name: app
        image: nginx:latest          # VẤN ĐỀ 1: tag latest
        securityContext:
          privileged: true           # VẤN ĐỀ 2: privileged container
          runAsUser: 0               # VẤN ĐỀ 3: chạy với UID 0 (root)
        # VẤN ĐỀ 4: không có runAsNonRoot
        # VẤN ĐỀ 5: không có readOnlyRootFilesystem
        # VẤN ĐỀ 6: không có resources.limits
```

## Bước 3: Chạy kube-linter lint

```bash
kube-linter lint /tmp/kubelinter-lab/insecure-deployment.yaml
```

Output mẫu:
```
/tmp/kubelinter-lab/insecure-deployment.yaml: (object: default/insecure-app apps/v1, Kind=Deployment)
  container "app" does not have a read-only root file system
  (check: read-only-root-filesystem, remediation: Set readOnlyRootFilesystem to true in your container's securityContext.)

/tmp/kubelinter-lab/insecure-deployment.yaml: (object: default/insecure-app apps/v1, Kind=Deployment)
  container "app" is not set to runAsNonRoot
  (check: run-as-non-root, remediation: Set runAsNonRoot to true in your pod or container's securityContext.)

/tmp/kubelinter-lab/insecure-deployment.yaml: (object: default/insecure-app apps/v1, Kind=Deployment)
  container "app" has no resource limits
  (check: unset-cpu-requirements, remediation: Set CPU requests and limits for your container.)

/tmp/kubelinter-lab/insecure-deployment.yaml: (object: default/insecure-app apps/v1, Kind=Deployment)
  container "app" is privileged
  (check: privileged-container, remediation: Do not run your container as privileged.)

Error: found 4 lint errors
```

## Bước 4: Tạo fixed-deployment.yaml

```bash
cat > /tmp/kubelinter-lab/fixed-deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-app
  namespace: default
  labels:
    app: secure-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: secure-app
  template:
    metadata:
      labels:
        app: secure-app
    spec:
      containers:
      - name: app
        # FIX 1: dùng tag cụ thể thay vì latest
        image: nginx:1.25-alpine
        securityContext:
          # FIX 2: không chạy privileged
          privileged: false
          # FIX 3: không cho phép leo thang đặc quyền
          allowPrivilegeEscalation: false
          # FIX 4: chạy với UID khác 0 (non-root)
          runAsNonRoot: true
          runAsUser: 1000
          # FIX 5: filesystem root chỉ đọc
          readOnlyRootFilesystem: true
          # FIX 6: drop tất cả Linux capabilities
          capabilities:
            drop:
            - ALL
        # FIX 7: thêm resource limits
        resources:
          limits:
            cpu: "500m"
            memory: "128Mi"
          requests:
            cpu: "100m"
            memory: "64Mi"
EOF
```

## Bước 5: Verify manifest đã sửa

```bash
kube-linter lint /tmp/kubelinter-lab/fixed-deployment.yaml
```

Output mong đợi:
```
No lint errors found!
```

## Bước 6: Chạy verify script

```bash
bash verify.sh
```

Output mong đợi:
```
[PASS] kube-linter đã được cài đặt
[PASS] File /tmp/kubelinter-lab/fixed-deployment.yaml tồn tại
[PASS] kube-linter lint không báo lỗi 'run-as-non-root'
[PASS] kube-linter lint không báo lỗi 'read-only-root-filesystem'
---
Kết quả: 4/4 tiêu chí đạt
```

---

## Giải thích từng fix

### Fix 1: Image tag cụ thể thay vì `latest`

```yaml
# Trước (không an toàn)
image: nginx:latest

# Sau (an toàn)
image: nginx:1.25-alpine
```

**Lý do:** Tag `latest` không xác định version cụ thể — mỗi lần pull có thể nhận image khác nhau, gây ra hành vi không nhất quán và khó audit. Dùng tag cụ thể đảm bảo reproducibility và traceability.

### Fix 2 & 3: Tắt privileged và allowPrivilegeEscalation

```yaml
securityContext:
  privileged: false
  allowPrivilegeEscalation: false
```

**Lý do:** Container privileged có gần như toàn quyền truy cập host kernel — có thể mount filesystem host, thay đổi kernel parameters, truy cập tất cả devices. `allowPrivilegeEscalation: false` ngăn process con có nhiều quyền hơn process cha (ví dụ: qua setuid binary).

### Fix 4: runAsNonRoot và runAsUser

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
```

**Lý do:** Chạy container với UID 0 (root) nghĩa là nếu attacker escape container, họ có quyền root trên host. `runAsNonRoot: true` đảm bảo container không thể start nếu image yêu cầu root. `runAsUser: 1000` chỉ định UID cụ thể.

### Fix 5: readOnlyRootFilesystem

```yaml
securityContext:
  readOnlyRootFilesystem: true
```

**Lý do:** Filesystem root chỉ đọc ngăn attacker ghi malware hoặc sửa đổi binary trong container. Nếu ứng dụng cần ghi file, dùng `emptyDir` volume cho các thư mục cụ thể.

### Fix 6: Drop capabilities

```yaml
securityContext:
  capabilities:
    drop:
    - ALL
```

**Lý do:** Linux capabilities chia nhỏ quyền root thành các đặc quyền riêng biệt. Drop ALL loại bỏ tất cả capabilities không cần thiết, giảm attack surface. Nếu ứng dụng cần capability cụ thể (ví dụ: `NET_BIND_SERVICE` để bind port < 1024), thêm lại bằng `add`.

### Fix 7: Resource limits

```yaml
resources:
  limits:
    cpu: "500m"
    memory: "128Mi"
  requests:
    cpu: "100m"
    memory: "64Mi"
```

**Lý do:** Không có resource limits, một container có thể chiếm toàn bộ CPU/memory của node, gây DoS cho các workload khác. Limits đảm bảo fair sharing và ngăn resource exhaustion attacks.

---

## So sánh KubeLinter vs kubesec vs trivy config

| Tiêu chí | KubeLinter | kubesec | trivy config |
|----------|-----------|---------|--------------|
| **Tập trung** | Kubernetes best practices | Điểm bảo mật Pod/Deployment | Misconfiguration đa nền tảng |
| **Output** | Danh sách lỗi + remediation | JSON score (-30 đến +7) | Severity levels (CRITICAL/HIGH) |
| **Số checks** | 30+ checks K8s-specific | ~20 checks Pod security | Hàng trăm checks (K8s, Terraform, Dockerfile) |
| **Tùy chỉnh** | `.kube-linter.yaml` | Hạn chế | `.trivyignore`, policy files |
| **Exit code** | 1 nếu có lỗi | 0 (cần parse JSON) | `--exit-code 1` |
| **Khi nào dùng** | Lint manifest K8s thuần túy | Cần điểm số để so sánh | Scan toàn bộ IaC |

### Ví dụ so sánh output

**KubeLinter:**
```
container "app" is not set to runAsNonRoot
(check: run-as-non-root, remediation: Set runAsNonRoot to true...)
```

**kubesec:**
```json
{
  "score": -30,
  "scoring": {
    "critical": [{"id": "Privileged", "points": -30}]
  }
}
```

**trivy config:**
```
CRITICAL: Container 'app' should set 'securityContext.privileged' to false
HIGH: Container 'app' should set 'securityContext.runAsNonRoot' to true
```

---

## Cấu hình .kube-linter.yaml

```yaml
# .kube-linter.yaml – Cấu hình tùy chỉnh
checks:
  # Dùng tất cả checks mặc định
  addAllBuiltIn: true

  # Bỏ qua checks không phù hợp
  exclude:
    - "latest-tag"  # Nếu môi trường dev cho phép latest

  # Hoặc chỉ chạy checks cụ thể
  # include:
  #   - "run-as-non-root"
  #   - "read-only-root-filesystem"
  #   - "unset-cpu-requirements"
  #   - "unset-memory-requirements"

# Custom check ví dụ: yêu cầu label bắt buộc
customChecks:
  - name: "require-app-label"
    template: required-label
    params:
      key: "app.kubernetes.io/name"
```

### Chạy với config file

```bash
kube-linter lint --config .kube-linter.yaml ./k8s/
```

### Tích hợp CI/CD (GitHub Actions)

```yaml
- name: Lint Kubernetes manifests
  run: |
    curl -sSL https://github.com/stackrox/kube-linter/releases/latest/download/kube-linter-linux.tar.gz | tar xz
    sudo mv kube-linter /usr/local/bin/
    kube-linter lint ./k8s/ --format json | jq .
    kube-linter lint ./k8s/  # exit 1 nếu có lỗi → fail pipeline
```
