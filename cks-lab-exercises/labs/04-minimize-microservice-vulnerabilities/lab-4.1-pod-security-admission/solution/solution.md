# Solution: Lab 4.1 - Pod Security Admission (PSA) — Thay thế PSP

## Overview

This solution provides step-by-step instructions for completing the Pod Security Admission (PSA) — Thay thế PSP lab exercise.

## Solution Steps

### Step 1: Run the setup script

Execute the setup script to create the initial environment:

```bash
./setup.sh
```

### Step 2: Apply Unknown

Create a file with the following content:

```yaml
# Cấp độ 1: Privileged (không giới hạn) — KHÔNG dùng trong production

# Cấp độ 2: Baseline (giới hạn cơ bản)
apiVersion: v1
kind: Namespace
metadata:
  name: baseline-ns
  labels:
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/audit: baseline
    pod-security.kubernetes.io/warn: baseline

---
# Cấp độ 3: Restricted (giới hạn chặt nhất) — Dùng cho production
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

Apply the manifest:

```bash
kubectl apply -f <filename>
```

### Step 3: - Volume types bị giới hạn (không có `hostPath`)

Create a file with the following content:

```yaml
# Ví dụ Pod đúng chuẩn Restricted level
apiVersion: v1
kind: Pod
metadata:
  name: restricted-pod
  namespace: production
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: nginx:1.25-alpine
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop:
        - ALL
      readOnlyRootFilesystem: true
    volumeMounts:
    - name: cache
      mountPath: /var/cache/nginx
    - name: run
      mountPath: /var/run
  volumes:
  - name: cache
    emptyDir: {}
  - name: run
    emptyDir: {}
```

Apply the manifest:

```bash
kubectl apply -f <filename>
```

### Step 4: Verify the configuration

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

- Understanding Pod Security Admission (PSA) — Thay thế PSP is essential for Kubernetes security
- Always verify configurations before deploying to production
- Security controls should be tested regularly
