# Solution: Lab 3.3 - Linux Capabilities Management

## Overview

This solution provides step-by-step instructions for completing the Linux Capabilities Management lab exercise.

## Solution Steps

### Step 1: Run the setup script

Execute the setup script to create the initial environment:

```bash
./setup.sh
```

### Step 2: Apply Pod

Create a file with the following content:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: capabilities-pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 1000
  containers:
  - name: app
    image: nginx:alpine
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL                    # Drop tất cả capabilities
        add:
        - NET_BIND_SERVICE       # Chỉ thêm capability cần thiết (bind port <1024)
      privileged: false
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

- Understanding Linux Capabilities Management is essential for Kubernetes security
- Always verify configurations before deploying to production
- Security controls should be tested regularly
