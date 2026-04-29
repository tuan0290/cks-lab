# Solution: Lab 1.2 - NetworkPolicy - Deny All Ingress

## Overview

This solution provides step-by-step instructions for completing the NetworkPolicy - Deny All Ingress lab exercise.

## Solution Steps

### Step 1: Run the setup script

Execute the setup script to create the initial environment:

```bash
./setup.sh
```

### Step 2: Apply NetworkPolicy

Create a file with the following content:

```yaml
# Chặn tất cả ingress traffic vào namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```

Apply the manifest:

```bash
kubectl apply -f <filename>
```

### Step 3: - Ingress

Create a file with the following content:

```yaml
# Cho phép frontend → backend port 8080
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
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

- Understanding NetworkPolicy - Deny All Ingress is essential for Kubernetes security
- Always verify configurations before deploying to production
- Security controls should be tested regularly
