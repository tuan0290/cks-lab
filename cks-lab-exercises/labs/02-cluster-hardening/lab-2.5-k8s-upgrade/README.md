# Lab 2.5 – Kubernetes Cluster Upgrade

**Domain:** Cluster Hardening (15%)
**Thời gian ước tính:** 30 phút
**Độ khó:** Nâng cao

---

## Mục tiêu

- Hiểu tại sao upgrade Kubernetes thường xuyên là yêu cầu bảo mật quan trọng
- Thực hành quy trình upgrade cluster từ phiên bản hiện tại lên phiên bản mới hơn bằng `kubeadm`
- Upgrade control-plane node trước, sau đó upgrade worker node
- Xác minh cluster hoạt động bình thường sau khi upgrade

---

## Lý thuyết

### Tại sao upgrade Kubernetes là yêu cầu bảo mật?

Mỗi phiên bản Kubernetes cũ đều có thể chứa **CVE (Common Vulnerabilities and Exposures)** đã được công bố. Kẻ tấn công biết chính xác lỗ hổng nào tồn tại trong phiên bản cũ và có thể khai thác chúng.

Ví dụ các CVE nghiêm trọng trong lịch sử Kubernetes:

| CVE | Phiên bản ảnh hưởng | Mô tả |
|-----|---------------------|-------|
| CVE-2018-1002105 | < 1.10.11, < 1.11.5, < 1.12.3 | Privilege escalation qua API server proxy |
| CVE-2019-11247 | < 1.13.9, < 1.14.5, < 1.15.2 | Unauthorized access to cluster-scoped resources |
| CVE-2019-9512 | < 1.13.10, < 1.14.6, < 1.15.3 | HTTP/2 DoS (Ping Flood) |
| CVE-2021-25741 | < 1.19.15, < 1.20.11, < 1.21.5 | Symlink exchange attack |

**CKS curriculum 2024** nhấn mạnh: upgrade Kubernetes để tránh các lỗ hổng đã biết là một phần của **Cluster Hardening**.

### Kubernetes Release Cycle

Kubernetes phát hành phiên bản minor mới **mỗi 4 tháng** (3 phiên bản/năm). Mỗi phiên bản được hỗ trợ trong **14 tháng** (khoảng 3 phiên bản minor).

```
v1.28 → v1.29 → v1.30 → v1.31
  ↑ Mỗi bước cách nhau ~4 tháng
```

**Quy tắc upgrade:** Chỉ được upgrade **1 minor version** mỗi lần. Không thể nhảy từ v1.27 lên v1.29 trực tiếp.

### Thứ tự upgrade

```
1. Upgrade kubeadm trên control-plane
2. Upgrade control-plane components (apiserver, etcd, scheduler, controller-manager)
3. Upgrade kubelet + kubectl trên control-plane
4. Lặp lại cho từng worker node:
   a. Drain node (di chuyển workload sang node khác)
   b. Upgrade kubeadm, kubelet, kubectl
   c. Uncordon node (cho phép schedule pod trở lại)
```

### Các lệnh kubeadm upgrade quan trọng

```bash
# Xem phiên bản hiện tại
kubectl version
kubeadm version

# Xem các phiên bản có thể upgrade lên
kubeadm upgrade plan

# Upgrade control-plane
kubeadm upgrade apply v1.X.Y

# Upgrade worker node
kubeadm upgrade node

# Drain node trước khi upgrade
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Uncordon node sau khi upgrade
kubectl uncordon <node-name>
```

### Drain vs Cordon

| Lệnh | Tác dụng | Khi nào dùng |
|------|---------|--------------|
| `kubectl cordon <node>` | Đánh dấu node `SchedulingDisabled` — pod mới không được schedule | Khi cần bảo trì nhẹ |
| `kubectl drain <node>` | Cordon + evict tất cả pod đang chạy | Trước khi upgrade hoặc bảo trì nặng |
| `kubectl uncordon <node>` | Bỏ đánh dấu, cho phép schedule lại | Sau khi bảo trì xong |

### Kiểm tra CVE của phiên bản hiện tại

```bash
# Xem phiên bản Kubernetes
kubectl version --short

# Tra cứu CVE tại:
# https://kubernetes.io/docs/reference/issues-security/official-cve-feed/
# https://nvd.nist.gov/vuln/search?query=kubernetes
```

---

## Bối cảnh

Bạn là kỹ sư bảo mật nhận được cảnh báo từ team security: cluster Kubernetes đang chạy phiên bản cũ có CVE nghiêm trọng. Nhiệm vụ của bạn là thực hiện upgrade cluster lên phiên bản mới nhất có sẵn để vá các lỗ hổng bảo mật.

Trong bài lab này, bạn sẽ thực hành toàn bộ quy trình upgrade:
1. Kiểm tra phiên bản hiện tại và lên kế hoạch upgrade
2. Upgrade control-plane node
3. Upgrade worker node (drain → upgrade → uncordon)
4. Xác minh cluster hoạt động bình thường

---

## Yêu cầu môi trường

- Kubernetes cluster >= 1.28 được cài bằng **kubeadm** (kubeadm cluster)
- `kubectl` đã được cấu hình và kết nối đến cluster
- Quyền SSH vào control-plane node và worker node
- Quyền `sudo` trên các node

> **Lưu ý:** Lab này yêu cầu cluster thực với quyền SSH vào node. Không thể thực hành trên managed cluster (EKS, GKE, AKS).

Chạy script khởi tạo môi trường:

```bash
bash setup.sh
```

---

## Các bước thực hiện

### Bước 1: Kiểm tra phiên bản hiện tại

```bash
# Xem phiên bản Kubernetes
kubectl version

# Xem phiên bản kubeadm
kubeadm version

# Xem tất cả node và phiên bản
kubectl get nodes -o wide

# Xem phiên bản chi tiết của từng component
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.nodeInfo.kubeletVersion}{"\n"}{end}'
```

### Bước 2: Lên kế hoạch upgrade

```bash
# Xem các phiên bản có thể upgrade lên
sudo kubeadm upgrade plan

# Output sẽ hiển thị:
# - Phiên bản hiện tại
# - Phiên bản có thể upgrade (latest stable, latest patch)
# - Các component sẽ được upgrade
```

Ghi nhận phiên bản target (ví dụ: `v1.29.X`):
```bash
TARGET_VERSION="v1.29.X"  # Thay bằng phiên bản thực tế từ kubeadm upgrade plan
```

### Bước 3: Upgrade control-plane node

SSH vào control-plane node:

```bash
ssh <user>@<control-plane-ip>
```

**3a. Upgrade kubeadm:**

```bash
# Debian/Ubuntu
sudo apt-mark unhold kubeadm
sudo apt-get update
sudo apt-get install -y kubeadm=1.29.X-1.1  # Thay X bằng patch version
sudo apt-mark hold kubeadm

# Xác minh phiên bản mới
kubeadm version
```

**3b. Xem kế hoạch upgrade:**

```bash
sudo kubeadm upgrade plan
```

**3c. Apply upgrade control-plane:**

```bash
sudo kubeadm upgrade apply v1.29.X  # Thay X bằng patch version

# Xác nhận khi được hỏi: [y/N] → y
```

Output thành công sẽ kết thúc bằng:
```
[upgrade/successful] SUCCESS! Your cluster was upgraded to "v1.29.X". Enjoy!
```

**3d. Drain control-plane node:**

```bash
# Từ máy có kubectl (hoặc trên control-plane)
kubectl drain <control-plane-node-name> \
  --ignore-daemonsets \
  --delete-emptydir-data
```

**3e. Upgrade kubelet và kubectl trên control-plane:**

```bash
# Debian/Ubuntu
sudo apt-mark unhold kubelet kubectl
sudo apt-get update
sudo apt-get install -y kubelet=1.29.X-1.1 kubectl=1.29.X-1.1
sudo apt-mark hold kubelet kubectl

# Restart kubelet
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

**3f. Uncordon control-plane:**

```bash
kubectl uncordon <control-plane-node-name>
```

**3g. Xác minh control-plane đã upgrade:**

```bash
kubectl get nodes
# Control-plane node phải hiển thị phiên bản mới
```

### Bước 4: Upgrade worker node(s)

Lặp lại cho từng worker node:

**4a. Drain worker node:**

```bash
# Từ máy có kubectl
kubectl drain <worker-node-name> \
  --ignore-daemonsets \
  --delete-emptydir-data
```

**4b. SSH vào worker node và upgrade:**

```bash
ssh <user>@<worker-node-ip>

# Upgrade kubeadm
sudo apt-mark unhold kubeadm
sudo apt-get update
sudo apt-get install -y kubeadm=1.29.X-1.1
sudo apt-mark hold kubeadm

# Upgrade node configuration
sudo kubeadm upgrade node

# Upgrade kubelet và kubectl
sudo apt-mark unhold kubelet kubectl
sudo apt-get update
sudo apt-get install -y kubelet=1.29.X-1.1 kubectl=1.29.X-1.1
sudo apt-mark hold kubelet kubectl

# Restart kubelet
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

**4c. Uncordon worker node:**

```bash
# Từ máy có kubectl
kubectl uncordon <worker-node-name>
```

### Bước 5: Xác minh cluster sau upgrade

```bash
# Xem tất cả node — tất cả phải ở trạng thái Ready với phiên bản mới
kubectl get nodes

# Xem tất cả pod hệ thống — phải Running
kubectl get pods -n kube-system

# Xem phiên bản API server
kubectl version

# Chạy verify script
bash verify.sh
```

---

## Tiêu chí kiểm tra

- [ ] Tất cả node trong cluster đang ở trạng thái `Ready`
- [ ] Phiên bản kubelet trên tất cả node đã được upgrade lên phiên bản mới hơn phiên bản ban đầu
- [ ] Tất cả pod trong namespace `kube-system` đang ở trạng thái `Running`

---

## Gợi ý

<details>
<summary>Gợi ý 1: Tìm phiên bản upgrade target</summary>

```bash
# Xem phiên bản hiện tại
kubectl version --short

# Xem phiên bản có thể upgrade
sudo kubeadm upgrade plan

# Hoặc xem trực tiếp package có sẵn
apt-cache madison kubeadm | head -5
```

Chỉ được upgrade **1 minor version** mỗi lần:
- v1.28.x → v1.29.x ✅
- v1.28.x → v1.30.x ❌ (phải qua v1.29 trước)

</details>

<details>
<summary>Gợi ý 2: Xử lý lỗi khi drain node</summary>

Nếu drain bị stuck do pod có PodDisruptionBudget:

```bash
# Force drain (cẩn thận — có thể gây downtime)
kubectl drain <node> \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --force \
  --grace-period=0
```

Nếu có pod không thể evict:

```bash
# Xem pod nào đang block drain
kubectl get pods --all-namespaces -o wide | grep <node-name>

# Xóa pod thủ công nếu cần
kubectl delete pod <pod-name> -n <namespace> --grace-period=0 --force
```

</details>

<details>
<summary>Gợi ý 3: Kiểm tra kubelet sau khi restart</summary>

```bash
# Xem trạng thái kubelet
sudo systemctl status kubelet

# Xem logs nếu kubelet không start
sudo journalctl -u kubelet -f --since "5 minutes ago"

# Xem phiên bản kubelet
kubelet --version
```

</details>

<details>
<summary>Gợi ý 4: Rollback nếu upgrade thất bại</summary>

Nếu upgrade control-plane thất bại, kubeadm tự động rollback. Nếu cần rollback thủ công:

```bash
# Xem backup của etcd (kubeadm tự tạo trước khi upgrade)
ls /etc/kubernetes/tmp/

# Restore từ backup nếu cần
# (Tham khảo: https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/)
```

</details>

<details>
<summary>Gợi ý 5: Upgrade trên RHEL/CentOS</summary>

```bash
# RHEL/CentOS dùng yum/dnf thay vì apt
sudo yum install -y kubeadm-1.29.X-0 --disableexcludes=kubernetes
sudo yum install -y kubelet-1.29.X-0 kubectl-1.29.X-0 --disableexcludes=kubernetes
```

</details>

---

## Giải pháp mẫu

<details>
<summary>Xem giải pháp đầy đủ (chỉ mở sau khi đã thử)</summary>

Xem file [solution/solution.md](solution/solution.md) để có các lệnh đầy đủ và giải thích chi tiết.

</details>

---

## Giải thích

### Tại sao upgrade là yêu cầu bảo mật?

Kubernetes là phần mềm phức tạp với hàng triệu dòng code. CVE mới được phát hiện thường xuyên. Chạy phiên bản cũ có nghĩa là:
- Kẻ tấn công biết chính xác lỗ hổng nào tồn tại
- Có thể tìm thấy exploit công khai trên internet
- Không có patch bảo mật từ Kubernetes team

### Kubernetes Security Patch Policy

Kubernetes team phát hành **patch release** (ví dụ: v1.29.1 → v1.29.2) để vá CVE mà không thay đổi API. Nên:
- Luôn chạy **latest patch** của minor version hiện tại
- Upgrade lên minor version mới khi minor version hiện tại hết support

### Upgrade trong CKS Exam

Trong kỳ thi CKS, bạn có thể được yêu cầu:
1. Upgrade cluster từ phiên bản X lên phiên bản Y
2. Upgrade chỉ control-plane hoặc chỉ worker node
3. Xác minh cluster hoạt động sau upgrade

Thứ tự quan trọng: **control-plane trước, worker node sau**.

### apt-mark hold — tại sao cần?

```bash
sudo apt-mark hold kubeadm kubelet kubectl
```

`apt-mark hold` ngăn `apt upgrade` tự động upgrade Kubernetes packages. Điều này quan trọng vì:
- Upgrade Kubernetes cần thực hiện theo thứ tự cụ thể
- Upgrade tự động có thể làm hỏng cluster
- Cần kiểm tra compatibility trước khi upgrade

---

## Tham khảo

- [Kubernetes Upgrade Documentation](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/)
- [Kubernetes CVE Feed](https://kubernetes.io/docs/reference/issues-security/official-cve-feed/)
- [Kubernetes Release Notes](https://kubernetes.io/releases/)
- [CKS Exam Curriculum – Cluster Hardening](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/)
