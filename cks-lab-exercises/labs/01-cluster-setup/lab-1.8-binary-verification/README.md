# Lab 1.8: Kubernetes Binary Verification

## Metadata

- **Domain**: 1 - Cluster Setup
- **Difficulty**: Easy
- **Estimated Time**: 15 minutes
- **Exam Weight**: 15%

## Learning Objectives

- Verify the integrity of Kubernetes binaries using SHA256 checksums
- Understand the importance of supply chain verification for cluster components
- Use official Kubernetes release checksums to validate downloaded binaries

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- sha256sum or shasum available

## Scenario

Before deploying a new Kubernetes version, your security team requires verification that the downloaded binaries have not been tampered with. You must verify the SHA256 checksum of the kubectl binary against the official checksum published by the Kubernetes project.

## Requirements

1. Create namespace `lab-1-8`
2. Create a ConfigMap `binary-verification-results` documenting the verification process and result
3. Create a ConfigMap `verification-procedure` with the step-by-step verification commands

## Questions

> **Exam-style tasks** — Complete all tasks below before running `./verify.sh`

1. **Task**: Create namespace `lab-1-8`.

2. **Task**: Find the path of the installed `kubectl` binary and compute its SHA256 checksum:
   ```bash
   KUBECTL_PATH=$(which kubectl)
   sha256sum "$KUBECTL_PATH"
   ```

3. **Task**: Create a ConfigMap named `binary-verification-results` in namespace `lab-1-8` with the following fields:
   - `binary`: the full path to the kubectl binary
   - `sha256`: the SHA256 checksum you computed
   - `verification-date`: current UTC timestamp
   - `status`: `checksum-recorded`

4. **Task**: Create a ConfigMap named `verification-procedure` in namespace `lab-1-8` documenting the step-by-step procedure to verify a Kubernetes binary against the official release checksum.
   - Include the download URL pattern: `https://dl.k8s.io/release/<version>/bin/linux/amd64/kubectl.sha256`

5. **Verify**: Run `./verify.sh` — all checks must pass.

## Instructions

```bash
# Get the current kubectl version
KUBECTL_VERSION=$(kubectl version --client -o json | python3 -c "import sys,json; print(json.load(sys.stdin)['clientVersion']['gitVersion'])")
echo "kubectl version: $KUBECTL_VERSION"

# Download the official checksum (example for linux/amd64)
# curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256"

# Verify the binary
# echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check

# Check the currently installed kubectl
KUBECTL_PATH=$(which kubectl)
sha256sum "$KUBECTL_PATH"
echo "Compare this hash with the official release checksum at:"
echo "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256"
```

### Step 3: Create the verification procedure ConfigMap

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: verification-procedure
  namespace: lab-1-8
data:
  procedure.sh: |
    #!/bin/bash
    # Kubernetes Binary Verification Procedure
    
    # Step 1: Determine the version to verify
    VERSION="v1.29.0"
    
    # Step 2: Download the binary and its checksum
    curl -LO "https://dl.k8s.io/release/\${VERSION}/bin/linux/amd64/kubectl"
    curl -LO "https://dl.k8s.io/release/\${VERSION}/bin/linux/amd64/kubectl.sha256"
    
    # Step 3: Verify the checksum
    echo "\$(cat kubectl.sha256)  kubectl" | sha256sum --check
    
    # Step 4: If verification passes, install
    # chmod +x kubectl
    # mv kubectl /usr/local/bin/kubectl
    
    echo "Binary verification complete"
EOF
```

### Step 4: Create the verification results ConfigMap

```bash
KUBECTL_PATH=$(which kubectl)
CHECKSUM=$(sha256sum "$KUBECTL_PATH" | awk '{print $1}')

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: binary-verification-results
  namespace: lab-1-8
data:
  binary: "$KUBECTL_PATH"
  sha256: "$CHECKSUM"
  verification-date: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  status: "checksum-recorded"
  note: "Compare this SHA256 with the official Kubernetes release checksum"
EOF
```

### Step 5: Verify your solution

```bash
./verify.sh
```

## Verification

```bash
./verify.sh
```

## Cleanup

```bash
./cleanup.sh
```

## Key Concepts

- **SHA256 checksum**: Cryptographic hash used to verify file integrity
- **Supply chain security**: Verifying that software has not been tampered with during distribution
- **Official release checksums**: Published at `https://dl.k8s.io/release/<version>/bin/<os>/<arch>/<binary>.sha256`

## Additional Resources

- [Kubernetes Release Checksums](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#verify-kubectl-binary)
- [SLSA Supply Chain Security](https://slsa.dev/)
