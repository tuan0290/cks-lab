# Lab 5.2: Kyverno Policy — Supply Chain Security

## Metadata

- **Domain**: 5 - Supply Chain Security
- **Difficulty**: Easy
- **Estimated Time**: 15 minutes
- **Exam Weight**: 15%

## Learning Objectives

- Understand Kyverno Policy — Supply Chain Security
- Apply security best practices
- Create and enforce policies

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- kubectl configured
- kyverno
- Kubernetes cluster v1.29+
- cosign

## Scenario

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
    val

## Requirements

1. Create and apply the required Kubernetes manifests
2. Verify the configuration is working correctly

## Instructions

### Step 1: Set up the lab environment

Run the setup script to create the initial resources:

```bash
./setup.sh
```

This will create the necessary namespace and base resources.

### Step 2: Complete the main task

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy

Create and apply the following Kubernetes resources:

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


### Step 3: Verify your solution

Use the verification script to check if your configuration is correct:

```bash
./verify.sh
```

Review any failed checks and make corrections as needed.

## Verification

Run the verification script to check your solution:

```bash
./verify.sh
```

All checks should pass before proceeding.

## Cleanup

After completing the lab, clean up the resources:

```bash
./cleanup.sh
```

## Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [CKS Exam Curriculum](https://github.com/cncf/curriculum)
