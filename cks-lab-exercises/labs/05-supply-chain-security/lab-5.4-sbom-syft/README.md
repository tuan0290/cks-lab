# Lab 5.4: SBOM với Syft

## Metadata

- **Domain**: 5 - Supply Chain Security
- **Difficulty**: Medium
- **Estimated Time**: 16 minutes
- **Exam Weight**: 15%

## Learning Objectives

- Understand SBOM với Syft

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- kubectl configured
- syft
- Kubernetes cluster v1.29+

## Scenario

```bash
# Cài syft
go install github.com/anchore/syft/cmd/syft@latest

## Requirements

1. Execute the necessary commands to configure SBOM với Syft
2. Verify the configuration is working correctly

## Instructions

### Step 1: Set up the lab environment

Run the setup script to create the initial resources:

```bash
./setup.sh
```

This will create the necessary namespace and base resources.

### Step 2: Complete the main task

```bash
go install github.com/anchore/syft/cmd/syft@latest
syft myregistry.io/myimage:v1.0 -o cyclonedx-json > sbom.json

Execute the following commands:

```bash
go install github.com/anchore/syft/cmd/syft@latest
```

```bash
syft myregistry.io/myimage:v1.0 -o cyclonedx-json > sbom.json
```

```bash
syft myimage:v1.0 -o spdx-json > sbom-spdx.json
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
