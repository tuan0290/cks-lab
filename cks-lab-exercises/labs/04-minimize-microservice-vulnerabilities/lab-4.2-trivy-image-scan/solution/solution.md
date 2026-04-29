# Solution: Lab 4.2 - Trivy - Quét lỗ hổng image

## Overview

This solution provides step-by-step instructions for completing the Trivy - Quét lỗ hổng image lab exercise.

## Solution Steps

### Step 1: Run the setup script

Execute the setup script to create the initial environment:

```bash
./setup.sh
```

### Step 2: Execute command 1

```bash
trivy image nginx:1.21
```

### Step 3: Execute command 2

```bash
trivy image --severity HIGH,CRITICAL nginx:1.21
```

### Step 4: Execute command 3

```bash
trivy image --format json nginx:1.21
```

### Step 5: Execute command 4

```bash
trivy image --output report.txt nginx:1.21
```

### Step 6: Execute command 5

```bash
trivy fs /path/to/image
```

### Step 7: Execute command 6

```bash
trivy k8s --namespace production
```

### Step 8: Execute command 7

```bash
trivy k8s pod --namespace default my-pod
```

### Step 9: Verify the configuration

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

- Understanding Trivy - Quét lỗ hổng image is essential for Kubernetes security
- Always verify configurations before deploying to production
- Security controls should be tested regularly
