# Lab 1.1 – NetworkPolicy Default Deny

**Domain:** Cluster Setup (15%)
**Thời gian ước tính:** 20 phút
**Độ khó:** Trung bình

---

## Mục tiêu

- Tạo NetworkPolicy chặn toàn bộ ingress và egress mặc định trong namespace `lab-network`
- Tạo NetworkPolicy cho phép traffic có chọn lọc từ namespace `frontend` đến namespace `backend` trên port 80
- Hiểu cách namespace selector và pod selector hoạt động trong NetworkPolicy

---

## Lý thuyết

### NetworkPolicy là gì?

Trong Kubernetes, mặc định **tất cả các pod đều có thể giao tiếp với nhau** — không có tường lửa nào ngăn cách. Điều này tiện lợi khi phát triển nhưng rất nguy hiểm trong môi trường production: nếu một pod bị tấn công, kẻ tấn công có thể dễ dàng di chuyển sang các pod khác trong cluster.

**NetworkPolicy** là tài nguyên Kubernetes cho phép bạn định nghĩa **quy tắc tường lửa ở tầng mạng** cho các pod. Nó hoạt động như một "firewall rule" — chỉ cho phép traffic được khai báo rõ ràng, chặn tất cả còn lại.

> **Lưu ý quan trọng:** NetworkPolicy chỉ hoạt động khi CNI plugin hỗ trợ (Calico, Cilium, Weave...). Nếu dùng CNI không hỗ trợ (như Flannel mặc định), NetworkPolicy sẽ được tạo nhưng không có tác dụng.

### Ingress và Egress là gì?

```
Internet → [Ingress] → Pod → [Egress] → Internet/Pod khác
```

- **Ingress**: Traffic đi **vào** pod (ai được phép gọi đến pod này?)
- **Egress**: Traffic đi **ra** từ pod (pod này được phép gọi đến đâu?)

Mỗi NetworkPolicy có thể kiểm soát một hoặc cả hai hướng thông qua `policyTypes`.

### Default Deny là gì và tại sao cần?

**Default Deny** là pattern bảo mật: chặn tất cả traffic trước, sau đó chỉ mở những gì thực sự cần thiết. Đây là nguyên tắc **least privilege** áp dụng cho tầng mạng.

Cách tạo default deny:
```yaml
spec:
  podSelector: {}   # {} = áp dụng cho TẤT CẢ pod trong namespace
  policyTypes:
  - Ingress         # Khai báo kiểm soát ingress
                    # Không có rules = chặn tất cả ingress
```

Khi `policyTypes` có `Ingress` nhưng không có `ingress:` rules → **chặn toàn bộ ingress**.
Khi `policyTypes` có `Egress` nhưng không có `egress:` rules → **chặn toàn bộ egress**.

### namespaceSelector và podSelector

NetworkPolicy có thể chọn nguồn/đích traffic theo:

| Selector | Ý nghĩa | Ví dụ |
|----------|---------|-------|
| `namespaceSelector` | Chọn theo namespace | Cho phép từ namespace `frontend` |
| `podSelector` | Chọn theo label của pod | Cho phép từ pod có label `app: web` |
| Kết hợp cả hai | AND logic | Pod có label X **và** ở namespace Y |

**AND vs OR — điểm dễ nhầm nhất:**
```yaml
# AND: pod phải ở frontend-ns VÀ có label app=web
from:
- namespaceSelector:
    matchLabels:
      kubernetes.io/metadata.name: frontend-ns
  podSelector:          # cùng phần tử → AND
    matchLabels:
      app: web

# OR: pod ở frontend-ns HOẶC có label app=web
from:
- namespaceSelector:
    matchLabels:
      kubernetes.io/metadata.name: frontend-ns
- podSelector:          # phần tử riêng → OR
    matchLabels:
      app: web
```

### NetworkPolicy là stateless

NetworkPolicy **không** tự động cho phép traffic chiều ngược lại. Nếu bạn chặn egress của frontend, frontend không thể gọi đến backend — dù backend có mở ingress hay không. Cần mở **cả 2 chiều** để kết nối thông.

---

## Bối cảnh

Bạn là kỹ sư bảo mật tại một công ty fintech. Hệ thống microservice đang chạy trong Kubernetes cluster với nhiều namespace. Theo yêu cầu bảo mật, mọi traffic giữa các namespace phải bị chặn theo mặc định (default deny), và chỉ các kết nối được phê duyệt rõ ràng mới được phép.

Nhiệm vụ của bạn là cấu hình NetworkPolicy cho namespace `lab-network` để:
1. Chặn toàn bộ ingress traffic mặc định
2. Chặn toàn bộ egress traffic mặc định
3. Chỉ cho phép traffic từ namespace `frontend-ns` đến namespace `backend-ns` trên port 80

---

## Yêu cầu môi trường

- Kubernetes cluster >= 1.29 với CNI hỗ trợ NetworkPolicy (Calico, Cilium, Weave, v.v.)
- `kubectl` đã được cấu hình và kết nối đến cluster
- Quyền tạo namespace và NetworkPolicy

Chạy script khởi tạo môi trường:

```bash
bash setup.sh
```

---

## Các bước thực hiện

### Bước 1: Kiểm tra môi trường

```bash
# Xác nhận các namespace đã được tạo
kubectl get namespaces | grep -E 'lab-network|frontend-ns|backend-ns'

# Xem các pod đang chạy
kubectl get pods -n backend-ns
kubectl get pods -n frontend-ns
```

### Bước 2: Tạo NetworkPolicy chặn toàn bộ ingress trong `lab-network`

Tạo file `deny-all-ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: lab-network
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```

Áp dụng:

```bash
kubectl apply -f deny-all-ingress.yaml
```

### Bước 3: Tạo NetworkPolicy chặn toàn bộ egress trong `lab-network`

Tạo file `deny-all-egress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-egress
  namespace: lab-network
spec:
  podSelector: {}
  policyTypes:
  - Egress
```

Áp dụng:

```bash
kubectl apply -f deny-all-egress.yaml
```

### Bước 4: Tạo NetworkPolicy cho phép traffic cụ thể

Tạo NetworkPolicy cho phép traffic từ `frontend-ns` đến `backend-ns` trên port 80:

```bash
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: backend-ns
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: frontend-ns
    ports:
    - protocol: TCP
      port: 80
EOF
```

### Bước 5: Kiểm tra NetworkPolicy đã được tạo

```bash
kubectl get networkpolicy -n lab-network
kubectl get networkpolicy -n backend-ns
kubectl describe networkpolicy deny-all-ingress -n lab-network
```

### Bước 6: Xác minh kết quả

```bash
bash verify.sh
```

---

## Tiêu chí kiểm tra

- [ ] NetworkPolicy `deny-all-ingress` tồn tại trong namespace `lab-network`
- [ ] NetworkPolicy `deny-all-egress` tồn tại trong namespace `lab-network`
- [ ] Có NetworkPolicy cho phép traffic từ `frontend-ns` đến `backend-ns` trên port 80

---

## Gợi ý

<details>
<summary>Gợi ý 1: podSelector rỗng có nghĩa là gì?</summary>

`podSelector: {}` (selector rỗng) áp dụng policy cho **tất cả** pod trong namespace đó. Đây là cách tạo default deny policy hiệu quả nhất.

</details>

<details>
<summary>Gợi ý 2: Cách label namespace để dùng namespaceSelector</summary>

Từ Kubernetes 1.21+, mỗi namespace tự động có label `kubernetes.io/metadata.name: <tên-namespace>`. Bạn có thể dùng label này trực tiếp trong `namespaceSelector` mà không cần thêm label thủ công.

```bash
kubectl get namespace frontend-ns --show-labels
```

</details>

<details>
<summary>Gợi ý 3: Thứ tự áp dụng NetworkPolicy</summary>

NetworkPolicy là **additive** — nhiều policy cùng áp dụng cho một pod sẽ được OR với nhau. Không có thứ tự ưu tiên. Nếu bất kỳ policy nào cho phép traffic, traffic đó được phép.

</details>

---

## Giải pháp mẫu

<details>
<summary>Xem giải pháp đầy đủ (chỉ mở sau khi đã thử)</summary>

Xem file [solution/solution.md](solution/solution.md) để có YAML đầy đủ và giải thích chi tiết.

</details>

---

## Giải thích

### Tại sao cần Default Deny?

Theo mặc định, Kubernetes **không** hạn chế traffic giữa các pod. Bất kỳ pod nào cũng có thể giao tiếp với bất kỳ pod nào khác trong cluster. Đây là rủi ro bảo mật nghiêm trọng trong môi trường production.

Default deny policy thực hiện nguyên tắc **least privilege** ở tầng mạng:
- Chặn tất cả traffic trước
- Chỉ mở những kết nối thực sự cần thiết

### Ingress vs Egress

- **Ingress**: Traffic đi vào pod (ai được phép gọi đến pod này?)
- **Egress**: Traffic đi ra từ pod (pod này được phép gọi đến đâu?)

Cần chặn cả hai hướng để có bảo mật toàn diện.

### Namespace Selector vs Pod Selector

- `namespaceSelector`: Chọn traffic từ/đến namespace cụ thể
- `podSelector`: Chọn traffic từ/đến pod có label cụ thể
- Kết hợp cả hai: Traffic phải thỏa mãn **cả hai** điều kiện (AND logic)

---

## Tham khảo

- [Kubernetes NetworkPolicy Documentation](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [NetworkPolicy Editor (visualizer)](https://editor.networkpolicy.io/)
- [CKS Exam Curriculum – Cluster Setup](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/)
- [Calico NetworkPolicy Tutorial](https://docs.tigera.io/calico/latest/network-policy/get-started/kubernetes-policy/kubernetes-policy-basic)

---

## Hỏi & Đáp

### Q1: Nếu deny ingress và egress cả 2 namespace frontend và backend, nhưng chỉ mở ingress phía backend — frontend có gọi được đến backend không?

**Không.** Frontend sẽ **không** gọi được đến backend trong trường hợp này.

**Giải thích:**

NetworkPolicy trong Kubernetes là **stateless** và hoạt động **độc lập trên từng namespace**. Một kết nối TCP thành công cần **cả 2 chiều đều được phép**:

```
frontend pod  ──[egress]──►  backend pod  ──[ingress]──►  nhận request
```

Khi `frontend-ns` có `deny-all-egress`, traffic bị chặn **ngay tại nguồn** — packet không bao giờ rời khỏi frontend pod. Dù backend có mở ingress hay không cũng không có tác dụng vì packet chưa đến được backend.

**Để kết nối thông, cần mở đủ cả 2 phía:**

| Namespace | Policy cần có |
|-----------|--------------|
| `frontend-ns` | Egress cho phép đến `backend-ns` port 80 |
| `backend-ns` | Ingress cho phép từ `frontend-ns` port 80 |

**Ví dụ cấu hình đúng:**

```yaml
# Phía frontend-ns: mở egress đến backend-ns
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-egress-to-backend
  namespace: frontend-ns
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: backend-ns
    ports:
    - protocol: TCP
      port: 80
```

```yaml
# Phía backend-ns: mở ingress từ frontend-ns
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-ingress-from-frontend
  namespace: backend-ns
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: frontend-ns
    ports:
    - protocol: TCP
      port: 80
```

> **Lưu ý quan trọng:** Đừng quên mở thêm egress DNS (UDP port 53) cho frontend nếu nó cần resolve hostname — nếu không, DNS lookup cũng sẽ bị chặn và kết nối thất bại ngay cả khi đã mở egress đến backend.

```yaml
# Thêm vào egress của frontend-ns để DNS hoạt động
egress:
- ports:
  - protocol: UDP
    port: 53
```

---

### Q2: Làm sao chứng minh frontend gọi được (hoặc không gọi được) đến backend?

**Bước 1: Lấy IP của backend pod**

```bash
BACKEND_IP=$(kubectl get pod backend-pod -n backend-ns -o jsonpath='{.status.podIP}')
echo "Backend IP: $BACKEND_IP"
```

**Bước 2: Test kết nối từ frontend pod (1 lệnh, không cần vào shell)**

```bash
# Test port 80 — nginx lắng nghe ở đây
kubectl exec frontend-pod -n frontend-ns -- wget -qO- --timeout=3 http://$BACKEND_IP:80

# Hoặc dùng nc để test TCP connect thuần (không cần HTTP response)
kubectl exec frontend-pod -n frontend-ns -- nc -zv $BACKEND_IP 80
```

---

**Kết quả mong đợi theo từng trường hợp:**

| Tình huống | Kết quả | Giải thích |
|-----------|---------|------------|
| Chưa có NetworkPolicy nào | ✅ Thông — HTML nginx | Mặc định K8s cho phép tất cả |
| Chỉ deny-all-egress ở `frontend-ns` | ❌ Timeout | Packet bị chặn ngay tại frontend, không đi được |
| Chỉ deny-all-ingress ở `backend-ns` | ❌ Timeout | Packet đến nơi nhưng bị chặn tại backend |
| Mở egress `frontend-ns` + ingress `backend-ns` port 80 | ✅ Thông — HTML nginx | Cả 2 chiều được phép |

---

**Output khi KHÔNG thông:**

```
wget: download timed out
# hoặc
nc: connect to 10.244.1.5 port 80 (tcp) timed out: Operation timed out
```

**Output khi THÔNG:**

```html
<!DOCTYPE html>
<html>
<head><title>Welcome to nginx!</title></head>
...
```

---

**Tip: Test nhanh bằng pod tạm (không cần pod có sẵn)**

```bash
# Tạo pod curl tạm trong frontend-ns, test xong tự xóa
kubectl run test-curl -n frontend-ns \
  --image=curlimages/curl:8.5.0 \
  --restart=Never \
  --rm -it \
  -- curl -m 3 http://$BACKEND_IP:80
```
