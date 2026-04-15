# Giải pháp mẫu – Lab 1.6: Gateway API với TLS

---

## Bước 1: Cài Gateway API CRDs

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml

kubectl get crd | grep gateway.networking.k8s.io
# gatewayclasses.gateway.networking.k8s.io
# gateways.gateway.networking.k8s.io
# httproutes.gateway.networking.k8s.io
```

## Bước 2: Cài NGINX Gateway Fabric

```bash
helm repo add nginx-gateway https://helm.nginx.com/stable
helm repo update

helm install nginx-gateway nginx-gateway/nginx-gateway-fabric \
  --namespace nginx-gateway \
  --create-namespace \
  --set service.type=NodePort \
  --set service.nodePorts.http=31080 \
  --set service.nodePorts.https=31443

kubectl wait --namespace nginx-gateway \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=nginx-gateway-fabric \
  --timeout=120s
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
HTTPS_PORT=$(kubectl get svc -n nginx-gateway \
  -o jsonpath='{.items[0].spec.ports[?(@.name=="https")].nodePort}')
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
