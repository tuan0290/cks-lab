# Lab 1.1: Cấu hình etcd Encryption

## Metadata

- **Domain**: 1 - Cluster Setup
- **Difficulty**: Easy
- **Estimated Time**: 13 minutes
- **Exam Weight**: 15%

## Learning Objectives

- Understand Cấu hình etcd Encryption

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- kubectl configured
- Kubernetes cluster v1.29+

## Scenario

```yaml
# /etc/kubernetes/encryption-config.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
    - secrets
    providers:
    - aescbc:
        keys:
        - name: key1
          secret: <32-byte-base64-key>
    - identity: {}  # Fallback (đọc dữ liệu cũ chưa mã hóa)
```

## Requirements

1. Generate a 32-byte base64-encoded encryption key
2. Create an `EncryptionConfiguration` file at `/etc/kubernetes/encryption-config.yaml` using `aescbc` provider for Secrets
3. Configure the kube-apiserver to use the encryption config via `--encryption-provider-config` flag
4. Restart the kube-apiserver and verify it comes back healthy
5. Create a new Secret and verify it is stored encrypted in etcd

## Questions

> **Exam-style tasks** — Complete all tasks below before running `./verify.sh`

1. **Task**: Generate a random 32-byte base64 key to use as the encryption secret.
   - Command: `head -c 32 /dev/urandom | base64`

2. **Task**: Create the file `/etc/kubernetes/encryption-config.yaml` with the following spec:
   - Use `aescbc` as the primary provider for `secrets`
   - Include `identity: {}` as the fallback provider
   - Use the key you generated in task 1

3. **Task**: Edit `/etc/kubernetes/manifests/kube-apiserver.yaml` to add the flag:
   ```
   --encryption-provider-config=/etc/kubernetes/encryption-config.yaml
   ```
   Also mount the config file into the kube-apiserver pod.

4. **Task**: After the kube-apiserver restarts, create a Secret named `test-secret` in the `default` namespace with key `password` and value `mysecretvalue`.

5. **Task**: Verify the Secret is encrypted in etcd by running:
   ```bash
   ETCDCTL_API=3 etcdctl get /registry/secrets/default/test-secret \
     --endpoints=https://127.0.0.1:2379 \
     --cacert=/etc/kubernetes/pki/etcd/ca.crt \
     --cert=/etc/kubernetes/pki/etcd/server.crt \
     --key=/etc/kubernetes/pki/etcd/server.key | hexdump -C | head
   ```
   The output should show `k8s:enc:aescbc:v1:` prefix, confirming encryption.

## Instructions

### Step 1: Set up the lab environment

Run the setup script to create the initial resources:

```bash
./setup.sh
```

This will create the necessary namespace and base resources.

### Step 2: Complete the main task

```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration

Execute the following commands:

```bash
head -c 32 /dev/urandom | base64
```
*- identity: {}  # Fallback (đọc dữ liệu cũ chưa mã hóa)*

```bash
--encryption-provider-config=/etc/kubernetes/encryption-config.yaml
```
*- identity: {}  # Fallback (đọc dữ liệu cũ chưa mã hóa)*

Create and apply the following Kubernetes resources:

```yaml
# /etc/kubernetes/encryption-config.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
    - secrets
    providers:
    - aescbc:
        keys:
        - name: key1
          secret: <32-byte-base64-key>
    - identity: {}  # Fallback (đọc dữ liệu cũ chưa mã hóa)
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
