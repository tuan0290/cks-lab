# Solution: Lab 4.3 - ResourceQuota & LimitRange

## Overview

This solution provides step-by-step instructions for completing the ResourceQuota & LimitRange lab exercise.

## Solution Steps

### Step 1: Run the setup script

Execute the setup script to create the initial environment:

```bash
./setup.sh
```

### Step 2: Apply Unknown

Create a file with the following content:

```yaml
# ResourceQuota — Giới hạn tổng tài nguyên namespace
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-resources
  namespace: production
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    persistentvolumeclaims: "4"
---
# LimitRange — Giới hạn mặc định cho từng Pod/Container
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: production
spec:
  limits:
  - default:          # Limit mặc định nếu không khai báo
      cpu: 500m
      memory: 512Mi
    defaultRequest:   # Request mặc định nếu không khai báo
      cpu: 100m
      memory: 128Mi
    max:              # Giới hạn tối đa
      cpu: "2"
      memory: 4Gi
    min:              # Giới hạn tối thiểu
      cpu: 50m
      memory: 64Mi
    type: Container
```

Apply the manifest:

```bash
kubectl apply -f <filename>
```

### Step 3: Verify the configuration

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

- Understanding ResourceQuota & LimitRange is essential for Kubernetes security
- Always verify configurations before deploying to production
- Security controls should be tested regularly
