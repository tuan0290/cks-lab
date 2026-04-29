# Solution: Lab 3.1 - seccomp Profile

## Overview

This solution provides step-by-step instructions for completing the seccomp Profile lab exercise.

## Solution Steps

### Step 1: Run the setup script

Execute the setup script to create the initial environment:

```bash
./setup.sh
```

### Step 2: }

Create a file with the following content:

```yaml
# Cách 1: Dùng Localhost profile tùy chỉnh
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  securityContext:
    seccompProfile:
      type: Localhost
      localhostProfile: my-profile.json  # relative to /var/lib/kubelet/seccomp/
  containers:
  - name: container
    image: nginx:alpine
```

Apply the manifest:

```bash
kubectl apply -f <filename>
```

### Step 3: image: nginx:alpine

Create a file with the following content:

```yaml
# Cách 2 (Khuyến nghị): Dùng RuntimeDefault
apiVersion: v1
kind: Pod
metadata:
  name: runtime-default-seccomp
spec:
  securityContext:
    seccompProfile:
      type: RuntimeDefault   # Mặc định của container runtime
  containers:
  - name: container
    image: nginx:alpine
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

- Understanding seccomp Profile is essential for Kubernetes security
- Always verify configurations before deploying to production
- Security controls should be tested regularly
