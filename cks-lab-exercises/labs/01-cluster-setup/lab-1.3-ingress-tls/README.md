# Lab 1.3 – Ingress TLS

**Domain:** Cluster Setup (15%)
**Thời gian ước tính:** 30 phút
**Độ khó:** Trung bình

---

## Mục tiêu

- Hiểu kiến trúc Ingress: **Ingress Controller** → **IngressClass** → **Ingress resource**
- Cài đặt NGINX Ingress Controller bằng Helm
- Tạo self-signed TLS certificate bằng `openssl`
- Tạo Kubernetes Secret kiểu `kubernetes.io/tls`
- Cấu hình Ingress resource với TLS termination và đúng `ingressClassName`
- Xác minh HTTPS hoạt động thực sự qua `curl -k`

---

## Lý thuyết

### Ingress hoạt động như thế nào? — 3 thành phần bắt buộc

Đây là điểm **hay bị hiểu nhầm nhất**: Ingress resource chỉ là **cấu hình** — nó không tự xử lý traffic. Cần đủ 3 thành phần:

```
┌─────────────────────────────────────────────────────────┐
│  1. Ingress Controller (Pod thực sự xử lý traffic)       │
│     └─ nginx-ingress-controller, traefik, haproxy...     │
│                                                          │
│  2. IngressClass (liên kết Controller với Ingress)       │
│     └─ nginx, traefik, haproxy...                        │
│                                                          │
│  3. Ingress resource (cấu hình routing rules)            │
│     └─ host, path, TLS, backend service                  │
└─────────────────────────────────────────────────────────┘
```

**Nếu thiếu Ingress Controller** → Ingress resource được tạo nhưng không có gì xử lý traffic → HTTPS không hoạt động.

**Nếu thiếu IngressClass** → Ingress Controller không biết Ingress resource nào thuộc về nó → bị bỏ qua.

### Ingress Controller là gì?

**Ingress Controller** là một Pod chạy trong cluster, lắng nghe trên port 80/443, đọc Ingress resources và cấu hình reverse proxy tương ứng.

```
Internet → [LoadBalancer/NodePort] → Ingress Controller Pod → Service → Pod
                                     (nginx, traefik, haproxy...)
```

Kubernetes **không có** Ingress Controller built-in — bạn phải cài thêm. Phổ biến nhất:

| Controller | Cài đặt | Ghi chú |
|-----------|---------|---------|
| **NGINX Ingress** | `helm install ingress-nginx ingress-nginx/ingress-nginx` | Phổ biến nhất, dùng trong CKS |
| Traefik | `helm install traefik traefik/traefik` | Tích hợp tốt với Docker |
| HAProxy | `helm install haproxy haproxytech/kubernetes-ingress` | Hiệu năng cao |

### IngressClass là gì?

**IngressClass** là resource liên kết Ingress resource với Ingress Controller cụ thể. Khi có nhiều controller trong cluster, IngressClass xác định controller nào xử lý Ingress nào.

```yaml
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: nginx
spec:
  controller: k8s.io/ingress-nginx  # Tên controller
```

Trong Ingress resource, khai báo `ingressClassName` để chỉ định:

```yaml
spec:
  ingressClassName: nginx   # Phải khớp với tên IngressClass
  tls: [...]
  rules: [...]
```

> **Lưu ý:** Từ Kubernetes 1.18+, `ingressClassName` là cách chuẩn. Annotation cũ `kubernetes.io/ingress.class` vẫn hoạt động nhưng deprecated.

### TLS Termination tại Ingress

```
Client ──[HTTPS port 443]──► Ingress Controller ──[HTTP port 80]──► Service ──► Pod
                              (decrypt TLS ở đây)
```

Ingress Controller:
1. Nhận HTTPS request từ client
2. Dùng private key trong TLS Secret để decrypt
3. Gửi certificate cho client để xác thực
4. Forward request dưới dạng HTTP thuần đến backend

Backend Pod **không cần** biết về TLS — đơn giản hóa ứng dụng.

### Luồng đầy đủ khi request đến

```
1. Client gửi HTTPS request đến domain app.tls-lab.local
2. DNS resolve → IP của LoadBalancer/NodePort của Ingress Controller
3. Ingress Controller nhận request trên port 443
4. Tìm Ingress resource có host=app.tls-lab.local và ingressClassName=nginx
5. Lấy TLS Secret tls-secret để decrypt
6. Forward HTTP request đến Service nginx-service:80
7. Service forward đến Pod
```

### TLS Secret

```bash
kubectl create secret tls <tên> \
  --cert=tls.crt \
  --key=tls.key \
  -n <namespace>
```

Secret có `type: kubernetes.io/tls` với 2 key: `tls.crt` và `tls.key`.

---

## Bối cảnh

Bạn là kỹ sư bảo mật tại một công ty fintech. Ứng dụng web đang chạy trong namespace `tls-lab` chỉ có HTTP. Yêu cầu bảo mật bắt buộc tất cả traffic phải được mã hóa qua HTTPS.

Nhiệm vụ của bạn là thiết lập toàn bộ stack Ingress TLS từ đầu:
1. Cài đặt NGINX Ingress Controller
2. Tạo TLS certificate và Secret
3. Cấu hình Ingress với đúng `ingressClassName` và TLS
4. Xác minh HTTPS hoạt động thực sự

---

## Yêu cầu môi trường

- Kubernetes cluster >= 1.29
- `kubectl` đã được cấu hình và kết nối đến cluster
- `openssl` đã được cài đặt
- `helm` đã được cài đặt (để cài Ingress Controller)
- Quyền tạo namespace, Deployment, Service, Ingress, IngressClass

Chạy script khởi tạo môi trường:

```bash
bash setup.sh
```

---

## Các bước thực hiện

### Bước 1: Kiểm tra Ingress Controller đã có chưa

```bash
# Kiểm tra xem đã có Ingress Controller nào chưa
kubectl get pods --all-namespaces | grep -i ingress

# Kiểm tra IngressClass có sẵn
kubectl get ingressclass

# Kiểm tra namespace ingress-nginx
kubectl get namespace ingress-nginx 2>/dev/null || echo "Chưa có ingress-nginx namespace"
```

---

### Bước 2: Cài đặt NGINX Ingress Controller (nếu chưa có)

```bash
# Thêm Helm repo
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Cài đặt NGINX Ingress Controller
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=NodePort \
  --set controller.service.nodePorts.http=30080 \
  --set controller.service.nodePorts.https=30443

# Chờ controller sẵn sàng
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

Xác minh:
```bash
# Controller pod phải Running
kubectl get pods -n ingress-nginx

# IngressClass 'nginx' phải tồn tại
kubectl get ingressclass
# NAME    CONTROLLER             PARAMETERS   AGE
# nginx   k8s.io/ingress-nginx   <none>       1m
```

---

### Bước 3: Hiểu IngressClass vừa được tạo

```bash
# Xem chi tiết IngressClass
kubectl describe ingressclass nginx

# Xem YAML
kubectl get ingressclass nginx -o yaml
```

Output quan trọng:
```yaml
spec:
  controller: k8s.io/ingress-nginx  # Controller nào xử lý
```

Khi tạo Ingress resource với `ingressClassName: nginx`, NGINX Ingress Controller sẽ đọc và xử lý Ingress đó.

---

### Bước 4: Tạo self-signed TLS certificate

```bash
mkdir -p /tmp/tls-lab

# Tạo private key và self-signed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /tmp/tls-lab/tls.key \
  -out /tmp/tls-lab/tls.crt \
  -subj "/CN=app.tls-lab.local/O=tls-lab"

# Xác minh certificate
openssl x509 -in /tmp/tls-lab/tls.crt -text -noout | \
  grep -E "Subject:|Not After|Issuer"
```

---

### Bước 5: Tạo TLS Secret trong namespace tls-lab

```bash
kubectl create secret tls tls-secret \
  --cert=/tmp/tls-lab/tls.crt \
  --key=/tmp/tls-lab/tls.key \
  -n tls-lab

# Xác minh type là kubernetes.io/tls
kubectl get secret tls-secret -n tls-lab
# NAME         TYPE                DATA   AGE
# tls-secret   kubernetes.io/tls   2      5s
```

---

### Bước 6: Tạo Ingress resource với TLS và ingressClassName

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
  ingressClassName: nginx        # Quan trọng: phải khớp với IngressClass
  tls:
  - hosts:
    - app.tls-lab.local          # Phải khớp với host trong rules
    secretName: tls-secret       # TLS Secret vừa tạo
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

Xác minh Ingress đã được nhận bởi controller:
```bash
kubectl get ingress tls-ingress -n tls-lab
# NAME          CLASS   HOSTS               ADDRESS        PORTS     AGE
# tls-ingress   nginx   app.tls-lab.local   <node-ip>      80, 443   10s

# Xem chi tiết
kubectl describe ingress tls-ingress -n tls-lab
# TLS:
#   tls-secret terminates app.tls-lab.local
```

> **Lưu ý:** Nếu cột `ADDRESS` trống sau 1-2 phút, kiểm tra Ingress Controller đang chạy không.

---

### Bước 7: Test HTTPS thực sự

```bash
# Lấy NodePort của Ingress Controller
HTTPS_PORT=$(kubectl get svc ingress-nginx-controller -n ingress-nginx \
  -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
echo "HTTPS NodePort: $HTTPS_PORT"

# Lấy IP của node
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo "Node IP: $NODE_IP"

# Test HTTPS với curl (-k để bỏ qua self-signed cert warning)
curl -k -H "Host: app.tls-lab.local" https://$NODE_IP:$HTTPS_PORT/
# Mong đợi: HTML của nginx

# Xem certificate được trả về
curl -k -v -H "Host: app.tls-lab.local" https://$NODE_IP:$HTTPS_PORT/ 2>&1 | \
  grep -E "subject:|issuer:|SSL|TLS"
```

---

### Bước 8: So sánh — Ingress không có ingressClassName

Thử tạo Ingress **không có** `ingressClassName`:

```bash
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: no-class-ingress
  namespace: tls-lab
spec:
  # ingressClassName bị bỏ — không có controller nào nhận
  tls:
  - hosts:
    - app2.tls-lab.local
    secretName: tls-secret
  rules:
  - host: app2.tls-lab.local
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

# Xem trạng thái — ADDRESS sẽ trống mãi
kubectl get ingress no-class-ingress -n tls-lab
# NAME               CLASS    HOSTS                ADDRESS   PORTS     AGE
# no-class-ingress   <none>   app2.tls-lab.local             80, 443   10s
#                    ↑ Không có class → không controller nào xử lý

# Xóa ingress này
kubectl delete ingress no-class-ingress -n tls-lab
```

---

### Bước 9: Chạy verify script

```bash
bash verify.sh
```

---

## Tiêu chí kiểm tra

- [ ] NGINX Ingress Controller đang chạy trong namespace `ingress-nginx`
- [ ] IngressClass `nginx` tồn tại trong cluster
- [ ] Secret `tls-secret` tồn tại trong namespace `tls-lab` với type `kubernetes.io/tls`
- [ ] Ingress `tls-ingress` tồn tại với `ingressClassName: nginx` và cấu hình TLS

---

## Gợi ý

<details>
<summary>Gợi ý 1: Tại sao Ingress không hoạt động dù đã tạo?</summary>

Kiểm tra theo thứ tự:

```bash
# 1. Ingress Controller có đang chạy không?
kubectl get pods -n ingress-nginx

# 2. IngressClass có tồn tại không?
kubectl get ingressclass

# 3. Ingress resource có đúng ingressClassName không?
kubectl get ingress -n tls-lab -o yaml | grep ingressClassName

# 4. Ingress có ADDRESS không? (nếu trống = controller chưa nhận)
kubectl get ingress -n tls-lab

# 5. Logs của Ingress Controller
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=50
```

</details>

<details>
<summary>Gợi ý 2: Cài Ingress Controller không dùng Helm</summary>

```bash
# Cài bằng manifest trực tiếp (không cần Helm)
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/baremetal/deploy.yaml

# Chờ sẵn sàng
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

</details>

<details>
<summary>Gợi ý 3: Default IngressClass</summary>

Nếu muốn Ingress Controller xử lý tất cả Ingress không có `ingressClassName`, đặt annotation `ingressclass.kubernetes.io/is-default-class: "true"`:

```bash
kubectl annotate ingressclass nginx \
  ingressclass.kubernetes.io/is-default-class=true
```

Sau đó Ingress không có `ingressClassName` sẽ tự động dùng controller này.

</details>

<details>
<summary>Gợi ý 4: Test HTTPS với /etc/hosts</summary>

Để test bằng domain thực thay vì `-H "Host:"`:

```bash
# Thêm vào /etc/hosts
echo "$NODE_IP app.tls-lab.local" | sudo tee -a /etc/hosts

# Test bằng domain
curl -k https://app.tls-lab.local:$HTTPS_PORT/

# Xóa sau khi test
sudo sed -i '/app.tls-lab.local/d' /etc/hosts
```

</details>

---

## Giải pháp mẫu

<details>
<summary>Xem giải pháp đầy đủ (chỉ mở sau khi đã thử)</summary>

Xem file [solution/solution.md](solution/solution.md) để có lệnh đầy đủ và giải thích chi tiết.

</details>

---

## Giải thích

### Tại sao cần đủ 3 thành phần?

| Thành phần | Vai trò | Nếu thiếu |
|-----------|---------|-----------|
| **Ingress Controller** | Pod thực sự nhận và xử lý traffic | Traffic không đến được backend |
| **IngressClass** | Liên kết Controller với Ingress resource | Controller không biết Ingress nào thuộc về nó |
| **Ingress resource** | Định nghĩa routing rules và TLS | Không có rules để route |

### Tại sao `ingressClassName` quan trọng?

Trong cluster có nhiều Ingress Controller (nginx + traefik chẳng hạn), `ingressClassName` xác định controller nào xử lý Ingress nào. Nếu không khai báo và không có default class, Ingress bị bỏ qua hoàn toàn.

### TLS Secret và Ingress Controller

Ingress Controller đọc TLS Secret để:
1. Load private key vào memory
2. Cấu hình TLS listener cho domain tương ứng
3. Khi client kết nối, dùng private key để TLS handshake

Secret phải ở **cùng namespace** với Ingress resource.

### Trong CKS Exam

Bạn thường được cấp cluster đã có Ingress Controller sẵn. Nhiệm vụ thường là:
1. Tạo TLS Secret từ cert/key cho sẵn
2. Tạo Ingress với đúng `ingressClassName`, `spec.tls`, và `spec.rules`
3. Xác minh Ingress có ADDRESS và TLS hoạt động

Lệnh quan trọng nhất:
```bash
kubectl create secret tls <name> --cert=tls.crt --key=tls.key -n <ns>
```

---

## Tham khảo

- [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [IngressClass](https://kubernetes.io/docs/concepts/services-networking/ingress/#ingress-class)
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [TLS Secrets](https://kubernetes.io/docs/concepts/configuration/secret/#tls-secrets)
- [CKS Exam Curriculum – Cluster Setup](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/)
