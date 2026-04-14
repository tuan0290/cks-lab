# Lab 4.5 – Pod-to-Pod Encryption với Cilium

**Domain:** Minimize Microservice Vulnerabilities (20%)
**Thời gian ước tính:** 25 phút
**Độ khó:** Nâng cao

---

## Mục tiêu

- Cấu hình Cilium để bật WireGuard encryption cho pod-to-pod traffic
- Tạo CiliumNetworkPolicy cho phép traffic giữa 2 pod trong namespace `cilium-lab`
- Xác minh encryption đang hoạt động bằng cách kiểm tra trạng thái Cilium

---

## Lý thuyết

### Tại sao cần Pod-to-Pod Encryption?

Mặc định, traffic giữa các pod trong Kubernetes cluster đi qua mạng nội bộ **không được mã hóa**. Điều này có nghĩa là:
- Attacker có quyền truy cập network infrastructure có thể sniff traffic
- Trong môi trường multi-tenant, tenant này có thể đọc traffic của tenant khác
- Compliance requirements (PCI-DSS, HIPAA) thường yêu cầu mã hóa data in transit

### Cilium là gì?

**Cilium** là CNI plugin cho Kubernetes sử dụng **eBPF (extended Berkeley Packet Filter)** — công nghệ kernel-level cho phép lập trình network behavior mà không cần kernel module. Cilium cung cấp:
- NetworkPolicy nâng cao (L7 filtering)
- Pod-to-Pod encryption (WireGuard hoặc IPSec)
- Observability (Hubble)

### WireGuard vs IPSec

Cilium hỗ trợ 2 phương thức encryption:

| | WireGuard | IPSec |
|---|---|---|
| Kernel requirement | >= 5.6 | >= 4.x |
| Performance | Cao hơn | Thấp hơn |
| Key management | Tự động | Cần quản lý thủ công |
| Audit | Đơn giản hơn | Phức tạp hơn |

### Bật WireGuard encryption trên Cilium

```bash
# Dùng Helm
helm upgrade cilium cilium/cilium \
  --namespace kube-system \
  --reuse-values \
  --set encryption.enabled=true \
  --set encryption.type=wireguard

# Hoặc patch ConfigMap
kubectl patch configmap cilium-config -n kube-system \
  --type merge \
  -p '{"data":{"enable-wireguard":"true"}}'

kubectl rollout restart daemonset/cilium -n kube-system
```

### CiliumNetworkPolicy

Cilium có CRD riêng `CiliumNetworkPolicy` mạnh hơn NetworkPolicy tiêu chuẩn:

```yaml
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: allow-client-to-server
  namespace: cilium-lab
spec:
  endpointSelector:      # Tương đương podSelector
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
```

### Kiểm tra encryption status

```bash
# Dùng cilium CLI
cilium encrypt status

# Hoặc exec vào Cilium pod
kubectl exec -n kube-system -it <cilium-pod> -- cilium status | grep -i encrypt
```

---

## Bối cảnh

Bạn là kỹ sư bảo mật tại một công ty xử lý dữ liệu nhạy cảm. Theo yêu cầu compliance, tất cả traffic giữa các pod trong cluster phải được mã hóa — kể cả traffic trong cùng một node. Cilium hỗ trợ WireGuard encryption ở tầng kernel, cung cấp hiệu suất cao và bảo mật mạnh.

Nhiệm vụ của bạn:
1. Bật WireGuard encryption trên Cilium
2. Tạo namespace `cilium-lab` và deploy 2 test pod
3. Tạo CiliumNetworkPolicy cho phép traffic giữa 2 pod
4. Xác minh encryption đang hoạt động

---

## Yêu cầu môi trường

- Kubernetes cluster >= 1.29 với Cilium CNI đã được cài đặt
- `kubectl` đã được cấu hình và kết nối đến cluster
- `cilium` CLI đã được cài đặt (tùy chọn nhưng khuyến nghị)
- Kernel >= 5.6 trên các node (yêu cầu của WireGuard)

Kiểm tra Cilium đã được cài đặt:
```bash
kubectl get pods -n kube-system -l k8s-app=cilium
```

Cài đặt Cilium CLI (nếu chưa có):
```bash
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-amd64.tar.gz
sudo tar xzvf cilium-linux-amd64.tar.gz -C /usr/local/bin
```

Chạy script khởi tạo môi trường:
```bash
bash setup.sh
```

---

## Các bước thực hiện

### Bước 1: Kiểm tra trạng thái Cilium hiện tại

```bash
# Kiểm tra Cilium pods
kubectl get pods -n kube-system -l k8s-app=cilium

# Kiểm tra trạng thái Cilium (nếu có cilium CLI)
cilium status

# Kiểm tra encryption mode hiện tại
kubectl get configmap cilium-config -n kube-system -o yaml | grep -E "encryption|wireguard"
```

### Bước 2: Bật WireGuard encryption trên Cilium

**Phương pháp 1: Dùng Helm (nếu Cilium được cài bằng Helm)**

```bash
helm upgrade cilium cilium/cilium \
  --namespace kube-system \
  --reuse-values \
  --set encryption.enabled=true \
  --set encryption.type=wireguard
```

**Phương pháp 2: Patch ConfigMap trực tiếp**

```bash
kubectl patch configmap cilium-config -n kube-system \
  --type merge \
  -p '{"data":{"enable-wireguard":"true"}}'

# Restart Cilium DaemonSet để áp dụng thay đổi
kubectl rollout restart daemonset/cilium -n kube-system
kubectl rollout status daemonset/cilium -n kube-system
```

### Bước 3: Xác minh WireGuard đang hoạt động

```bash
# Kiểm tra WireGuard interface trên node
kubectl get pods -n kube-system -l k8s-app=cilium -o name | head -1 | \
  xargs -I{} kubectl exec {} -n kube-system -- cilium status | grep -i "wireguard\|encryption"

# Hoặc dùng cilium CLI
cilium encrypt status
```

### Bước 4: Tạo namespace và deploy test pods

```bash
# Namespace đã được tạo bởi setup.sh
kubectl get namespace cilium-lab

# Xem các pod đã được deploy
kubectl get pods -n cilium-lab
```

### Bước 5: Tạo CiliumNetworkPolicy

Tạo policy cho phép traffic giữa pod `client` và pod `server` trong namespace `cilium-lab`:

```bash
kubectl apply -f - <<EOF
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: allow-client-to-server
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
EOF
```

### Bước 6: Kiểm tra connectivity

```bash
# Test kết nối từ client đến server
CLIENT_POD=$(kubectl get pod -n cilium-lab -l app=client -o name | head -1)
SERVER_IP=$(kubectl get pod -n cilium-lab -l app=server -o jsonpath='{.items[0].status.podIP}')

kubectl exec -n cilium-lab "$CLIENT_POD" -- curl -s --max-time 5 "http://$SERVER_IP" | head -5
```

### Bước 7: Kiểm tra kết quả

```bash
bash verify.sh
```

---

## Tiêu chí kiểm tra

- [ ] Cilium đang chạy trong namespace `kube-system`
- [ ] CiliumNetworkPolicy tồn tại trong namespace `cilium-lab`
- [ ] Cilium encryption mode được bật (WireGuard hoặc IPSec)

---

## Gợi ý

<details>
<summary>Gợi ý 1: Kiểm tra kernel version có hỗ trợ WireGuard không</summary>

WireGuard yêu cầu Linux kernel >= 5.6. Kiểm tra:

```bash
# Trên node
uname -r

# Nếu kernel < 5.6, dùng IPSec thay thế:
kubectl patch configmap cilium-config -n kube-system \
  --type merge \
  -p '{"data":{"enable-ipsec":"true","ipsec-key-file":"/etc/ipsec/keys"}}'
```

</details>

<details>
<summary>Gợi ý 2: CiliumNetworkPolicy vs NetworkPolicy</summary>

CiliumNetworkPolicy là CRD của Cilium, mạnh hơn NetworkPolicy tiêu chuẩn:
- Hỗ trợ L7 filtering (HTTP, gRPC, DNS)
- Hỗ trợ FQDN-based policies
- Hỗ trợ filtering theo service account

Cú pháp `endpointSelector` tương đương `podSelector` trong NetworkPolicy tiêu chuẩn.

</details>

<details>
<summary>Gợi ý 3: Xác minh encryption bằng tcpdump</summary>

Để xác minh traffic thực sự được mã hóa, bạn có thể capture traffic trên node:

```bash
# Trên node, capture traffic giữa 2 pod
# Traffic WireGuard sẽ xuất hiện trên UDP port 51871
tcpdump -i any udp port 51871 -c 10

# Nếu thấy UDP traffic thay vì plaintext HTTP, encryption đang hoạt động
```

</details>

---

## Giải pháp mẫu

<details>
<summary>Xem giải pháp đầy đủ (chỉ mở sau khi đã thử)</summary>

Xem file [solution/solution.md](solution/solution.md) để có hướng dẫn chi tiết về Cilium WireGuard config và CiliumNetworkPolicy.

</details>

---

## Giải thích

### Tại sao cần Pod-to-Pod Encryption?

Mặc định, traffic giữa các pod trong Kubernetes cluster đi qua mạng nội bộ không được mã hóa. Điều này có nghĩa là:
- Attacker có quyền truy cập vào network infrastructure có thể sniff traffic
- Trong môi trường multi-tenant, tenant này có thể đọc traffic của tenant khác
- Compliance requirements (PCI-DSS, HIPAA) thường yêu cầu mã hóa data in transit

### WireGuard vs IPSec

Cilium hỗ trợ hai phương thức encryption:

| | WireGuard | IPSec |
|---|---|---|
| Kernel requirement | >= 5.6 | >= 4.x |
| Performance | Cao hơn | Thấp hơn |
| Key management | Tự động | Cần quản lý thủ công |
| Audit | Ít phức tạp hơn | Phức tạp hơn |

### CiliumNetworkPolicy

CKS exam (từ 10/2024) nhấn mạnh Cilium như một phần của "Minimize Microservice Vulnerabilities". CiliumNetworkPolicy cung cấp:
- **L3/L4 filtering**: Tương tự NetworkPolicy tiêu chuẩn
- **L7 filtering**: Kiểm tra HTTP method, path, headers
- **Identity-based**: Dựa trên Cilium identity thay vì IP

---

## Tham khảo

- [Cilium WireGuard Encryption](https://docs.cilium.io/en/stable/security/network/encryption-wireguard/)
- [CiliumNetworkPolicy Reference](https://docs.cilium.io/en/stable/network/kubernetes/policy/#ciliumnetworkpolicy)
- [Cilium IPSec Encryption](https://docs.cilium.io/en/stable/security/network/encryption-ipsec/)
- [CKS Exam Curriculum – Microservice Vulnerabilities](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/)
