# Giải pháp mẫu – Lab 4.5: Pod-to-Pod Encryption với Cilium

> **Lưu ý:** Chỉ đọc sau khi đã tự thử thực hành. Việc tự giải quyết vấn đề giúp bạn ghi nhớ tốt hơn nhiều so với đọc đáp án.

---

## Bước 1: Kiểm tra trạng thái Cilium

```bash
# Kiểm tra Cilium pods
kubectl get pods -n kube-system -l k8s-app=cilium

# Kiểm tra version và trạng thái
cilium status --wait

# Kiểm tra encryption hiện tại
kubectl get configmap cilium-config -n kube-system -o yaml | grep -E "wireguard|ipsec|encryption"
```

---

## Bước 2: Bật WireGuard Encryption

### Phương pháp A: Helm (khuyến nghị nếu Cilium được cài bằng Helm)

```bash
helm upgrade cilium cilium/cilium \
  --namespace kube-system \
  --reuse-values \
  --set encryption.enabled=true \
  --set encryption.type=wireguard \
  --set encryption.nodeEncryption=false
```

### Phương pháp B: Patch ConfigMap trực tiếp

```bash
# Bật WireGuard
kubectl patch configmap cilium-config -n kube-system \
  --type merge \
  -p '{"data":{"enable-wireguard":"true"}}'

# Restart Cilium DaemonSet
kubectl rollout restart daemonset/cilium -n kube-system

# Chờ rollout hoàn tất
kubectl rollout status daemonset/cilium -n kube-system --timeout=120s
```

### Xác nhận WireGuard đang hoạt động

```bash
# Kiểm tra qua cilium CLI
cilium encrypt status

# Kiểm tra qua kubectl exec
CILIUM_POD=$(kubectl get pods -n kube-system -l k8s-app=cilium -o name | head -1)
kubectl exec "$CILIUM_POD" -n kube-system -- cilium status | grep -i "encryption\|wireguard"

# Kiểm tra WireGuard interface trên node
kubectl exec "$CILIUM_POD" -n kube-system -- ip link show | grep cilium_wg
```

Kết quả mong đợi:
```
Encryption:       Wireguard   [cilium_wg0 (Pubkey: <key>, Port: 51871, Peers: 1)]
```

---

## Bước 3: Tạo CiliumNetworkPolicy

```yaml
# allow-client-to-server.yaml
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: allow-client-to-server
  namespace: cilium-lab
spec:
  # Áp dụng cho pod có label app=server (pod nhận traffic)
  endpointSelector:
    matchLabels:
      app: server
  # Cho phép ingress từ pod có label app=client
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: client
    toPorts:
    - ports:
      - port: "80"
        protocol: TCP
```

Áp dụng:
```bash
kubectl apply -f allow-client-to-server.yaml
```

Xác nhận:
```bash
kubectl get ciliumnetworkpolicy -n cilium-lab
kubectl describe ciliumnetworkpolicy allow-client-to-server -n cilium-lab
```

---

## Bước 4: Kiểm tra connectivity

```bash
# Lấy IP của server pod
SERVER_IP=$(kubectl get pod server -n cilium-lab -o jsonpath='{.status.podIP}')
echo "Server IP: $SERVER_IP"

# Test kết nối từ client đến server (phải thành công)
kubectl exec -n cilium-lab client -- curl -s --max-time 5 "http://$SERVER_IP" | head -3

# Test kết nối từ server đến client (phải thất bại — không có policy cho phép)
CLIENT_IP=$(kubectl get pod client -n cilium-lab -o jsonpath='{.status.podIP}')
kubectl exec -n cilium-lab server -- wget -q --timeout=5 "http://$CLIENT_IP" -O- 2>&1 || echo "Connection blocked (expected)"
```

---

## Bước 5: Xác minh encryption với tcpdump (nâng cao)

```bash
# Trên node chạy các pod, capture WireGuard traffic
# WireGuard sử dụng UDP port 51871

# Tìm node đang chạy các pod
kubectl get pods -n cilium-lab -o wide

# SSH vào node và capture traffic
# sudo tcpdump -i any udp port 51871 -c 20 -nn

# Nếu thấy UDP/WireGuard traffic thay vì plaintext HTTP, encryption đang hoạt động
```

---

## CiliumNetworkPolicy nâng cao: L7 HTTP filtering

```yaml
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: allow-client-http-get
  namespace: cilium-lab
spec:
  endpointSelector:
    matchLabels:
      app: server
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: client
    toPorts:
    - ports:
      - port: "80"
        protocol: TCP
      rules:
        http:
        - method: "GET"          # Chỉ cho phép GET, không cho phép POST/DELETE
          path: "/"
```

---

## Tham khảo

- [Cilium WireGuard Encryption](https://docs.cilium.io/en/stable/security/network/encryption-wireguard/)
- [CiliumNetworkPolicy Examples](https://docs.cilium.io/en/stable/network/kubernetes/policy/#examples)
- [Cilium Network Policy Editor](https://editor.networkpolicy.io/?id=cilium)
- [Cilium Helm Values](https://docs.cilium.io/en/stable/helm-reference/)
