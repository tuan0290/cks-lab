# Solution: Lab 5.2 - Kyverno Policy — Supply Chain Security

## Overview

This solution provides step-by-step instructions for completing the Kyverno Policy — Supply Chain Security lab exercise.

## Solution Steps

### Step 1: Run the setup script

Execute the setup script to create the initial environment:

```bash
./setup.sh
```

### Step 2: Apply Unknown

Create a file with the following content:

```yaml
# Kyverno ClusterPolicy: Chỉ cho phép image từ registry được phép
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: check-image-registry
  annotations:
    policies.kyverno.io/title: Check Image Registry
    policies.kyverno.io/category: Supply Chain Security
    policies.kyverno.io/severity: medium
spec:
  validationFailureAction: enforce
  background: true
  rules:
  - name: verify-registry
    match:
      any:
      - resources:
          kinds:
          - Pod
    validate:
      message: "Images must only be pulled from approved registries"
      pattern:
        spec:
          containers:
          - image: "myregistry.io/* | gcr.io/myproject/*"
---
# Kyverno Policy: Xác thực chữ ký image (Cosign)
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-image-signature
  annotations:
    policies.kyverno.io/title: Verify Image Signature
    policies.kyverno.io/severity: high
spec:
  validationFailureAction: enforce
  rules:
  - name: verify-signature
    match:
      any:
      - resources:
          kinds:
          - Pod
    verifyImages:
    - imageReferences:
      - "myregistry.io/*"
      key: |-
        -----BEGIN PUBLIC KEY-----
        MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE...
        -----END PUBLIC KEY-----
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

- Understanding Kyverno Policy — Supply Chain Security is essential for Kubernetes security
- Always verify configurations before deploying to production
- Security controls should be tested regularly
