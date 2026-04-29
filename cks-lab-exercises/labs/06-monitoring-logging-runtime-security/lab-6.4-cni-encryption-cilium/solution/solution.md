# Solution: Lab 6.4 - CNI Network Encryption (Cilium IPsec)

## Overview

This solution provides step-by-step instructions for completing the CNI Network Encryption (Cilium IPsec) lab exercise.

## Solution Steps

### Step 1: Run the setup script

Execute the setup script to create the initial environment:

```bash
./setup.sh
```

### Step 2: ---

```bash
□ Cấu hình NetworkPolicy (deny all + allow specific)
```

---

### Step 3: ---

```bash
□ Mã hóa etcd với EncryptionConfiguration
```

---

### Step 4: ---

```bash
□ Cấu hình containerd/CRI-O đúng cách
```

---

### Step 5: ---

```bash
□ Cấu hình API Server security flags
```

---

### Step 6: ---

```bash
□ Tạo ServiceAccount + RBAC với quyền tối thiểu
```

---

### Step 7: ---

```bash
□ Bật Audit Logging đúng policy
```

---

### Step 8: ---

```bash
□ Bảo mật Kubelet config
```

---

### Step 9: ---

```bash
□ Tạo và áp dụng seccomp profile
```

---

### Step 10: ---

```bash
□ Tạo và áp dụng AppArmor profile
```

---

### Step 11: ---

```bash
□ Drop ALL capabilities trong Pod
```

---

### Step 12: ---

```bash
□ Cấu hình kernel sysctl parameters
```

---

### Step 13: ---

```bash
□ Cấu hình Pod Security Admission (3 cấp độ)
```

---

### Step 14: ---

```bash
□ Quét image với Trivy (chỉ HIGH, CRITICAL)
```

---

### Step 15: ---

```bash
□ Viết Pod spec đúng chuẩn Restricted level
```

---

### Step 16: ---

```bash
□ Tạo ResourceQuota + LimitRange
```

---

### Step 17: ---

```bash
□ Ký image với Cosign
```

---

### Step 18: ---

```bash
□ Xác thực image với Cosign
```

---

### Step 19: ---

```bash
□ Cấu hình ImagePolicyWebhook
```

---

### Step 20: ---

```bash
□ Viết Kyverno policy kiểm soát registry
```

---

### Step 21: ---

```bash
□ Tạo SBOM với Syft
```

---

### Step 22: ---

```bash
□ Cài và cấu hình Falco
```

---

### Step 23: ---

```bash
□ Viết custom Falco rules (ít nhất 3 loại)
```

---

### Step 24: ---

```bash
□ Query và phân tích Audit Log với jq
```

---

### Step 25: ---

```bash
□ Cấu hình CNI encryption (Cilium)
```

---

### Step 26: ---

```bash
□ Phát hiện và xử lý threat scenarios
```

---

### Step 27: ---

```bash
kubectl create serviceaccount sa-name -n ns
```

---

### Step 28: ---

```bash
kubectl create role role-name --verb=get,list --resource=pods -n ns
```

---

### Step 29: ---

```bash
kubectl create rolebinding rb-name --role=role-name --serviceaccount=ns:sa-name -n ns
```

---

### Step 30: ---

```bash
kubectl auth can-i delete secrets -n default --as=system:anonymous
```

---

### Step 31: ---

```bash
kubectl auth can-i get secrets --all-namespaces
```

---

### Step 32: ---

```bash
kubectl create networkpolicy default-deny -n ns
```

---

### Step 33: ---

```bash
kubectl get networkpolicies -A
```

---

### Step 34: ---

```bash
kubectl label ns default pod-security.kubernetes.io/enforce=restricted
```

---

### Step 35: ---

```bash
kubectl describe ns default | grep pod-security
```

---

### Step 36: ---

```bash
trivy image nginx:latest --severity HIGH,CRITICAL
```

---

### Step 37: ---

```bash
trivy k8s all-namespaces
```

---

### Step 38: ---

```bash
kubectl logs -n kube-system kube-apiserver-master
```

---

### Step 39: ---

```bash
kubectl logs -n falco -l app=falcosecurity-falco
```

---

### Step 40: ---

```bash
cosign sign myregistry.io/image:tag
```

---

### Step 41: ---

```bash
cosign verify myregistry.io/image:tag --key cosign.pub
```

---

### Step 42: ---

```bash
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -dates
```

---

### Step 43: ---

```bash
alias k=kubectl
```

---

### Step 44: ---

```bash
alias kg='kubectl get'
```

---

### Step 45: ---

```bash
alias kd='kubectl delete'
```

---

### Step 46: ---

```bash
alias ka='kubectl apply -f'
```

---

### Step 47: ---

```bash
kubectl config use-context <context-name>
```

---

### Step 48: ---

```bash
kubectl run my-pod --image=nginx --dry-run=client -o yaml
```

---

### Step 49: ---

```bash
kubectl create deployment my-deploy --image=nginx --replicas=3 --dry-run=client -o yaml
```

---

### Step 50: **Cách chạy mock exam:**

```bash
cd mock-exams/mock-exam-3
```

**Cách chạy mock exam:**

### Step 51: **Cách chạy mock exam:**

```bash
bash setup.sh
```

**Cách chạy mock exam:**

### Step 52: **Cách chạy mock exam:**

```bash
cat solutions/answers.md
```

**Cách chạy mock exam:**

### Step 53: **Cách chạy mock exam:**

```bash
bash cleanup.sh
```

**Cách chạy mock exam:**

### Step 54: - Nên chạy trực tiếp trên control plane node (bastion → master node)

```bash
https://github.com/aquasecurity/trivy/releases
```

- Nên chạy trực tiếp trên control plane node (bastion → master node)

### Step 55: - Nên chạy trực tiếp trên control plane node (bastion → master node)

```bash
https://github.com/falcosecurity/falco/releases
```

- Nên chạy trực tiếp trên control plane node (bastion → master node)

### Step 56: - Nên chạy trực tiếp trên control plane node (bastion → master node)

```bash
https://github.com/sigstore/cosign/releases
```

- Nên chạy trực tiếp trên control plane node (bastion → master node)

### Step 57: - Nên chạy trực tiếp trên control plane node (bastion → master node)

```bash
https://github.com/anchore/syft/releases
```

- Nên chạy trực tiếp trên control plane node (bastion → master node)

### Step 58: Apply ConfigMap

Create a file with the following content:

```yaml
# Cilium ConfigMap — Bật IPsec encryption
apiVersion: v1
kind: ConfigMap
metadata:
  name: cilium-config
  namespace: kube-system
data:
  enable-ipsec: "true"
  ipsec-key-file: "/etc/cilium/ipsec/keys"
  encryption: "ipsec"
  encryption-node-encryption: "true"   # Encrypt cả Pod-to-Pod
  tls-ca-cert: "/var/lib/cilium/tls/ca.crt"
  tls-client-cert: "/var/lib/cilium/tls/client.crt"
  tls-client-key: "/var/lib/cilium/tls/client.key"
```

Apply the manifest:

```bash
kubectl apply -f <filename>
```

### Step 59: Verify the configuration

Run the verification script to confirm everything is working:

```bash
./verify.sh
```

## Verification

After completing all steps, verify your solution:

```bash
./verify.sh
```

Expected output: All checks should pass.

## Common Mistakes

- Forgetting to create the namespace before applying resources
- Not waiting for resources to be ready before verification
- Incorrect YAML indentation
- Missing required labels or annotations
- Incorrect security context configuration
- Not considering resource dependencies

## Troubleshooting

**Issue**: Resources not being created

**Solution**: Check kubectl logs and describe the resources to see error messages. Verify YAML syntax and API versions.

**Issue**: Verification script fails

**Solution**: Review the specific check that failed. Use kubectl get/describe commands to inspect the actual state of resources.

## Key Takeaways

- Understanding CNI Network Encryption (Cilium IPsec) is essential for Kubernetes security
- Always verify configurations before deploying to production
- Security controls should be tested regularly
