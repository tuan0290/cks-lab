# Giải pháp mẫu – Lab 2.5: Kubernetes Cluster Upgrade

> **Lưu ý:** Chỉ đọc sau khi đã tự thử thực hành.

---

## Quy trình upgrade đầy đủ (Debian/Ubuntu)

### Bước 1: Xác định phiên bản target

```bash
# Trên control-plane node
sudo kubeadm upgrade plan

# Xem package có sẵn
apt-cache madison kubeadm | head -5
# Ví dụ output:
#   kubeadm | 1.29.3-1.1 | https://pkgs.k8s.io/...
#   kubeadm | 1.29.2-1.1 | https://pkgs.k8s.io/...
```

### Bước 2: Upgrade control-plane

```bash
# SSH vào control-plane node
ssh user@control-plane-ip

# 2a. Upgrade kubeadm
sudo apt-mark unhold kubeadm
sudo apt-get update
sudo apt-get install -y kubeadm=1.29.3-1.1
sudo apt-mark hold kubeadm

# Xác minh
kubeadm version

# 2b. Apply upgrade
sudo kubeadm upgrade apply v1.29.3
# Nhập 'y' khi được hỏi

# 2c. Drain control-plane (từ máy có kubectl)
kubectl drain <control-plane-name> \
  --ignore-daemonsets \
  --delete-emptydir-data

# 2d. Upgrade kubelet + kubectl
sudo apt-mark unhold kubelet kubectl
sudo apt-get update
sudo apt-get install -y kubelet=1.29.3-1.1 kubectl=1.29.3-1.1
sudo apt-mark hold kubelet kubectl

# Restart kubelet
sudo systemctl daemon-reload
sudo systemctl restart kubelet

# 2e. Uncordon
kubectl uncordon <control-plane-name>

# Xác minh
kubectl get nodes
```

### Bước 3: Upgrade từng worker node

```bash
# Drain worker node (từ máy có kubectl)
kubectl drain <worker-node-name> \
  --ignore-daemonsets \
  --delete-emptydir-data

# SSH vào worker node
ssh user@worker-node-ip

# Upgrade kubeadm
sudo apt-mark unhold kubeadm
sudo apt-get update
sudo apt-get install -y kubeadm=1.29.3-1.1
sudo apt-mark hold kubeadm

# Upgrade node config
sudo kubeadm upgrade node

# Upgrade kubelet + kubectl
sudo apt-mark unhold kubelet kubectl
sudo apt-get update
sudo apt-get install -y kubelet=1.29.3-1.1 kubectl=1.29.3-1.1
sudo apt-mark hold kubelet kubectl

# Restart kubelet
sudo systemctl daemon-reload
sudo systemctl restart kubelet

# Uncordon (từ máy có kubectl)
kubectl uncordon <worker-node-name>
```

### Bước 4: Xác minh

```bash
# Tất cả node phải Ready với phiên bản mới
kubectl get nodes

# Tất cả pod kube-system phải Running
kubectl get pods -n kube-system

# Phiên bản API server
kubectl version
```

---

## Sự khác biệt giữa control-plane và worker node

| Bước | Control-plane | Worker node |
|------|--------------|-------------|
| Upgrade kubeadm | `apt install kubeadm=X` | `apt install kubeadm=X` |
| Upgrade components | `kubeadm upgrade apply vX.Y.Z` | `kubeadm upgrade node` |
| Upgrade kubelet | `apt install kubelet=X kubectl=X` | `apt install kubelet=X kubectl=X` |

**Lưu ý quan trọng:**
- Control-plane dùng `kubeadm upgrade apply` — upgrade toàn bộ control-plane components
- Worker node dùng `kubeadm upgrade node` — chỉ upgrade node configuration

---

## Xử lý lỗi thường gặp

### Lỗi: "node has pods that cannot be evicted"

```bash
# Xem pod nào đang block
kubectl get pods --all-namespaces -o wide | grep <node-name>

# Force drain
kubectl drain <node> \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --force
```

### Lỗi: kubelet không start sau upgrade

```bash
# Xem logs
sudo journalctl -u kubelet -f

# Thường do config không tương thích — reset config
sudo kubeadm upgrade node --certificate-renewal=false
sudo systemctl restart kubelet
```

### Lỗi: "unable to upgrade connection: pod does not exist"

Đây là lỗi tạm thời khi pod đang restart sau upgrade. Chờ 1-2 phút và thử lại.

---

## Tham khảo

- [kubeadm upgrade](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/)
- [Kubernetes CVE Feed](https://kubernetes.io/docs/reference/issues-security/official-cve-feed/)
