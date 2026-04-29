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

1. Execute the necessary commands to configure Cấu hình etcd Encryption
2. Create and apply the required Kubernetes manifests
3. Verify the configuration is working correctly

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
