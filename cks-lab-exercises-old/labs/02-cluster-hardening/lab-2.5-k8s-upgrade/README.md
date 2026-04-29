# Lab 2.5 – Kubernetes Cluster Upgrade

**Domain:** Cluster Hardening (15%)
**Thời gian ước tính:** 30 phút
**Độ khó:** Nâng cao

---

## Mục tiêu

- Hiểu tại sao upgrade Kubernetes thường xuyên là yêu cầu bảo mật quan trọng
- Thực hành quy trình upgrade cluster từ v1.31.x lên v1.32.x bằng `kubeadm`
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
| CVE-2021-25741 | < 1.19.15, < 1.20.11, < 1.21.5 | Symlink exchange attack |

**CKS curriculum** nhấn mạnh: upgrade Kubernetes để tránh các lỗ hổng đã biết là một phần của **Cluster Hardening**.

### Kubernetes Release Cycle và Version Skew Policy

Kubernetes phát hành phiên bản minor mới **mỗi 4 tháng**. Mỗi phiên bản được hỗ trợ trong **14 tháng**.

**Quy tắc bắt buộc:** Chỉ được upgrade **1 minor version** mỗi lần. Không thể nhảy từ v1.30 lên v1.32 trực tiếp.

```
v1.30.x → v1.31.x → v1.32.x   ✅ Đúng (từng bước)
v1.30.x → v1.32.x              ❌ Sai (bỏ qua minor version)
```

### Thứ tự upgrade bắt buộc

```
1. Upgrade control-plane node (primary)
   a. Upgrade kubeadm
   b. kubeadm upgrade plan  (xem phiên bản có thể upgrade)
   c. kubeadm upgrade apply v1.32.x
   d. Drain control-plane node
   e. Upgrade kubelet + kubectl
   f. Restart kubelet
   g. Uncordon control-plane node

2. Upgrade additional control-plane nodes (nếu có)
   → Giống bước 1 nhưng dùng: kubeadm upgrade node (không phải apply)

3. Upgrade từng worker node
   a. Drain worker node (từ control-plane)
   b. SSH vào worker node
   c. Upgrade kubeadm
   d. kubeadm upgrade node
   e. Upgrade kubelet + kubectl
   f. Restart kubelet
   g. Uncordon worker node (từ control-plane)
```

### Changing the package repository

Từ Kubernetes 1.24+, package repository dùng **pkgs.k8s.io** (community-owned). Mỗi minor version có repository riêng — cần **đổi repository** trước khi upgrade lên minor version mới:

```bash
# Ví dụ: đổi từ v1.31 sang v1.32
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /" \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list
```

---

## Bối cảnh

Bạn là kỹ sư bảo mật nhận được cảnh báo từ team security: cluster Kubernetes đang chạy v1.31.x có CVE nghiêm trọng. Nhiệm vụ của bạn là thực hiện upgrade cluster lên v1.32.x theo đúng quy trình chính thức của Kubernetes.

---

## Yêu cầu môi trường

- Kubernetes cluster được cài bằng **kubeadm** (v1.31.x)
- `kubectl` đã được cấu hình với quyền cluster-admin
- Quyền SSH và `sudo` vào control-plane node và worker node(s)
- Swap đã được disable trên tất cả node

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

# Xem tất cả node và phiên bản kubelet
kubectl get nodes -o wide

# Xem phiên bản kubeadm (trên control-plane node)
kubeadm version
```

---

### Bước 2: Đổi package repository lên v1.32 (trên control-plane node)

SSH vào control-plane node:

```bash
ssh <user>@<control-plane-ip>
```

Đổi repository từ v1.31 sang v1.32:

```bash
# Debian/Ubuntu
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /" \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
```

Tìm phiên bản patch mới nhất của v1.32:

```bash
sudo apt-cache madison kubeadm
# Tìm dòng có dạng: 1.32.x-*
# Ghi nhận phiên bản, ví dụ: 1.32.3-1.1
```

---

### Bước 3: Upgrade kubeadm trên control-plane node

```bash
# Debian/Ubuntu — thay x bằng patch version mới nhất
sudo apt-mark unhold kubeadm && \
sudo apt-get update && \
sudo apt-get install -y kubeadm='1.32.x-*' && \
sudo apt-mark hold kubeadm

# RHEL/CentOS
sudo yum install -y kubeadm-'1.32.x-*' --disableexcludes=kubernetes

# Xác minh phiên bản mới
kubeadm version
```

---

### Bước 4: Xem kế hoạch upgrade

```bash
sudo kubeadm upgrade plan
```

Output sẽ hiển thị:
- Phiên bản hiện tại của từng component
- Phiên bản có thể upgrade lên
- Trạng thái các component config

---

### Bước 5: Apply upgrade control-plane

```bash
# Thay x bằng patch version cụ thể (ví dụ: v1.32.3)
sudo kubeadm upgrade apply v1.32.x
```

Xác nhận khi được hỏi: nhập `y`

Output thành công:
```
[upgrade/successful] SUCCESS! Your cluster was upgraded to "v1.32.x". Enjoy!
[upgrade/kubelet] Now that your control plane is upgraded, please proceed with upgrading your kubelets if you haven't already done so.
```

> **Lưu ý:** Sau khi upgrade control-plane xong, nếu dùng CNI plugin (Calico, Cilium...), kiểm tra xem CNI có cần upgrade không.

---

### Bước 6: Drain control-plane node

```bash
# Chạy từ máy có kubectl (hoặc trên control-plane)
kubectl drain <control-plane-node-name> --ignore-daemonsets
```

---

### Bước 7: Upgrade kubelet và kubectl trên control-plane node

```bash
# Debian/Ubuntu — thay x bằng patch version
sudo apt-mark unhold kubelet kubectl && \
sudo apt-get update && \
sudo apt-get install -y kubelet='1.32.x-*' kubectl='1.32.x-*' && \
sudo apt-mark hold kubelet kubectl

# RHEL/CentOS
sudo yum install -y kubelet-'1.32.x-*' kubectl-'1.32.x-*' --disableexcludes=kubernetes

# Restart kubelet
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

---

### Bước 8: Uncordon control-plane node

```bash
kubectl uncordon <control-plane-node-name>

# Xác minh control-plane đã Ready với phiên bản mới
kubectl get nodes
```

---

### Bước 9: Upgrade từng worker node

Lặp lại cho từng worker node:

**9a. Drain worker node** (từ control-plane hoặc máy có kubectl):

```bash
kubectl drain <worker-node-name> --ignore-daemonsets
```

**9b. SSH vào worker node và đổi repository:**

```bash
ssh <user>@<worker-node-ip>

# Debian/Ubuntu — đổi sang v1.32 repository
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /" \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
```

**9c. Upgrade kubeadm:**

```bash
# Debian/Ubuntu
sudo apt-mark unhold kubeadm && \
sudo apt-get update && \
sudo apt-get install -y kubeadm='1.32.x-*' && \
sudo apt-mark hold kubeadm

# RHEL/CentOS
sudo yum install -y kubeadm-'1.32.x-*' --disableexcludes=kubernetes
```

**9d. Upgrade node configuration:**

```bash
# Worker node dùng "upgrade node" (không phải "upgrade apply")
sudo kubeadm upgrade node
```

**9e. Upgrade kubelet và kubectl:**

```bash
# Debian/Ubuntu
sudo apt-mark unhold kubelet kubectl && \
sudo apt-get update && \
sudo apt-get install -y kubelet='1.32.x-*' kubectl='1.32.x-*' && \
sudo apt-mark hold kubelet kubectl

# RHEL/CentOS
sudo yum install -y kubelet-'1.32.x-*' kubectl-'1.32.x-*' --disableexcludes=kubernetes

# Restart kubelet
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

**9f. Uncordon worker node** (từ control-plane):

```bash
kubectl uncordon <worker-node-name>
```

---

### Bước 10: Xác minh cluster sau upgrade

```bash
# Tất cả node phải Ready với phiên bản mới
kubectl get nodes

# Tất cả pod kube-system phải Running
kubectl get pods -n kube-system

# Xác minh phiên bản API server
kubectl version
```

---

### Bước 11: Chạy verify script

```bash
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
kubectl version --short 2>/dev/null || kubectl version

# Sau khi đổi repository sang v1.32, tìm patch version mới nhất
sudo apt-cache madison kubeadm
# Ví dụ output:
#   kubeadm | 1.32.3-1.1 | https://pkgs.k8s.io/...
#   kubeadm | 1.32.2-1.1 | https://pkgs.k8s.io/...
# → Dùng 1.32.3-1.1 (mới nhất)
```

</details>

<details>
<summary>Gợi ý 2: Sự khác biệt giữa control-plane và worker node</summary>

| Bước | Control-plane (primary) | Control-plane (additional) | Worker node |
|------|------------------------|---------------------------|-------------|
| Upgrade kubeadm | `apt install kubeadm=X` | `apt install kubeadm=X` | `apt install kubeadm=X` |
| Upgrade components | `kubeadm upgrade apply vX.Y.Z` | `kubeadm upgrade node` | `kubeadm upgrade node` |
| Drain | Sau khi apply | Sau khi upgrade node | Trước khi upgrade |
| Upgrade kubelet | `apt install kubelet=X kubectl=X` | `apt install kubelet=X kubectl=X` | `apt install kubelet=X kubectl=X` |

**Quan trọng:** Worker node phải **drain trước** khi upgrade, control-plane drain **sau** khi upgrade components.

</details>

<details>
<summary>Gợi ý 3: Xử lý lỗi khi drain node</summary>

```bash
# Nếu drain bị stuck do PodDisruptionBudget
kubectl drain <node> \
  --ignore-daemonsets \
  --delete-emptydir-data

# Force drain (cẩn thận — có thể gây downtime)
kubectl drain <node> \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --force \
  --grace-period=0
```

</details>

<details>
<summary>Gợi ý 4: Kiểm tra kubelet sau khi restart</summary>

```bash
# Xem trạng thái kubelet
sudo systemctl status kubelet

# Xem logs nếu kubelet không start
sudo journalctl -xeu kubelet --since "5 minutes ago"

# Xem phiên bản kubelet
kubelet --version
```

</details>

<details>
<summary>Gợi ý 5: Recovering from a failure state</summary>

Nếu `kubeadm upgrade apply` thất bại, lệnh này là **idempotent** — có thể chạy lại:

```bash
sudo kubeadm upgrade apply v1.32.x
```

Hoặc force apply mà không đổi version:

```bash
sudo kubeadm upgrade apply --force
```

kubeadm tự động backup tại `/etc/kubernetes/tmp/`:
- `kubeadm-backup-etcd-<date>-<time>` — backup etcd data
- `kubeadm-backup-manifests-<date>-<time>` — backup static pod manifests

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

Kubernetes team phát hành **patch release** (ví dụ: v1.32.1 → v1.32.2) để vá CVE mà không thay đổi API. Nên:
- Luôn chạy **latest patch** của minor version hiện tại
- Upgrade lên minor version mới khi minor version hiện tại hết support (14 tháng)

### apt-mark hold — tại sao cần?

```bash
sudo apt-mark hold kubeadm kubelet kubectl
```

`apt-mark hold` ngăn `apt upgrade` tự động upgrade Kubernetes packages. Điều này quan trọng vì:
- Upgrade Kubernetes cần thực hiện theo thứ tự cụ thể
- Upgrade tự động có thể làm hỏng cluster
- Cần kiểm tra compatibility trước khi upgrade

### Trong CKS Exam

Bạn thường được yêu cầu:
1. Upgrade cluster từ phiên bản X lên phiên bản Y
2. Upgrade chỉ control-plane hoặc chỉ worker node
3. Xác minh cluster hoạt động sau upgrade

Thứ tự quan trọng: **control-plane trước, worker node sau**.

---

## Tham khảo

- [Upgrading kubeadm clusters (v1.32)](https://v1-32.docs.kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/)
- [Upgrading Linux nodes (v1.32)](https://v1-32.docs.kubernetes.io/docs/tasks/administer-cluster/kubeadm/upgrading-linux-nodes/)
- [Changing the Kubernetes package repository](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/change-package-repository/)
- [Kubernetes CVE Feed](https://kubernetes.io/docs/reference/issues-security/official-cve-feed/)
- [CKS Exam Curriculum – Cluster Hardening](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/)
