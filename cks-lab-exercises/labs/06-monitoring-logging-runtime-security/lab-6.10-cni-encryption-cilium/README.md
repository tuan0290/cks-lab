# Lab 6.10: CNI Network Encryption (Cilium IPsec)

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

1. Create namespace `lab-6-10`
2. Install Cilium with IPsec encryption enabled
3. Generate and apply IPsec keys
4. Verify pod-to-pod traffic is encrypted
5. Create documentation ConfigMaps

## Questions

> **Exam-style tasks** — Complete all tasks below before running `./verify.sh`

1. **Task**: Create namespace `lab-6-10`.

2. **Task**: Install Cilium with IPsec encryption (if not already installed):
   ```bash
   helm repo add cilium https://helm.cilium.io/
   helm install cilium cilium/cilium \
     --namespace kube-system \
     --set encryption.enabled=true \
     --set encryption.type=ipsec
   ```

3. **Task**: Generate and apply IPsec keys:
   ```bash
   # Generate a random IPsec key
   kubectl create secret generic cilium-ipsec-keys \
     --from-literal=keys="3 rfc4106(gcm(aes)) $(dd if=/dev/urandom count=20 bs=1 2>/dev/null | xxd -p -c 64) 128" \
     -n kube-system
   ```

4. **Task**: Verify Cilium encryption is active:
   ```bash
   kubectl -n kube-system exec ds/cilium -- cilium encrypt status
   ```

5. **Task**: Create a ConfigMap named `cilium-encryption-config` in namespace `lab-6-10` documenting:
   - Encryption type: IPsec
   - Key rotation procedure
   - How to verify encryption is active
   - Difference between IPsec and WireGuard in Cilium

6. **Task**: Create a ConfigMap named `encryption-test-results` in namespace `lab-6-10` documenting the verification results.

7. **Verify**: Run `./verify.sh` — all checks must pass.

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
