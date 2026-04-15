# Lab 1.6 – Gateway API với TLS (Migration từ Ingress)

**Domain:** Cluster Setup (15%)
**Thời gian ước tính:** 30 phút
**Độ khó:** Nâng cao

---

## Mục tiêu

- Hiểu tại sao Kubernetes đang migrate từ Ingress API sang **Gateway API**
- Hiểu kiến trúc Gateway API: **GatewayClass** → **Gateway** → **HTTPRoute**
- Cài đặt Gateway Controller (NGINX Gateway Fabric) thủ công theo hướng dẫn
- Tạo GatewayClass và Gateway với TLS termination
- Tạo HTTPRoute để route traffic đến backend service
- So sánh cấu hình Ingress TLS vs Gateway API TLS

---

## Lý thuyết

### Tại sao cần Gateway API? — Hạn chế của Ingress

Ingress API đã tồn tại từ Kubernetes 1.1 và có nhiều hạn chế:

| Hạn chế | Mô tả |
|---------|-------|
| **Annotation hell** | Mỗi controller dùng annotation riêng (`nginx.ingress.kubernetes.io/...`, `traefik.ingress.kubernetes.io/...`) — không portable |
| **Chỉ HTTP/HTTPS** | Không hỗ trợ TCP, UDP, gRPC natively |
| **Không có role separation** | Cluster admin và app developer dùng chung resource |
| **Thiếu expressiveness** | Không hỗ trợ traffic splitting, header-based routing natively |

**Gateway API** (GA từ Kubernetes 1.28) giải quyết tất cả vấn đề trên.

### Kiến trúc Gateway API — 3 thành phần chính

```
┌──────────────────────────────────────────────────────────────┐
│  GatewayClass  (Cluster Admin quản lý)                        │
│  └─ Liên kết với Gateway Controller cụ thể                    │
│     (nginx-gateway, cilium, istio, envoy...)                  │
│                                                               │
│  Gateway  (Cluster Admin / Platform Team quản lý)             │
│  └─ Định nghĩa listener: port, protocol, TLS cert            │
│     Tương đương: LoadBalancer + TLS config                    │
│                                                               │
│  HTTPRoute / TCPRoute / GRPCRoute  (App Developer quản lý)   │
│  └─ Định nghĩa routing rules: host, path, backend            │
│     Tương đương: Ingress rules                                │
└──────────────────────────────────────────────────────────────┘
```

**Role separation** — đây là điểm khác biệt lớn nhất:

| Resource | Ai quản lý | Tương đương Ingress |
|----------|-----------|---------------------|
| `GatewayClass` | Cluster Admin | Ingress Controller + IngressClass |
| `Gateway` | Platform Team | Ingress (phần TLS + port) |
| `HTTPRoute` | App Developer | Ingress (phần rules) |

### So sánh Ingress vs Gateway API

**Ingress TLS (cũ):**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-ingress
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"  # Annotation không portable
spec:
  ingressClassName: nginx
  tls:
  - hosts: [app.example.com]
    secretName: tls-secret
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-service
            port:
              number: 80
```

**Gateway API TLS (mới):**
```yaml
# Gateway — định nghĩa listener với TLS
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-gateway
spec:
  gatewayClassName: nginx          # Liên kết với GatewayClass
  listeners:
  - name: https
    port: 443
    protocol: HTTPS
    tls:
      mode: Terminate              # TLS termination
      certificateRefs:
      - name: tls-secret           # TLS Secret
    allowedRoutes:
      namespaces:
        from: Same
---
# HTTPRoute — định nghĩa routing rules (tách biệt)
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-route
spec:
  parentRefs:
  - name: my-gateway               # Tham chiếu đến Gateway
  hostnames: [app.example.com]
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: my-service
      port: 80
```

### GatewayClass là gì?

**GatewayClass** là cluster-scoped resource, tương tự IngressClass, liên kết với một Gateway Controller cụ thể:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: nginx
spec:
  controllerName: gateway.nginx.org/nginx-gateway-controller
```

Khi tạo Gateway với `gatewayClassName: nginx`, NGINX Gateway Controller sẽ xử lý Gateway đó.

### TLS modes trong Gateway API

| Mode | Mô tả | Dùng khi nào |
|------|-------|--------------|
| `Terminate` | TLS termination tại Gateway | Phổ biến nhất — backend nhận HTTP |
| `Passthrough` | Forward TLS đến backend | Backend tự xử lý TLS (mTLS) |

---

## Bối cảnh

Team platform của bạn đang migrate từ Ingress sang Gateway API. Bạn cần:
1. Cài đặt NGINX Gateway Fabric (Gateway Controller)
2. Tạo GatewayClass và Gateway với TLS
3. Tạo HTTPRoute để route traffic
4. Xác minh HTTPS hoạt động qua Gateway API

---

## Yêu cầu môi trường

- Kubernetes cluster >= 1.28 (Gateway API GA)
- `kubectl` đã được cấu hình với quyền cluster-admin
- `helm` đã được cài đặt
- `openssl` đã được cài đặt
- Namespace `gateway-lab` đã được tạo bởi `setup.sh`

Chạy script khởi tạo môi trường:

```bash
bash setup.sh
```

---

## Các bước thực hiện

### Bước 1: Cài đặt Gateway API CRDs

Gateway API CRDs không có sẵn trong Kubernetes — cần cài thêm:

```bash
# Cài đặt Gateway API CRDs (Standard channel)
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml

# Xác minh CRDs đã được cài
kubectl get crd | grep gateway.networking.k8s.io
# gatewayclasses.gateway.networking.k8s.io
# gateways.gateway.networking.k8s.io
# httproutes.gateway.networking.k8s.io
# referencegrants.gateway.networking.k8s.io
```

---

### Bước 2: Cài đặt NGINX Gateway Fabric (Gateway Controller)

```bash
# Thêm Helm repo
helm repo add nginx-gateway https://helm.nginx.com/stable
helm repo update

# Cài đặt NGINX Gateway Fabric
helm install nginx-gateway nginx-gateway/nginx-gateway-fabric \
  --namespace nginx-gateway \
  --create-namespace \
  --set service.type=NodePort \
  --set service.nodePorts.http=31080 \
  --set service.nodePorts.https=31443

# Chờ controller sẵn sàng
kubectl wait --namespace nginx-gateway \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=nginx-gateway-fabric \
  --timeout=120s

# Xác minh
kubectl get pods -n nginx-gateway
```

---

### Bước 3: Tạo GatewayClass

> **Lưu ý:** Khi cài NGINX Gateway Fabric bằng Helm, GatewayClass thường được tạo tự động. Kiểm tra trước:

```bash
kubectl get gatewayclass
```

Nếu chưa có, tạo thủ công:

```bash
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: nginx
spec:
  controllerName: gateway.nginx.org/nginx-gateway-controller
EOF

# Xác minh GatewayClass đã được Accepted
kubectl get gatewayclass nginx
# NAME    CONTROLLER                                      ACCEPTED   AGE
# nginx   gateway.nginx.org/nginx-gateway-controller     True       30s
```

**Quan trọng:** `ACCEPTED: True` nghĩa là Controller đã nhận GatewayClass. Nếu `False` hoặc `Unknown`, Controller chưa chạy.

---

### Bước 4: Tạo TLS certificate và Secret

```bash
mkdir -p /tmp/gateway-lab

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /tmp/gateway-lab/tls.key \
  -out /tmp/gateway-lab/tls.crt \
  -subj "/CN=app.gateway-lab.local/O=gateway-lab"

kubectl create secret tls gateway-tls-secret \
  --cert=/tmp/gateway-lab/tls.crt \
  --key=/tmp/gateway-lab/tls.key \
  -n gateway-lab

kubectl get secret gateway-tls-secret -n gateway-lab
```

---

### Bước 5: Tạo Gateway với TLS listener

```bash
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: main-gateway
  namespace: gateway-lab
spec:
  gatewayClassName: nginx              # Liên kết với GatewayClass
  listeners:
  - name: https
    port: 443
    protocol: HTTPS
    hostname: app.gateway-lab.local    # Hostname filter
    tls:
      mode: Terminate                  # TLS termination tại Gateway
      certificateRefs:
      - kind: Secret
        name: gateway-tls-secret       # TLS Secret
    allowedRoutes:
      namespaces:
        from: Same                     # Chỉ cho phép HTTPRoute cùng namespace
EOF

# Xem trạng thái Gateway
kubectl get gateway main-gateway -n gateway-lab
# NAME           CLASS   ADDRESS        PROGRAMMED   AGE
# main-gateway   nginx   192.168.1.10   True         30s

# Xem chi tiết
kubectl describe gateway main-gateway -n gateway-lab
```

**`PROGRAMMED: True`** = Gateway Controller đã cấu hình xong.

---

### Bước 6: Tạo HTTPRoute

```bash
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: app-route
  namespace: gateway-lab
spec:
  parentRefs:
  - name: main-gateway              # Tham chiếu đến Gateway
    namespace: gateway-lab
    sectionName: https              # Tên listener trong Gateway
  hostnames:
  - app.gateway-lab.local
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: nginx-service           # Backend service
      port: 80
EOF

# Xem trạng thái HTTPRoute
kubectl get httproute app-route -n gateway-lab
# NAME        HOSTNAMES                    AGE
# app-route   ["app.gateway-lab.local"]    10s

# Xem chi tiết — kiểm tra Parents status
kubectl describe httproute app-route -n gateway-lab
```

---

### Bước 7: Test HTTPS qua Gateway API

```bash
# Lấy NodePort của Gateway Controller
HTTPS_PORT=$(kubectl get svc -n nginx-gateway \
  -o jsonpath='{.items[0].spec.ports[?(@.name=="https")].nodePort}' 2>/dev/null || echo "31443")
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

echo "Test URL: https://$NODE_IP:$HTTPS_PORT/"

# Test HTTPS
curl -k -H "Host: app.gateway-lab.local" https://$NODE_IP:$HTTPS_PORT/
# Mong đợi: HTML của nginx

# Xem certificate được trả về
curl -k -v -H "Host: app.gateway-lab.local" https://$NODE_IP:$HTTPS_PORT/ 2>&1 | \
  grep -E "subject:|issuer:|TLS"
```

---

### Bước 8: So sánh Ingress vs Gateway API trong cluster

```bash
# Xem Ingress resources (nếu có từ lab-1.3)
kubectl get ingress --all-namespaces

# Xem Gateway resources
kubectl get gateway --all-namespaces
kubectl get httproute --all-namespaces
kubectl get gatewayclass

# So sánh cấu trúc
echo "=== Ingress ==="
kubectl get ingress tls-ingress -n tls-lab -o yaml 2>/dev/null | \
  grep -A5 "spec:" | head -20

echo "=== Gateway + HTTPRoute ==="
kubectl get gateway main-gateway -n gateway-lab -o yaml | \
  grep -A10 "listeners:" | head -20
```

---

### Bước 9: Chạy verify script

```bash
bash verify.sh
```

---

## Tiêu chí kiểm tra

- [ ] Gateway API CRDs đã được cài đặt (`kubectl get crd | grep gateway.networking.k8s.io`)
- [ ] GatewayClass `nginx` tồn tại và có `ACCEPTED: True`
- [ ] Gateway `main-gateway` trong namespace `gateway-lab` có `PROGRAMMED: True`
- [ ] HTTPRoute `app-route` tồn tại và tham chiếu đến `main-gateway`

---

## Gợi ý

<details>
<summary>Gợi ý 1: Gateway không PROGRAMMED — nguyên nhân thường gặp</summary>

```bash
# Xem events của Gateway
kubectl describe gateway main-gateway -n gateway-lab

# Xem logs của Gateway Controller
kubectl logs -n nginx-gateway -l app.kubernetes.io/name=nginx-gateway-fabric --tail=50

# Kiểm tra GatewayClass có ACCEPTED không
kubectl get gatewayclass nginx -o yaml | grep -A5 "status:"
```

Nguyên nhân phổ biến:
- Controller chưa chạy → `kubectl get pods -n nginx-gateway`
- `gatewayClassName` không khớp với GatewayClass name
- TLS Secret không tồn tại hoặc sai namespace

</details>

<details>
<summary>Gợi ý 2: HTTPRoute không được route — kiểm tra parentRefs</summary>

```bash
# Xem status của HTTPRoute
kubectl describe httproute app-route -n gateway-lab

# Phần quan trọng trong output:
# Status:
#   Parents:
#   - Conditions:
#     - Type: Accepted
#       Status: "True"
#     - Type: ResolvedRefs
#       Status: "True"
```

Nếu `Accepted: False` → `parentRefs` không khớp với Gateway.
Nếu `ResolvedRefs: False` → backend service không tồn tại.

</details>

<details>
<summary>Gợi ý 3: ReferenceGrant — cho phép cross-namespace</summary>

Nếu HTTPRoute và Gateway ở **khác namespace**, cần `ReferenceGrant`:

```yaml
# Trong namespace của Gateway
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: allow-httproute
  namespace: gateway-ns
spec:
  from:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    namespace: app-ns          # Namespace của HTTPRoute
  to:
  - group: ""
    kind: Service
```

</details>

<details>
<summary>Gợi ý 4: Traffic splitting với Gateway API</summary>

Gateway API hỗ trợ traffic splitting natively (không cần annotation):

```yaml
rules:
- backendRefs:
  - name: app-v1
    port: 80
    weight: 80    # 80% traffic
  - name: app-v2
    port: 80
    weight: 20    # 20% traffic (canary)
```

Đây là tính năng Ingress không hỗ trợ natively.

</details>

---

## Giải pháp mẫu

<details>
<summary>Xem giải pháp đầy đủ (chỉ mở sau khi đã thử)</summary>

Xem file [solution/solution.md](solution/solution.md) để có các lệnh đầy đủ và giải thích chi tiết.

</details>

---

## Giải thích

### Tại sao Gateway API là tương lai?

| Tính năng | Ingress | Gateway API |
|-----------|---------|-------------|
| Role separation | ❌ Không | ✅ GatewayClass/Gateway/Route |
| TCP/UDP support | ❌ Không | ✅ TCPRoute, UDPRoute |
| Traffic splitting | ❌ Annotation | ✅ Native (weight) |
| Header-based routing | ❌ Annotation | ✅ Native |
| Cross-namespace | ❌ Hạn chế | ✅ ReferenceGrant |
| Portability | ❌ Annotation khác nhau | ✅ Chuẩn hóa |
| Status reporting | ❌ Hạn chế | ✅ Chi tiết per-controller |

### Migration path từ Ingress sang Gateway API

```
Ingress                    Gateway API
──────────────────────     ──────────────────────────────
IngressClass          →    GatewayClass
Ingress (TLS + rules) →    Gateway (TLS) + HTTPRoute (rules)
Annotation            →    Native fields
```

### Gateway API trong CKS

Gateway API đang được đưa vào CKS curriculum vì:
- Kubernetes 1.28+ GA
- Nhiều production cluster đang migrate
- Bảo mật tốt hơn nhờ role separation và ReferenceGrant

---

## Tham khảo

- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/)
- [Gateway API vs Ingress](https://gateway-api.sigs.k8s.io/concepts/api-overview/)
- [NGINX Gateway Fabric](https://docs.nginx.com/nginx-gateway-fabric/)
- [Migrating from Ingress](https://gateway-api.sigs.k8s.io/guides/migrating-from-ingress/)
- [CKS Exam Curriculum – Cluster Setup](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/)
