# Giải pháp mẫu – Lab 1.1: NetworkPolicy Default Deny

> **Lưu ý:** Chỉ đọc sau khi đã tự thử thực hành. Việc tự giải quyết vấn đề giúp bạn ghi nhớ tốt hơn nhiều so với đọc đáp án.

---

## NetworkPolicy 1: Chặn toàn bộ Ingress trong `lab-network`

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: lab-network
spec:
  podSelector: {}       # Áp dụng cho tất cả pod trong namespace
  policyTypes:
  - Ingress             # Chỉ kiểm soát ingress traffic
                        # Không có ingress rules = chặn tất cả ingress
```

**Giải thích:**
- `podSelector: {}` — selector rỗng khớp với **tất cả** pod trong namespace `lab-network`
- `policyTypes: [Ingress]` — khai báo policy này kiểm soát ingress traffic
- Không có trường `ingress:` — đồng nghĩa với chặn toàn bộ ingress traffic

Áp dụng:
```bash
kubectl apply -f deny-all-ingress.yaml
```

---

## NetworkPolicy 2: Chặn toàn bộ Egress trong `lab-network`

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-egress
  namespace: lab-network
spec:
  podSelector: {}       # Áp dụng cho tất cả pod trong namespace
  policyTypes:
  - Egress              # Chỉ kiểm soát egress traffic
                        # Không có egress rules = chặn tất cả egress
```

**Giải thích:**
- Tương tự deny-all-ingress nhưng cho hướng egress (traffic đi ra)
- Kết hợp cả hai policy tạo ra **full isolation** cho namespace `lab-network`

Áp dụng:
```bash
kubectl apply -f deny-all-egress.yaml
```

---

## NetworkPolicy 3: Cho phép traffic từ `frontend-ns` đến `backend-ns` port 8080

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: backend-ns          # Policy này nằm trong namespace đích (backend-ns)
spec:
  podSelector: {}                # Áp dụng cho tất cả pod trong backend-ns
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: frontend-ns   # Chỉ cho phép từ namespace frontend-ns
    ports:
    - protocol: TCP
      port: 8080                 # Chỉ cho phép trên port 8080
```

**Giải thích:**
- Policy này đặt trong `backend-ns` — namespace nhận traffic
- `namespaceSelector` dùng label tự động `kubernetes.io/metadata.name` (có từ K8s 1.21+)
- Chỉ traffic từ `frontend-ns` đến port 8080 mới được phép; tất cả traffic khác bị chặn

Áp dụng:
```bash
kubectl apply -f allow-frontend-to-backend.yaml
```

---

## Kiểm tra kết quả

```bash
# Xem tất cả NetworkPolicy
kubectl get networkpolicy -n lab-network
kubectl get networkpolicy -n backend-ns

# Mô tả chi tiết
kubectl describe networkpolicy deny-all-ingress -n lab-network
kubectl describe networkpolicy allow-frontend-to-backend -n backend-ns

# Chạy verify script
bash verify.sh
```

---

## Biến thể nâng cao: Kết hợp namespaceSelector và podSelector

Nếu muốn giới hạn thêm theo pod label (không chỉ namespace):

```yaml
ingress:
- from:
  - namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: frontend-ns
    podSelector:                   # AND với namespaceSelector (cùng một phần tử trong mảng)
      matchLabels:
        app: frontend
```

**Lưu ý quan trọng về AND vs OR:**

```yaml
# AND: Pod phải ở trong frontend-ns VÀ có label app=frontend
ingress:
- from:
  - namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: frontend-ns
    podSelector:
      matchLabels:
        app: frontend

# OR: Pod ở trong frontend-ns HOẶC có label app=frontend (bất kể namespace)
ingress:
- from:
  - namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: frontend-ns
  - podSelector:
      matchLabels:
        app: frontend
```

Sự khác biệt nằm ở chỗ `namespaceSelector` và `podSelector` có nằm trong **cùng một phần tử** của mảng `from` hay không.

---

## Tham khảo

- [NetworkPolicy Concepts](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [NetworkPolicy Recipes](https://github.com/ahmetb/kubernetes-network-policy-recipes)
