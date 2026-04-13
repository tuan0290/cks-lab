# Giải pháp mẫu – Lab 2.4: Restrict API Server Access

> **Lưu ý:** Chỉ đọc sau khi đã tự thử thực hành. Việc tự giải quyết vấn đề giúp bạn ghi nhớ tốt hơn nhiều so với đọc đáp án.

---

## Bước 1: Kiểm tra cấu hình hiện tại

```bash
# Xem tất cả flag của kube-apiserver
kubectl get pod kube-apiserver-$(hostname) -n kube-system \
  -o jsonpath='{.spec.containers[0].command}' | tr ',' '\n' | sort

# Lọc các flag liên quan
kubectl get pod kube-apiserver-$(hostname) -n kube-system \
  -o jsonpath='{.spec.containers[0].command}' | tr ',' '\n' | \
  grep -E "anonymous-auth|admission-plugins|authorization-mode"
```

---

## Bước 2: Backup manifest

```bash
sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/kube-apiserver.yaml.bak
```

---

## Bước 3: Sửa kube-apiserver manifest

```bash
sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml
```

Ví dụ manifest sau khi sửa (chỉ hiển thị phần command):

```yaml
spec:
  containers:
  - command:
    - kube-apiserver
    - --advertise-address=192.168.1.10
    - --allow-privileged=true
    - --anonymous-auth=false                              # THÊM/SỬA
    - --authorization-mode=Node,RBAC                     # XÁC NHẬN có Node,RBAC
    - --client-ca-file=/etc/kubernetes/pki/ca.crt
    - --enable-admission-plugins=NodeRestriction          # THÊM/SỬA
    - --enable-bootstrap-token-auth=true
    - --etcd-cafile=/etc/kubernetes/pki/etcd/ca.crt
    - --etcd-certfile=/etc/kubernetes/pki/apiserver-etcd-client.crt
    - --etcd-keyfile=/etc/kubernetes/pki/apiserver-etcd-client.key
    - --etcd-servers=https://127.0.0.1:2379
    - --kubelet-client-certificate=/etc/kubernetes/pki/apiserver-kubelet-client.crt
    - --kubelet-client-key=/etc/kubernetes/pki/apiserver-kubelet-client.key
    - --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname
    - --proxy-client-cert-file=/etc/kubernetes/pki/front-proxy-client.crt
    - --proxy-client-key-file=/etc/kubernetes/pki/front-proxy-client.key
    - --requestheader-allowed-names=front-proxy-client
    - --requestheader-client-ca-file=/etc/kubernetes/pki/front-proxy-ca.crt
    - --requestheader-extra-headers-prefix=X-Remote-Extra-
    - --requestheader-group-headers=X-Remote-Group
    - --requestheader-username-headers=X-Remote-User
    - --secure-port=6443
    - --service-account-issuer=https://kubernetes.default.svc.cluster.local
    - --service-account-key-file=/etc/kubernetes/pki/sa.pub
    - --service-account-signing-key-file=/etc/kubernetes/pki/sa.key
    - --service-cluster-ip-range=10.96.0.0/12
    - --tls-cert-file=/etc/kubernetes/pki/apiserver.crt
    - --tls-private-key-file=/etc/kubernetes/pki/apiserver.key
```

**Lưu ý về --enable-admission-plugins:**

Nếu đã có flag này với các plugin khác, thêm NodeRestriction vào danh sách:
```yaml
# Trước:
- --enable-admission-plugins=PodSecurity

# Sau:
- --enable-admission-plugins=NodeRestriction,PodSecurity
```

---

## Bước 4: Xác nhận kube-apiserver đã restart

```bash
# Chờ 30-60 giây sau khi lưu file
watch kubectl get pods -n kube-system | grep kube-apiserver

# Xác nhận các flag
kubectl get pod kube-apiserver-$(hostname) -n kube-system \
  -o jsonpath='{.spec.containers[0].command}' | tr ',' '\n' | \
  grep -E "anonymous-auth|admission-plugins|authorization-mode"
```

Kết quả mong đợi:
```
--anonymous-auth=false
--authorization-mode=Node,RBAC
--enable-admission-plugins=NodeRestriction
```

---

## Bước 5: Ghi kết quả vào file

```bash
{
  echo "=== API Server Security Check ==="
  echo "Date: $(date)"
  echo "Hostname: $(hostname)"
  echo ""

  echo "--- anonymous-auth ---"
  kubectl get pod kube-apiserver-$(hostname) -n kube-system \
    -o jsonpath='{.spec.containers[0].command}' | tr ',' '\n' | \
    grep "anonymous-auth" || echo "NOT SET (default: true)"

  echo ""
  echo "--- enable-admission-plugins ---"
  kubectl get pod kube-apiserver-$(hostname) -n kube-system \
    -o jsonpath='{.spec.containers[0].command}' | tr ',' '\n' | \
    grep "admission-plugins" || echo "NOT SET"

  echo ""
  echo "--- authorization-mode ---"
  kubectl get pod kube-apiserver-$(hostname) -n kube-system \
    -o jsonpath='{.spec.containers[0].command}' | tr ',' '\n' | \
    grep "authorization-mode" || echo "NOT SET"

  echo ""
  echo "--- NodeRestriction check ---"
  kubectl get pod kube-apiserver-$(hostname) -n kube-system \
    -o jsonpath='{.spec.containers[0].command}' | tr ',' '\n' | \
    grep "NodeRestriction" && echo "NodeRestriction: ENABLED" || echo "NodeRestriction: NOT FOUND"

} > /tmp/api-server-check.txt

echo "Kết quả đã được ghi vào /tmp/api-server-check.txt"
cat /tmp/api-server-check.txt
```

---

## Kiểm tra bổ sung: Xác minh anonymous access bị từ chối

```bash
# Thử truy cập API server không có credentials (phải bị từ chối)
APISERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
curl -k "$APISERVER/api/v1/namespaces" 2>/dev/null | python3 -m json.tool | grep -E "status|message|reason"
```

Kết quả mong đợi khi `--anonymous-auth=false`:
```json
{
  "status": "Failure",
  "message": "Unauthorized",
  "reason": "Unauthorized",
  "code": 401
}
```

---

## Tham khảo

- [kube-apiserver Flags](https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/)
- [NodeRestriction Admission Plugin](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#noderestriction)
- [Authorization Modes](https://kubernetes.io/docs/reference/access-authn-authz/authorization/)
- [Authenticating](https://kubernetes.io/docs/reference/access-authn-authz/authentication/)
