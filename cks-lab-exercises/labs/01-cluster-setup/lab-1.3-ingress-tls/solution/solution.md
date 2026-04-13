# Giải pháp mẫu – Lab 1.3: Ingress TLS

> **Lưu ý:** Chỉ đọc sau khi đã tự thử thực hành. Việc tự giải quyết vấn đề giúp bạn ghi nhớ tốt hơn nhiều so với đọc đáp án.

---

## Bước 1: Tạo self-signed TLS certificate

```bash
mkdir -p /tmp/tls-lab

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /tmp/tls-lab/tls.key \
  -out /tmp/tls-lab/tls.crt \
  -subj "/CN=app.tls-lab.local/O=tls-lab"
```

Xác nhận certificate đã được tạo:

```bash
ls -la /tmp/tls-lab/
# tls.crt  tls.key

openssl x509 -in /tmp/tls-lab/tls.crt -text -noout | grep -E "Subject:|Not After"
# Subject: CN = app.tls-lab.local, O = tls-lab
# Not After : <ngày hết hạn>
```

---

## Bước 2: Tạo Kubernetes TLS Secret

```bash
kubectl create secret tls tls-secret \
  --cert=/tmp/tls-lab/tls.crt \
  --key=/tmp/tls-lab/tls.key \
  -n tls-lab
```

Xác nhận Secret:

```bash
kubectl get secret tls-secret -n tls-lab
# NAME         TYPE                DATA   AGE
# tls-secret   kubernetes.io/tls   2      5s

kubectl describe secret tls-secret -n tls-lab
# Type:  kubernetes.io/tls
# Data
# ====
# tls.crt:  <size> bytes
# tls.key:  <size> bytes
```

---

## Bước 3: Tạo Ingress với TLS

```yaml
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
```

```bash
kubectl apply -f ingress-tls.yaml
# hoặc dùng heredoc:
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

Xác nhận Ingress:

```bash
kubectl get ingress tls-ingress -n tls-lab
# NAME          CLASS   HOSTS               ADDRESS   PORTS     AGE
# tls-ingress   nginx   app.tls-lab.local             80, 443   5s

kubectl describe ingress tls-ingress -n tls-lab
# TLS:
#   tls-secret terminates app.tls-lab.local
```

---

## Giải thích TLS Termination tại Ingress

### Luồng xử lý request

```
Client
  |
  | HTTPS (port 443)
  | TLS handshake với certificate từ tls-secret
  v
Ingress Controller (nginx)
  |
  | HTTP (port 80) — traffic đã được giải mã
  v
Service: nginx-service
  |
  v
Pod: nginx-deployment
```

Ingress controller thực hiện **TLS termination**:
1. Nhận HTTPS request từ client
2. Dùng `tls.key` trong Secret để giải mã TLS handshake
3. Gửi certificate `tls.crt` cho client để xác thực
4. Chuyển tiếp request dưới dạng HTTP thuần đến backend

### Tại sao TLS termination tại Ingress?

**Ưu điểm:**
- Backend Pod không cần xử lý TLS — đơn giản hóa ứng dụng
- Quản lý certificate tập trung tại một điểm
- Giảm overhead CPU cho Pod (TLS decryption tốn tài nguyên)
- Dễ rotate certificate mà không cần restart Pod

**Nhược điểm:**
- Traffic từ Ingress đến Pod là HTTP (không mã hóa trong cluster)
- Nếu cần end-to-end encryption, dùng mTLS (mutual TLS) với service mesh

### Annotation ssl-redirect

```yaml
annotations:
  nginx.ingress.kubernetes.io/ssl-redirect: "true"
```

Annotation này yêu cầu nginx-ingress tự động redirect HTTP → HTTPS. Khi client truy cập `http://app.tls-lab.local`, sẽ được redirect đến `https://app.tls-lab.local`.

---

## Tham khảo

- [Kubernetes Ingress TLS](https://kubernetes.io/docs/concepts/services-networking/ingress/#tls)
- [TLS Secrets](https://kubernetes.io/docs/concepts/configuration/secret/#tls-secrets)
- [NGINX Ingress Controller – TLS/HTTPS](https://kubernetes.github.io/ingress-nginx/user-guide/tls/)
- [openssl req documentation](https://www.openssl.org/docs/man1.1.1/man1/req.html)
