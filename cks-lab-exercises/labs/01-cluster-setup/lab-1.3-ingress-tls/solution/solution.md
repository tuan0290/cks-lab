# Giải pháp mẫu – Lab 1.3: Ingress TLS

---

## Bước 1: Cài NGINX Ingress Controller

```bash
# Dùng Helm
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=NodePort \
  --set controller.service.nodePorts.http=30080 \
  --set controller.service.nodePorts.https=30443

# Chờ sẵn sàng
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

# Xác minh IngressClass được tạo tự động
kubectl get ingressclass
# NAME    CONTROLLER             PARAMETERS   AGE
# nginx   k8s.io/ingress-nginx   <none>       1m
```

## Bước 2: Tạo TLS certificate

```bash
mkdir -p /tmp/tls-lab

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /tmp/tls-lab/tls.key \
  -out /tmp/tls-lab/tls.crt \
  -subj "/CN=app.tls-lab.local/O=tls-lab"

# Xác minh
openssl x509 -in /tmp/tls-lab/tls.crt -noout -subject -dates
```

## Bước 3: Tạo TLS Secret

```bash
kubectl create secret tls tls-secret \
  --cert=/tmp/tls-lab/tls.crt \
  --key=/tmp/tls-lab/tls.key \
  -n tls-lab

# Xác minh type
kubectl get secret tls-secret -n tls-lab
# NAME         TYPE                DATA   AGE
# tls-secret   kubernetes.io/tls   2      5s
```

## Bước 4: Tạo Ingress với ingressClassName và TLS

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
  ingressClassName: nginx          # Liên kết với NGINX Ingress Controller
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

# Xác minh Ingress có ADDRESS (controller đã nhận)
kubectl get ingress tls-ingress -n tls-lab
# NAME          CLASS   HOSTS               ADDRESS        PORTS     AGE
# tls-ingress   nginx   app.tls-lab.local   192.168.1.10   80, 443   30s
```

## Bước 5: Test HTTPS

```bash
HTTPS_PORT=$(kubectl get svc ingress-nginx-controller -n ingress-nginx \
  -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

# Test HTTPS (-k bỏ qua self-signed cert warning)
curl -k -H "Host: app.tls-lab.local" https://$NODE_IP:$HTTPS_PORT/
# Mong đợi: HTML của nginx

# Xem certificate được trả về
curl -k -v -H "Host: app.tls-lab.local" https://$NODE_IP:$HTTPS_PORT/ 2>&1 | \
  grep -E "subject:|issuer:|TLS"
```

---

## Giải thích kiến trúc

```
curl → NodePort:30443 → ingress-nginx-controller Pod
                         ↓ (đọc Ingress resource có ingressClassName=nginx)
                         ↓ (lấy TLS Secret tls-secret)
                         ↓ (TLS handshake với client)
                         ↓ (forward HTTP đến)
                        nginx-service:80 → nginx Pod
```

**Tại sao `ingressClassName` bắt buộc?**

Nếu không có `ingressClassName`, Ingress Controller không biết Ingress này thuộc về nó. Ingress sẽ không có ADDRESS và traffic không được route.

---

## Tham khảo

- [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [IngressClass](https://kubernetes.io/docs/concepts/services-networking/ingress/#ingress-class)
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
