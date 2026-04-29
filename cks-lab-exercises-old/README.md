# CKS Lab Exercises – Certified Kubernetes Security Specialist

Bộ bài lab thực hành CKS được thiết kế theo cấu trúc đề thi mới nhất (cập nhật **15/10/2024**) của Linux Foundation. Mục tiêu giúp học viên nắm vững kỹ năng bảo mật Kubernetes và vượt qua kỳ thi CKS với điểm tối thiểu **67%**.

---

## Tổng quan

Bộ bài lab gồm **25 bài lab** thực hành, **6 cheatsheet** tham khảo nhanh, và **2 bài thi thử** (mock exam), phân bổ theo 6 domain của đề thi:

| Domain | Trọng số | Số bài lab | Thư mục |
|--------|----------|------------|---------|
| Cluster Setup | 15% | 4 | `labs/01-cluster-setup/` |
| Cluster Hardening | 15% | 4 | `labs/02-cluster-hardening/` |
| System Hardening | 10% | 3 | `labs/03-system-hardening/` |
| Minimize Microservice Vulnerabilities | 20% | 5 | `labs/04-microservice-vulnerabilities/` |
| Supply Chain Security | 20% | 5 | `labs/05-supply-chain-security/` |
| Monitoring, Logging & Runtime Security | 20% | 4 | `labs/06-monitoring-runtime/` |
| **Tổng** | **100%** | **25** | |

---

## Danh sách bài lab

### Domain 1 – Cluster Setup (15%)
| Lab | Chủ đề | Độ khó |
|-----|--------|--------|
| 1.1 | NetworkPolicy Default Deny | Trung bình |
| 1.2 | Pod Security Standards (PSS) | Trung bình |
| 1.3 | Ingress TLS | Trung bình |
| 1.4 | CIS Benchmark với kube-bench | Trung bình |

### Domain 2 – Cluster Hardening (15%)
| Lab | Chủ đề | Độ khó |
|-----|--------|--------|
| 2.1 | RBAC Least Privilege | Trung bình |
| 2.2 | Audit Policy | Nâng cao |
| 2.3 | ServiceAccount Token Automount | Cơ bản |
| 2.4 | Restrict API Server Access | Nâng cao |

### Domain 3 – System Hardening (10%)
| Lab | Chủ đề | Độ khó |
|-----|--------|--------|
| 3.1 | AppArmor | Nâng cao |
| 3.2 | Seccomp | Nâng cao |
| 3.3 | Minimize OS Footprint | Trung bình |

### Domain 4 – Minimize Microservice Vulnerabilities (20%)
| Lab | Chủ đề | Độ khó |
|-----|--------|--------|
| 4.1 | Trivy Image Scan | Cơ bản |
| 4.2 | Secret Encryption at Rest | Nâng cao |
| 4.3 | Secret Volume Mount | Cơ bản |
| 4.4 | RuntimeClass Sandbox | Trung bình |
| 4.5 | Pod-to-Pod Encryption với Cilium | Nâng cao |

### Domain 5 – Supply Chain Security (20%)
| Lab | Chủ đề | Độ khó |
|-----|--------|--------|
| 5.1 | cosign Image Signing | Trung bình |
| 5.2 | Static Analysis (kubesec/trivy config) | Cơ bản |
| 5.3 | Image Policy Webhook (OPA/Gatekeeper) | Nâng cao |
| 5.4 | SBOM (Software Bill of Materials) | Trung bình |
| 5.5 | KubeLinter Static Analysis | Cơ bản |

### Domain 6 – Monitoring, Logging & Runtime Security (20%)
| Lab | Chủ đề | Độ khó |
|-----|--------|--------|
| 6.1 | Falco Rules (Shell Spawn Detection) | Trung bình |
| 6.2 | Audit Log Analysis | Trung bình |
| 6.3 | Immutable Containers | Cơ bản |
| 6.4 | Behavioral Analytics với Falco | Nâng cao |

---

## Hướng dẫn bắt đầu

### 1. Cài đặt công cụ cần thiết

Trước khi bắt đầu, đảm bảo đã cài đặt đầy đủ các công cụ sau:

| Công cụ | Mục đích | Cài đặt |
|---------|----------|---------|
| `kubectl` | Tương tác với Kubernetes cluster | https://kubernetes.io/docs/tasks/tools/ |
| `trivy` | Quét lỗ hổng bảo mật container image và config | https://aquasecurity.github.io/trivy |
| `cosign` | Ký và xác minh chữ ký container image | https://docs.sigstore.dev/cosign/installation/ |
| `falco` | Runtime security – phát hiện hành vi bất thường | https://falco.org/docs/getting-started/ |
| `kube-bench` | Kiểm tra CIS Kubernetes Benchmark | https://github.com/aquasecurity/kube-bench |
| `kubesec` | Phân tích static bảo mật Kubernetes manifest | https://kubesec.io/ |
| `helm` | Quản lý Kubernetes packages | https://helm.sh/docs/intro/install/ |
| `syft` | Tạo SBOM từ container image | https://github.com/anchore/syft |
| `cilium` CLI | Kiểm tra và quản lý Cilium CNI | https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/ |
| `kube-linter` | Lint Kubernetes manifests theo best practices | https://docs.kubelinter.io/ |

### 2. Yêu cầu môi trường

- Kubernetes cluster >= **1.29** (ít nhất 1 control-plane + 1 worker node)
- Quyền truy cập `cluster-admin` vào cluster
- Hệ điều hành Linux trên các node (Ubuntu 22.04 LTS khuyến nghị)

### 3. Cách thực hành một bài lab

```bash
# 1. Vào thư mục bài lab
cd labs/01-cluster-setup/lab-1.1-network-policy/

# 2. Đọc README.md để hiểu mục tiêu và yêu cầu
cat README.md

# 3. Khởi tạo môi trường
bash setup.sh

# 4. Thực hành theo hướng dẫn trong README.md

# 5. Kiểm tra kết quả
bash verify.sh

# 6. Dọn dẹp môi trường sau khi hoàn thành
bash cleanup.sh
```

---

## Cấu trúc thư mục

```
cks-lab-exercises/
├── README.md                          # File này
├── labs/
│   ├── 01-cluster-setup/              # Domain 1 – 15% (4 labs)
│   ├── 02-cluster-hardening/          # Domain 2 – 15% (4 labs)
│   ├── 03-system-hardening/           # Domain 3 – 10% (3 labs)
│   ├── 04-microservice-vulnerabilities/ # Domain 4 – 20% (5 labs)
│   ├── 05-supply-chain-security/      # Domain 5 – 20% (5 labs)
│   └── 06-monitoring-runtime/         # Domain 6 – 20% (4 labs)
├── cheatsheets/                       # Tham khảo nhanh theo domain
│   ├── 01-cluster-setup.md
│   ├── 02-cluster-hardening.md
│   ├── 03-system-hardening.md
│   ├── 04-microservice-vulnerabilities.md
│   ├── 05-supply-chain-security.md
│   └── 06-monitoring-runtime.md
└── mock-exams/                        # Bài thi thử mô phỏng đề thi thực
    ├── mock-exam-1/
    └── mock-exam-2/
```

---

## Nguồn tham khảo

- [Linux Foundation CKS Curriculum](https://github.com/cncf/curriculum)
- [CKS Program Changes (15/10/2024)](https://training.linuxfoundation.org/cks-program-changes/)
- [Kubernetes Security Documentation](https://kubernetes.io/docs/concepts/security/)
