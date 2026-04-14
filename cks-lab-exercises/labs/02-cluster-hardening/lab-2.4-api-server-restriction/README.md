# Lab 2.4 – Restrict API Server Access

**Domain:** Cluster Hardening (15%)
**Thời gian ước tính:** 20 phút
**Độ khó:** Nâng cao

---

## Mục tiêu

- Cấu hình kube-apiserver để tắt anonymous authentication (`--anonymous-auth=false`)
- Bật NodeRestriction admission plugin để giới hạn quyền của kubelet
- Xác minh `--authorization-mode` bao gồm cả `RBAC` và `Node`
- Ghi kết quả kiểm tra vào `/tmp/api-server-check.txt`

---

## Lý thuyết

### kube-apiserver là gì?

**kube-apiserver** là thành phần trung tâm của Kubernetes — tất cả request (từ kubectl, controller, kubelet, pod...) đều đi qua đây. Bảo mật kube-apiserver là ưu tiên hàng đầu vì nếu bị compromise, toàn bộ cluster bị kiểm soát.

### Anonymous Authentication

Mặc định, kube-apiserver cho phép request **không có credentials** với identity:
- Username: `system:anonymous`
- Group: `system:unauthenticated`

Rủi ro: Nếu RBAC cấu hình sai (vô tình cấp quyền cho `system:unauthenticated`), bất kỳ ai cũng có thể truy cập API mà không cần xác thực.

```bash
# Tắt anonymous auth
--anonymous-auth=false
```

### Authorization Modes

kube-apiserver hỗ trợ nhiều authorization mode. Trong production cần có:

| Mode | Mô tả | Bắt buộc? |
|------|-------|-----------|
| `Node` | Cho phép kubelet authorize các request liên quan đến node/pod của nó | ✅ Bắt buộc |
| `RBAC` | Phân quyền dựa trên Role/ClusterRole | ✅ Bắt buộc |
| `AlwaysAllow` | Cho phép tất cả — không dùng production | ❌ Nguy hiểm |
| `AlwaysDeny` | Từ chối tất cả | ❌ Không dùng được |

```yaml
--authorization-mode=Node,RBAC
# Thứ tự quan trọng: Node được kiểm tra trước RBAC
```

### NodeRestriction Admission Plugin

**NodeRestriction** là admission plugin giới hạn quyền của kubelet:
- Kubelet chỉ có thể sửa Node/Pod object của **chính node đó**
- Không thể sửa Node/Pod của node khác
- Không thể thêm label với prefix `node-restriction.kubernetes.io/`

Tại sao cần? Nếu một node bị compromise, kẻ tấn công không thể dùng kubelet credentials để tấn công các node khác.

```yaml
--enable-admission-plugins=NodeRestriction
```

### Admission Controllers là gì?

**Admission Controllers** là các plugin chạy sau authentication/authorization, trước khi request được lưu vào etcd. Chúng có thể:
- **Validate**: Từ chối request không hợp lệ (ví dụ: NodeRestriction, PSS)
- **Mutate**: Tự động thêm/sửa field (ví dụ: DefaultStorageClass)

```
Request → Authentication → Authorization → Admission Controllers → etcd
```

### Kiểm tra cấu hình kube-apiserver hiện tại

```bash
# Xem tất cả flag đang chạy
kubectl get pod kube-apiserver-$(hostname) -n kube-system \
  -o jsonpath='{.spec.containers[0].command}' | tr ',' '\n' | sort

# Kiểm tra flag cụ thể
kubectl get pod kube-apiserver-$(hostname) -n kube-system \
  -o jsonpath='{.spec.containers[0].command}' | tr ',' '\n' | \
  grep -E "anonymous-auth|admission-plugins|authorization-mode"
```

---

## Bối cảnh

Bạn là kỹ sư bảo mật đang thực hiện hardening cho Kubernetes cluster trước khi đưa vào production. Security audit đã phát hiện kube-apiserver đang cho phép anonymous access và thiếu NodeRestriction admission plugin — hai vấn đề bảo mật nghiêm trọng.

NodeRestriction admission plugin ngăn kubelet trên worker node tự ý sửa đổi Node và Pod objects của node khác, giới hạn blast radius nếu một node bị compromise.

Nhiệm vụ của bạn:
1. Tắt anonymous authentication trên kube-apiserver
2. Bật NodeRestriction admission plugin
3. Xác minh authorization mode bao gồm RBAC và Node
4. Ghi kết quả kiểm tra vào `/tmp/api-server-check.txt`

---

## Yêu cầu môi trường

- Kubernetes cluster >= 1.29 (kubeadm-based cluster)
- `kubectl` đã được cấu hình và kết nối đến cluster
- Quyền SSH và sudo trên control-plane node
- Quyền chỉnh sửa `/etc/kubernetes/manifests/kube-apiserver.yaml`

Chạy script khởi tạo môi trường:
```bash
bash setup.sh
```

---

## Các bước thực hiện

### Bước 1: Kiểm tra cấu hình hiện tại của kube-apiserver

```bash
# Xem tất cả flag đang chạy
kubectl get pod kube-apiserver-$(hostname) -n kube-system \
  -o jsonpath='{.spec.containers[0].command}' | tr ',' '\n' | sort

# Kiểm tra các flag quan trọng
kubectl get pod kube-apiserver-$(hostname) -n kube-system \
  -o jsonpath='{.spec.containers[0].command}' | tr ',' '\n' | \
  grep -E "anonymous-auth|admission-plugins|authorization-mode"
```

### Bước 2: Backup và sửa kube-apiserver manifest

```bash
# Backup
sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/kube-apiserver.yaml.bak

# Chỉnh sửa
sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml
```

### Bước 3: Thêm/sửa các flag bảo mật

Trong phần `command:` của kube-apiserver, đảm bảo có các flag sau:

**Tắt anonymous authentication:**
```yaml
- --anonymous-auth=false
```

**Bật NodeRestriction admission plugin:**
```yaml
- --enable-admission-plugins=NodeRestriction
```

Nếu đã có `--enable-admission-plugins`, thêm `NodeRestriction` vào danh sách:
```yaml
- --enable-admission-plugins=NodeRestriction,PodSecurity
```

**Xác minh authorization mode (thường đã có, không cần sửa):**
```yaml
- --authorization-mode=Node,RBAC
```

### Bước 4: Chờ kube-apiserver khởi động lại

```bash
# Chờ khoảng 30-60 giây sau khi lưu file
sleep 30

# Kiểm tra pod đang chạy
kubectl get pods -n kube-system | grep kube-apiserver

# Xác nhận các flag
kubectl get pod kube-apiserver-$(hostname) -n kube-system \
  -o jsonpath='{.spec.containers[0].command}' | tr ',' '\n' | \
  grep -E "anonymous-auth|admission-plugins|authorization-mode"
```

### Bước 5: Ghi kết quả kiểm tra vào file

```bash
{
  echo "=== API Server Security Check ==="
  echo "Date: $(date)"
  echo ""
  echo "--- anonymous-auth ---"
  kubectl get pod kube-apiserver-$(hostname) -n kube-system \
    -o jsonpath='{.spec.containers[0].command}' | tr ',' '\n' | grep "anonymous-auth" || echo "NOT SET (default: true)"
  echo ""
  echo "--- admission-plugins ---"
  kubectl get pod kube-apiserver-$(hostname) -n kube-system \
    -o jsonpath='{.spec.containers[0].command}' | tr ',' '\n' | grep "admission-plugins" || echo "NOT SET"
  echo ""
  echo "--- authorization-mode ---"
  kubectl get pod kube-apiserver-$(hostname) -n kube-system \
    -o jsonpath='{.spec.containers[0].command}' | tr ',' '\n' | grep "authorization-mode" || echo "NOT SET"
} > /tmp/api-server-check.txt

cat /tmp/api-server-check.txt
```

### Bước 6: Kiểm tra kết quả

```bash
bash verify.sh
```

---

## Tiêu chí kiểm tra

- [ ] kube-apiserver có flag `--anonymous-auth=false`
- [ ] kube-apiserver có `NodeRestriction` trong `--enable-admission-plugins`
- [ ] kube-apiserver có `--authorization-mode` bao gồm `RBAC`

---

## Gợi ý

<details>
<summary>Gợi ý 1: Cách xem danh sách admission plugins hiện tại</summary>

```bash
kubectl get pod kube-apiserver-$(hostname) -n kube-system \
  -o jsonpath='{.spec.containers[0].command}' | tr ',' '\n' | grep "admission"
```

Nếu không có output, admission plugins đang dùng giá trị mặc định. Kubeadm thường đã bật `NodeRestriction` mặc định từ K8s 1.17+. Kiểm tra bằng:

```bash
kubectl get pod kube-apiserver-$(hostname) -n kube-system -o yaml | grep -A2 "admission"
```

</details>

<details>
<summary>Gợi ý 2: NodeRestriction hoạt động như thế nào?</summary>

NodeRestriction admission plugin giới hạn kubelet chỉ có thể:
- Sửa đổi Node object của chính nó (không phải node khác)
- Sửa đổi Pod object đang chạy trên node của nó
- Không thể thêm/xóa label với prefix `node-restriction.kubernetes.io/`

Điều này ngăn chặn tấn công lateral movement nếu một node bị compromise.

</details>

<details>
<summary>Gợi ý 3: Tại sao cần cả Node và RBAC trong authorization-mode?</summary>

- `Node`: Cho phép kubelet authenticate và authorize các request liên quan đến node/pod của nó
- `RBAC`: Cho phép phân quyền dựa trên Role/ClusterRole cho users và service accounts

Nếu chỉ có `RBAC` mà không có `Node`, kubelet sẽ không thể hoạt động đúng. Thứ tự `Node,RBAC` là quan trọng — Node authorizer được kiểm tra trước.

</details>

---

## Giải pháp mẫu

<details>
<summary>Xem giải pháp đầy đủ (chỉ mở sau khi đã thử)</summary>

Xem file [solution/solution.md](solution/solution.md) để có hướng dẫn chi tiết và các flag cần thêm.

</details>

---

## Giải thích

### Anonymous Authentication

Khi `--anonymous-auth=true` (mặc định), các request không có credentials được xử lý với identity `system:anonymous` thuộc group `system:unauthenticated`. Mặc dù RBAC có thể giới hạn quyền của anonymous user, việc tắt hoàn toàn là best practice vì:
- Giảm attack surface
- Ngăn chặn lỗi cấu hình RBAC vô tình cấp quyền cho anonymous
- Tuân thủ CIS Benchmark 1.2.1

### NodeRestriction Admission Plugin

Không có NodeRestriction, một kubelet bị compromise có thể:
- Sửa đổi Node objects của các node khác (thêm/xóa labels, taints)
- Truy cập Pod specs của workload trên node khác
- Thực hiện privilege escalation trong cluster

NodeRestriction là một trong những admission plugins quan trọng nhất cho cluster security.

### Authorization Mode: Node,RBAC

Kubernetes hỗ trợ nhiều authorization mode. Trong production:
- `Node`: Bắt buộc cho kubelet hoạt động đúng
- `RBAC`: Tiêu chuẩn cho phân quyền user/service account
- Không dùng `AlwaysAllow` trong production

---

## Tham khảo

- [kube-apiserver Flags](https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/)
- [NodeRestriction Admission Plugin](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#noderestriction)
- [Authorization Modes](https://kubernetes.io/docs/reference/access-authn-authz/authorization/)
- [CKS Exam Curriculum – Cluster Hardening](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/)
