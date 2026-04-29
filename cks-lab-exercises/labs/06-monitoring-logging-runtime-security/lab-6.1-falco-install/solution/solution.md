# Solution: Lab 6.1 - Cài đặt Falco

## Overview

This solution provides step-by-step instructions for completing the Cài đặt Falco lab exercise.

## Solution Steps

### Step 1: Run the setup script

Execute the setup script to create the initial environment:

```bash
./setup.sh
```

### Step 2: Execute command 1

```bash
helm repo add falcosecurity https://falcosecurity.github.io/charts
```

### Step 3: Execute command 2

```bash
helm repo update
```

### Step 4: Execute command 3

```bash
helm install falco falcosecurity/falco \
```

### Step 5: Execute command 4

```bash
--namespace falco --create-namespace \
```

### Step 6: Execute command 5

```bash
--set driver.kind=ebpf \
```

### Step 7: Execute command 6

```bash
--set tty=true
```

### Step 8: Execute command 7

```bash
kubectl get pods -n falco
```

### Step 9: Execute command 8

```bash
kubectl logs -n falco -l app=falcosecurity-falco
```

### Step 10: Verify the configuration

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
- Missing required labels or annotations
- Incorrect security context configuration
- Not considering resource dependencies

## Troubleshooting

**Issue**: Resources not being created

**Solution**: Check kubectl logs and describe the resources to see error messages. Verify YAML syntax and API versions.

**Issue**: Verification script fails

**Solution**: Review the specific check that failed. Use kubectl get/describe commands to inspect the actual state of resources.

## Key Takeaways

- Understanding Cài đặt Falco is essential for Kubernetes security
- Always verify configurations before deploying to production
- Security controls should be tested regularly
