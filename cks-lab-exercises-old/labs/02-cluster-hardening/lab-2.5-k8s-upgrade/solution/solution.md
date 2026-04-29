# Giải pháp mẫu – Lab 2.5: Kubernetes Cluster Upgrade (v1.31 → v1.32)

> Tham khảo chính thức:
> - https://v1-32.docs.kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/
> - https://v1-32.docs.kubernetes.io/docs/tasks/administer-cluster/kubeadm/upgrading-linux-nodes/

---

## Upgrade Control-Plane Node

### 1. Đổi repository sang v1.32

```bash
# SSH vào control-plane node
ssh user@control-plane-ip

# Debian/Ubuntu: đổi repository
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /" \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update

# Tìm patch version mới nhất
sudo apt-cache madison kubeadm
# → Ví dụ: 1.32.3-1.1
```

### 2. Upgrade kubeadm

```bash
# Debian/Ubuntu (thay x bằng patch version)
sudo apt-mark unhold kubeadm && \
sudo apt-get update && \
sudo apt-get install -y kubeadm='1.32.x-*' && \
sudo apt-mark hold kubeadm

# RHEL/CentOS
sudo yum install -y kubeadm-'1.32.x-*' --disableexcludes=kubernetes

# Xác minh
kubeadm version
```

### 3. Xem kế hoạch upgrade

```bash
sudo kubeadm upgrade plan
```

### 4. Apply upgrade (chỉ primary control-plane)

```bash
sudo kubeadm upgrade apply v1.32.x
# Nhập 'y' khi được hỏi
# Output thành công: [upgrade/successful] SUCCESS! Your cluster was upgraded to "v1.32.x"
```

> **Additional control-plane nodes** dùng `sudo kubeadm upgrade node` thay vì `upgrade apply`.

### 5. Drain control-plane node

```bash
# Chạy từ máy có kubectl
kubectl drain <control-plane-name> --ignore-daemonsets
```

### 6. Upgrade kubelet và kubectl

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

### 7. Uncordon control-plane

```bash
kubectl uncordon <control-plane-name>
kubectl get nodes  # Xác minh Ready + phiên bản mới
```

---

## Upgrade Worker Node

### 1. Drain worker node (từ control-plane)

```bash
kubectl drain <worker-node-name> --ignore-daemonsets
```

### 2. SSH vào worker node và đổi repository

```bash
ssh user@worker-node-ip

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /" \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
```

### 3. Upgrade kubeadm

```bash
sudo apt-mark unhold kubeadm && \
sudo apt-get update && \
sudo apt-get install -y kubeadm='1.32.x-*' && \
sudo apt-mark hold kubeadm
```

### 4. Upgrade node configuration

```bash
# Worker node dùng "upgrade node" (KHÔNG phải "upgrade apply")
sudo kubeadm upgrade node
```

### 5. Upgrade kubelet và kubectl

```bash
sudo apt-mark unhold kubelet kubectl && \
sudo apt-get update && \
sudo apt-get install -y kubelet='1.32.x-*' kubectl='1.32.x-*' && \
sudo apt-mark hold kubelet kubectl

sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

### 6. Uncordon worker node (từ control-plane)

```bash
kubectl uncordon <worker-node-name>
```

---

## Xác minh

```bash
# Tất cả node Ready với phiên bản mới
kubectl get nodes

# Tất cả pod kube-system Running
kubectl get pods -n kube-system

# Phiên bản API server
kubectl version
```

---

## Điểm khác biệt quan trọng

| | Control-plane (primary) | Control-plane (additional) | Worker node |
|---|---|---|---|
| Upgrade components | `kubeadm upgrade apply vX.Y.Z` | `kubeadm upgrade node` | `kubeadm upgrade node` |
| Thứ tự drain | **Sau** upgrade components | **Sau** upgrade components | **Trước** upgrade components |

---

## Tham khảo

- [kubeadm upgrade (v1.32)](https://v1-32.docs.kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/)
- [Upgrading Linux nodes (v1.32)](https://v1-32.docs.kubernetes.io/docs/tasks/administer-cluster/kubeadm/upgrading-linux-nodes/)
