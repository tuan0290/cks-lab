# Giải pháp mẫu – Lab 1.5: Authentication với Certificate và ServiceAccount

---

## Tạo user bằng Certificate (đầy đủ)

```bash
mkdir -p /tmp/user-cert-lab && cd /tmp/user-cert-lab

# 1. Tạo private key
openssl genrsa -out dev-user.key 2048

# 2. Tạo CSR
openssl req -new -key dev-user.key -out dev-user.csr \
  -subj "/CN=dev-user/O=developers"

# 3. Submit CSR lên Kubernetes
CSR_BASE64=$(cat dev-user.csr | base64 | tr -d '\n')
kubectl apply -f - <<EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: dev-user
spec:
  request: ${CSR_BASE64}
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400
  usages:
  - client auth
EOF

# 4. Approve
kubectl certificate approve dev-user

# 5. Lấy certificate
kubectl get csr dev-user -o jsonpath='{.status.certificate}' | base64 -d > dev-user.crt

# 6. Xác minh
openssl x509 -in dev-user.crt -noout -subject
# subject=CN=dev-user, O=developers
```

## Tạo kubeconfig

```bash
CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')
CLUSTER_SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
CA_DATA=$(kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')

cat > dev-user.kubeconfig <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: ${CA_DATA}
    server: ${CLUSTER_SERVER}
  name: ${CLUSTER_NAME}
contexts:
- context:
    cluster: ${CLUSTER_NAME}
    user: dev-user
    namespace: dev-ns
  name: dev-user-context
current-context: dev-user-context
users:
- name: dev-user
  user:
    client-certificate: /tmp/user-cert-lab/dev-user.crt
    client-key: /tmp/user-cert-lab/dev-user.key
EOF
```

## Cấp quyền RBAC

```bash
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: dev-ns
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: dev-user-pod-reader
  namespace: dev-ns
subjects:
- kind: User
  name: dev-user
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
EOF
```

## Test quyền

```bash
export KUBECONFIG=/tmp/user-cert-lab/dev-user.kubeconfig

kubectl get pods -n dev-ns          # ✅ Thành công
kubectl get secrets -n dev-ns       # ❌ Forbidden
kubectl get pods -n default         # ❌ Forbidden
kubectl delete pod sample-app -n dev-ns  # ❌ Forbidden

unset KUBECONFIG
```

## ServiceAccount với automount disabled

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: restricted-sa
  namespace: dev-ns
automountServiceAccountToken: false
EOF

# Xác minh
kubectl get sa restricted-sa -n dev-ns -o jsonpath='{.automountServiceAccountToken}'
# false
```

## Revoke quyền user

```bash
# Cách nhanh nhất: xóa RoleBinding
kubectl delete rolebinding dev-user-pod-reader -n dev-ns

# User vẫn có certificate hợp lệ nhưng không có quyền gì
export KUBECONFIG=/tmp/user-cert-lab/dev-user.kubeconfig
kubectl get pods -n dev-ns  # ❌ Forbidden (không còn RoleBinding)
unset KUBECONFIG
```
