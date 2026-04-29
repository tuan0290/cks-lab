# Lab 6.4: CNI Network Encryption (Cilium IPsec)

## Metadata

- **Domain**: 6 - Monitoring, Logging & Runtime Security
- **Difficulty**: Hard
- **Estimated Time**: 77 minutes
- **Exam Weight**: 15%

## Learning Objectives

- Understand CNI Network Encryption (Cilium IPsec)

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- syft
- kyverno
- kubectl configured
- Kubernetes cluster v1.29+
- cosign
- falco
- trivy

## Scenario

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

## Requirements

1. Execute the necessary commands to configure CNI Network Encryption (Cilium IPsec)
2. Create and apply the required Kubernetes manifests
3. Verify the configuration is working correctly
4. Document any troubleshooting steps you performed

## Instructions

### Step 1: Set up the lab environment

Run the setup script to create the initial resources:

```bash
./setup.sh
```

This will create the necessary namespace and base resources.

### Step 2: Complete the main task

```yaml
apiVersion: v1
kind: ConfigMap

Execute the following commands:

```bash
□ Cấu hình NetworkPolicy (deny all + allow specific)
```
*---*

```bash
□ Mã hóa etcd với EncryptionConfiguration
```
*---*

```bash
□ Cấu hình containerd/CRI-O đúng cách
```
*---*

Create and apply the following Kubernetes resources:

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


### Step 3: Verify your solution

Use the verification script to check if your configuration is correct:

```bash
./verify.sh
```

Review any failed checks and make corrections as needed.

## Verification

Run the verification script to check your solution:

```bash
./verify.sh
```

All checks should pass before proceeding.

## Cleanup

After completing the lab, clean up the resources:

```bash
./cleanup.sh
```

## Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [CKS Exam Curriculum](https://github.com/cncf/curriculum)
