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

1. Create namespace `lab-5-4`
2. Generate an SBOM for `nginx:1.25` in CycloneDX JSON format using Syft
3. Generate an SBOM in SPDX format
4. Store the SBOM summary in a ConfigMap

## Questions

> **Exam-style tasks** — Complete all tasks below before running `./verify.sh`

1. **Task**: Create namespace `lab-5-4`.

2. **Task**: Generate an SBOM for `nginx:1.25` in CycloneDX JSON format:
   ```bash
   syft nginx:1.25 -o cyclonedx-json > /tmp/nginx-sbom-cyclonedx.json
   ```

3. **Task**: Generate an SBOM in SPDX format:
   ```bash
   syft nginx:1.25 -o spdx-json > /tmp/nginx-sbom-spdx.json
   ```

4. **Task**: Count the number of packages in the SBOM:
   ```bash
   cat /tmp/nginx-sbom-cyclonedx.json | python3 -c \
     "import sys,json; d=json.load(sys.stdin); print(len(d.get('components',[])))"
   ```

5. **Task**: Create a ConfigMap named `sbom-summary` in namespace `lab-5-4` with:
   - `image: nginx:1.25`
   - `sbom-format: CycloneDX,SPDX`
   - `package-count: <number from step 4>`
   - `tool: syft`

6. **Task**: Create a ConfigMap named `sbom-policy` in namespace `lab-5-4` documenting why SBOMs are important for supply chain security and how they relate to vulnerability scanning.

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
