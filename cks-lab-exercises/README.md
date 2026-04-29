# CKS Lab Exercises

A comprehensive collection of hands-on lab exercises for the **Certified Kubernetes Security Specialist (CKS)** exam preparation.

## Overview

| Metric | Value |
|--------|-------|
| Total Labs | 60 |
| Domains Covered | 6 |
| Kubernetes Version | v1.29+ |
| Coverage | 100% CKS Exam Topics |

## Lab Structure

Each lab contains:
- `README.md` - Lab objectives, scenario, requirements, and instructions
- `setup.sh` - Initializes the lab environment
- `verify.sh` - Checks if the lab requirements are met
- `cleanup.sh` - Removes all lab resources
- `solution/solution.md` - Step-by-step solution

## Quick Start

```bash
# 1. Navigate to a lab
cd labs/01-cluster-setup/lab-1.1-etcd-encryption

# 2. Set up the lab environment
./setup.sh

# 3. Complete the lab following README.md instructions

# 4. Verify your solution
./verify.sh

# 5. Clean up
./cleanup.sh
```

---

## Domain 1: Cluster Setup (15% - 9 labs)

| Lab | Topic | Difficulty | Time |
|-----|-------|-----------|------|
| 1.1 | Cấu hình etcd Encryption | Easy | 13 minutes |
| 1.2 | NetworkPolicy - Deny All Ingress | Medium | 13 minutes |
| 1.3 | Cấu hình containerd | Easy | 9 minutes |
| 1.4 | CIS Benchmark with kube-bench | Medium | 20 minutes |
| 1.5 | Ingress TLS Configuration | Medium | 20 minutes |
| 1.6 | NetworkPolicy Egress Control | Medium | 20 minutes |
| 1.7 | Node Metadata Protection | Medium | 15 minutes |
| 1.8 | Kubernetes Binary Verification | Easy | 15 minutes |
| 1.9 | Cluster Upgrade Security Considerations | Hard | 25 minutes |

## Domain 2: Cluster Hardening (15% - 9 labs)

| Lab | Topic | Difficulty | Time |
|-----|-------|-----------|------|
| 2.1 | Cấu hình API Server Security | Hard | 19 minutes |
| 2.2 | RBAC - Nguyên tắc Tối Thiểu Đặc Quyền | Easy | 13 minutes |
| 2.3 | Cấu hình Audit Log | Medium | 16 minutes |
| 2.4 | Kubelet Security Configuration | Easy | 11 minutes |
| 2.5 | ServiceAccount Token Management | Medium | 20 minutes |
| 2.6 | Admission Controllers Configuration | Hard | 25 minutes |
| 2.7 | Certificate Management and Rotation | Hard | 25 minutes |
| 2.8 | Control Plane Security Hardening | Hard | 25 minutes |
| 2.9 | NodeRestriction Admission Controller | Medium | 20 minutes |

## Domain 3: System Hardening (10% - 6 labs)

| Lab | Topic | Difficulty | Time |
|-----|-------|-----------|------|
| 3.1 | seccomp Profile | Medium | 13 minutes |
| 3.2 | AppArmor Configuration | Hard | 26 minutes |
| 3.3 | Linux Capabilities Management | Easy | 11 minutes |
| 3.4 | Kernel Security Parameters (sysctl) | Hard | 22 minutes |
| 3.5 | Minimizing Host OS Footprint | Medium | 20 minutes |
| 3.6 | IAM Roles and Cloud Identity Management | Medium | 20 minutes |

## Domain 4: Minimize Microservice Vulnerabilities (20% - 12 labs)

| Lab | Topic | Difficulty | Time |
|-----|-------|-----------|------|
| 4.1 | Pod Security Admission (PSA) — Thay thế PSP | Medium | 13 minutes |
| 4.10 | Multi-Tenancy Isolation | Hard | 25 minutes |
| 4.11 | Image Vulnerability Management | Medium | 20 minutes |
| 4.12 | Runtime Security with Falco Integration | Hard | 25 minutes |
| 4.2 | Trivy - Quét lỗ hổng image | Medium | 18 minutes |
| 4.3 | ResourceQuota & LimitRange | Easy | 11 minutes |
| 4.4 | Security Contexts | Medium | 20 minutes |
| 4.5 | Secret Management | Medium | 20 minutes |
| 4.6 | NetworkPolicy for Microservices | Medium | 20 minutes |
| 4.7 | OPA Gatekeeper Policy Enforcement | Hard | 25 minutes |
| 4.8 | Sandbox Containers with gVisor | Hard | 25 minutes |
| 4.9 | Pod-to-Pod Encryption with mTLS | Hard | 25 minutes |

## Domain 5: Supply Chain Security (20% - 12 labs)

| Lab | Topic | Difficulty | Time |
|-----|-------|-----------|------|
| 5.1 | Cosign — Ký và Xác thực Image | Hard | 25 minutes |
| 5.10 | Container Image Hardening | Medium | 20 minutes |
| 5.11 | Dependency Scanning with Trivy | Medium | 20 minutes |
| 5.12 | Admission Controllers for Supply Chain Enforcement | Hard | 25 minutes |
| 5.2 | Kyverno Policy — Supply Chain Security | Easy | 15 minutes |
| 5.3 | ImagePolicyWebhook | Easy | 11 minutes |
| 5.4 | SBOM với Syft | Medium | 16 minutes |
| 5.5 | Base Image Minimization | Medium | 20 minutes |
| 5.6 | CI/CD Pipeline Security | Hard | 25 minutes |
| 5.7 | Cosign Verification with Kyverno verifyImages | Hard | 25 minutes |
| 5.8 | Private Registry Security | Medium | 20 minutes |
| 5.9 | Supply Chain Attestation with In-toto and SLSA | Hard | 25 minutes |

## Domain 6: Monitoring & Runtime Security (20% - 12 labs)

| Lab | Topic | Difficulty | Time |
|-----|-------|-----------|------|
| 6.1 | Cài đặt Falco | Hard | 19 minutes |
| 6.10 | Container Behavior Analysis with Falco and Audit Logs | Hard | 30 minutes |
| 6.11 | Kubernetes Incident Response Procedures | Hard | 35 minutes |
| 6.12 | Network Traffic Monitoring and Anomaly Detection | Hard | 30 minutes |
| 6.2 | Viết Falco Rules | Medium | 15 minutes |
| 6.3 | Audit Log Query & Analysis | Hard | 22 minutes |
| 6.4 | CNI Network Encryption (Cilium IPsec) | Hard | 77 minutes |
| 6.5 | Falco Custom Rules - Sensitive File Access Monitoring | Medium | 20 minutes |
| 6.6 | Falco Custom Rules - Privileged Container Detection | Medium | 20 minutes |
| 6.7 | Advanced NetworkPolicy - Multi-Tier Application Isolation | Hard | 30 minutes |
| 6.8 | Threat Detection - Attack Simulation and Response | Hard | 35 minutes |
| 6.9 | Runtime Immutability - Immutable Containers and Read-Only Filesystems | Medium | 25 minutes |

---

## Prerequisites

- Kubernetes cluster v1.29+ (minikube, kind, or cloud provider)
- `kubectl` configured and connected to the cluster
- Domain-specific tools: `trivy`, `cosign`, `falco`, `kube-bench`, `syft`

## CKS Exam Domains

| Domain | Weight | Labs |
|--------|--------|------|
| 1. Cluster Setup | 15% | 9 |
| 2. Cluster Hardening | 15% | 9 |
| 3. System Hardening | 10% | 6 |
| 4. Minimize Microservice Vulnerabilities | 20% | 12 |
| 5. Supply Chain Security | 20% | 12 |
| 6. Monitoring & Runtime Security | 20% | 12 |

---

*Generated for CKS 2026 exam preparation*
