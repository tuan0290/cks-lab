# Solution: Lab 1.1 - Cấu hình etcd Encryption

## Overview

This solution provides step-by-step instructions for completing the Cấu hình etcd Encryption lab exercise.

## Solution Steps

### Step 1: Run the setup script

Execute the setup script to create the initial environment:

```bash
./setup.sh
```

### Step 2: - identity: {}  # Fallback (đọc dữ liệu cũ chưa mã hóa)

```bash
head -c 32 /dev/urandom | base64
```

- identity: {}  # Fallback (đọc dữ liệu cũ chưa mã hóa)

### Step 3: - identity: {}  # Fallback (đọc dữ liệu cũ chưa mã hóa)

```bash
--encryption-provider-config=/etc/kubernetes/encryption-config.yaml
```

- identity: {}  # Fallback (đọc dữ liệu cũ chưa mã hóa)

### Step 4: Apply EncryptionConfiguration

Create a file with the following content:

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

Apply the manifest:

```bash
kubectl apply -f <filename>
```

### Step 5: Verify the configuration

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

## Troubleshooting

**Issue**: Resources not being created

**Solution**: Check kubectl logs and describe the resources to see error messages. Verify YAML syntax and API versions.

**Issue**: Verification script fails

**Solution**: Review the specific check that failed. Use kubectl get/describe commands to inspect the actual state of resources.

## Key Takeaways

- Understanding Cấu hình etcd Encryption is essential for Kubernetes security
- Always verify configurations before deploying to production
- Security controls should be tested regularly
