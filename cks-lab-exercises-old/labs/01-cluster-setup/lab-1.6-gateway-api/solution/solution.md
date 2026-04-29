# Giải pháp mẫu – Lab 1.6: Gateway API với TLS

---

## Bước 1: Cài Gateway API CRDs + NGINX Gateway Fabric

```bash
# CRDs tương thích với NGF v2.5.1
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v2.5.1" | kubectl apply -f -

# Cài NGF từ OCI registry (không cần helm repo add)
helm install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric \
  --create-namespace \
  --namespace nginx-gateway \
  --set nginx.service.type=NodePort

kubectl wait --timeout=5m \
  -n nginx-gateway \
  deployment/ngf-nginx-gateway-fabric \
  --for=condition=Available
```

## Bước 3: Kiểm tra GatewayClass (tự động tạo)

```bash
kubectl get gatewayclass
# NAME    CONTROLLER                                      ACCEPTED   AGE
# nginx   gateway.nginx.org/nginx-gateway-controller     True       1m
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
```

## Bước 4: TLS Secret

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
```

## Bước 5: Gateway với TLS

```bash
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: main-gateway
  namespace: gateway-lab
spec:
  gatewayClassName: nginx
  listeners:
  - name: https
    port: 443
    protocol: HTTPS
    hostname: app.gateway-lab.local
    tls:
      mode: Terminate
      certificateRefs:
      - kind: Secret
        name: gateway-tls-secret
    allowedRoutes:
      namespaces:
        from: Same
EOF

# Chờ PROGRAMMED=True
kubectl get gateway main-gateway -n gateway-lab -w
```

## Bước 6: HTTPRoute

```bash
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: app-route
  namespace: gateway-lab
spec:
  parentRefs:
  - name: main-gateway
    namespace: gateway-lab
    sectionName: https
  hostnames:
  - app.gateway-lab.local
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: nginx-service
      port: 80
EOF
```

## Bước 7: Test

```bash
# NGF tạo Service riêng cho mỗi Gateway
kubectl get svc -n nginx-gateway

HTTPS_PORT=$(kubectl get svc -n nginx-gateway \
  -o jsonpath='{.items[0].spec.ports[?(@.port==443)].nodePort}')
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

curl -k -H "Host: app.gateway-lab.local" https://$NODE_IP:$HTTPS_PORT/
```

---

## So sánh Ingress vs Gateway API

| | Ingress | Gateway API |
|---|---|---|
| TLS config | `spec.tls` trong Ingress | `listeners[].tls` trong Gateway |
| Routing rules | `spec.rules` trong Ingress | HTTPRoute riêng biệt |
| Controller link | `ingressClassName` | `gatewayClassName` |
| Role | Một resource | Tách Gateway (admin) + HTTPRoute (dev) |
| Traffic split | Annotation | Native `weight` |
