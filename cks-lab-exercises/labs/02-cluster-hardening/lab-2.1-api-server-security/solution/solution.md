# Solution: Lab 2.1 - Cấu hình API Server Security

## Overview

This solution provides step-by-step instructions for completing the Cấu hình API Server Security lab exercise.

## Solution Steps

### Step 1: Run the setup script

Execute the setup script to create the initial environment:

```bash
./setup.sh
```

### Step 2: Execute command 1

```bash
--anonymous-auth=false                              # Tắt anonymous access
```

### Step 3: Execute command 2

```bash
--authorization-mode=Node,RBAC                      # Chỉ dùng RBAC
```

### Step 4: Execute command 3

```bash
--enable-admission-plugins=NodeRestriction,EventRateLimit
```

### Step 5: Execute command 4

```bash
--secure-port=6443                                  # Chỉ dùng HTTPS
```

### Step 6: Execute command 5

```bash
--tls-cert-file=/etc/kubernetes/pki/apiserver.crt
```

### Step 7: Execute command 6

```bash
--tls-private-key-file=/etc/kubernetes/pki/apiserver.key
```

### Step 8: Execute command 7

```bash
--client-ca-file=/etc/kubernetes/pki/ca.crt
```

### Step 9: Execute command 8

```bash
--service-account-lookup=true                       # Validate ServiceAccount
```

### Step 10: Execute command 9

```bash
--service-account-key-file=/etc/kubernetes/pki/sa.pub
```

### Step 11: Execute command 10

```bash
--service-account-signing-key-file=/etc/kubernetes/pki/sa.key
```

### Step 12: Verify the configuration

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

- Understanding Cấu hình API Server Security is essential for Kubernetes security
- Always verify configurations before deploying to production
- Security controls should be tested regularly
