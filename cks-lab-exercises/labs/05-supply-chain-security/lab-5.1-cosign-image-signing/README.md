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

1. Create namespace `lab-5-1`
2. Generate a Cosign key pair (`cosign.key` and `cosign.pub`)
3. Sign a container image using the private key
4. Verify the signature using the public key
5. Store the public key in a ConfigMap

## Questions

> **Exam-style tasks** — Complete all tasks below before running `./verify.sh`

1. **Task**: Create namespace `lab-5-1`.

2. **Task**: Generate a Cosign key pair (set `COSIGN_PASSWORD=""` for no password in lab):
   ```bash
   COSIGN_PASSWORD="" cosign generate-key-pair
   # Creates cosign.key (private) and cosign.pub (public)
   ```

3. **Task**: Sign a container image using the private key:
   ```bash
   COSIGN_PASSWORD="" cosign sign --key cosign.key \
     --annotations "signed-by=lab-user" \
     --annotations "environment=lab" \
     ttl.sh/cks-lab-test:1h
   ```

4. **Task**: Verify the signature using the public key:
   ```bash
   cosign verify --key cosign.pub ttl.sh/cks-lab-test:1h
   ```

5. **Task**: Store the public key in a ConfigMap named `cosign-public-key` in namespace `lab-5-1`:
   ```bash
   kubectl create configmap cosign-public-key \
     --from-file=cosign.pub=./cosign.pub \
     -n lab-5-1
   ```

6. **Task**: Create a ConfigMap named `signing-procedure` in namespace `lab-5-1` documenting the key generation, signing, and verification steps.

7. **Verify**: Run `./verify.sh` — all checks must pass.

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
