# Lab 5.1: Cosign — Ký và Xác thực Image

## Metadata

- **Domain**: 5 - Supply Chain Security
- **Difficulty**: Hard
- **Estimated Time**: 25 minutes
- **Exam Weight**: 15%

## Learning Objectives

- Understand Cosign — Ký và Xác thực Image

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- kubectl configured
- syft
- Kubernetes cluster v1.29+
- cosign

## Scenario

```bash
# Cài cosign
go install github.com/sigstore/cosign/v2/cmd/cosign@latest

## Requirements

1. Execute the necessary commands to configure Cosign — Ký và Xác thực Image
2. Verify the configuration is working correctly
3. Document any troubleshooting steps you performed

## Instructions

### Step 1: Set up the lab environment

Run the setup script to create the initial resources:

```bash
./setup.sh
```

This will create the necessary namespace and base resources.

### Step 2: Complete the main task

```bash
go install github.com/sigstore/cosign/v2/cmd/cosign@latest
cosign generate-key-pair

Execute the following commands:

```bash
go install github.com/sigstore/cosign/v2/cmd/cosign@latest
```

```bash
cosign generate-key-pair
```

```bash
cosign sign myregistry.io/myproject/myimage:v1.0
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
