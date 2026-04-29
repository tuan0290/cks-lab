# Solution: Lab 5.1 - Cosign — Ký và Xác thực Image

## Overview

This solution provides step-by-step instructions for completing the Cosign — Ký và Xác thực Image lab exercise.

## Solution Steps

### Step 1: Run the setup script

Execute the setup script to create the initial environment:

```bash
./setup.sh
```

### Step 2: Execute command 1

```bash
go install github.com/sigstore/cosign/v2/cmd/cosign@latest
```

### Step 3: Execute command 2

```bash
cosign generate-key-pair
```

### Step 4: Execute command 3

```bash
cosign sign myregistry.io/myproject/myimage:v1.0
```

### Step 5: Execute command 4

```bash
cosign sign \
```

### Step 6: Execute command 5

```bash
--annotations "version=1.0" \
```

### Step 7: Execute command 6

```bash
--annotations "author=team" \
```

### Step 8: Execute command 7

```bash
myregistry.io/myproject/myimage:v1.0
```

### Step 9: Execute command 8

```bash
cosign verify myregistry.io/myproject/myimage:v1.0 \
```

### Step 10: Execute command 9

```bash
--key cosign.pub
```

### Step 11: Execute command 10

```bash
syft myregistry.io/myproject/myimage:v1.0 -o cyclonedx-json > sbom.json
```

### Step 12: Execute command 11

```bash
cosign attach sbom --type cyclonedx sbom.json \
```

### Step 13: Execute command 12

```bash
myregistry.io/myproject/myimage:v1.0
```

### Step 14: Verify the configuration

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

- Understanding Cosign — Ký và Xác thực Image is essential for Kubernetes security
- Always verify configurations before deploying to production
- Security controls should be tested regularly
