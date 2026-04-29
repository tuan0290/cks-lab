# Lab 4.2: Trivy - Quét lỗ hổng image

## Metadata

- **Domain**: 4 - Minimize Microservice Vulnerabilities
- **Difficulty**: Medium
- **Estimated Time**: 18 minutes
- **Exam Weight**: 15%

## Learning Objectives

- Understand Trivy - Quét lỗ hổng image

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- trivy
- kubectl configured
- Kubernetes cluster v1.29+

## Scenario

```bash
# Quét cơ bản
trivy image nginx:1.21

## Requirements

1. Create namespace `lab-4-2`
2. Scan `nginx:1.25` with Trivy for HIGH and CRITICAL vulnerabilities
3. Scan `nginx:1.21` and compare results with `nginx:1.25`
4. Create a ConfigMap `trivy-scan-results` with the scan summary
5. Create a Deployment with scan annotations

## Questions

> **Exam-style tasks** — Complete all tasks below before running `./verify.sh`

1. **Task**: Create namespace `lab-4-2`.

2. **Task**: Scan `nginx:1.25` for HIGH and CRITICAL vulnerabilities:
   ```bash
   trivy image --severity HIGH,CRITICAL nginx:1.25
   ```
   Note the total count of HIGH and CRITICAL findings.

3. **Task**: Scan `nginx:1.21` and compare:
   ```bash
   trivy image --severity HIGH,CRITICAL --exit-code 1 nginx:1.21 || echo "Vulnerabilities found"
   ```

4. **Task**: Create a ConfigMap named `trivy-scan-results` in namespace `lab-4-2` with:
   - Key `image`: `nginx:1.25`
   - Key `scan-date`: current UTC timestamp
   - Key `severity-filter`: `HIGH,CRITICAL`
   - Key `status`: `passed` or `failed`

5. **Task**: Create a Deployment named `scanned-app` in namespace `lab-4-2` using image `nginx:1.25` with pod template annotations:
   - `security.scan/tool: trivy`
   - `security.scan/status: passed`
   - `security.scan/critical-count: "0"`

6. **Verify**: Run `./verify.sh` — all checks must pass.

## Instructions

### Step 1: Set up the lab environment

Run the setup script to create the initial resources:

```bash
./setup.sh
```

This will create the necessary namespace and base resources.

### Step 2: Complete the main task

```bash
trivy image nginx:1.21
trivy image --severity HIGH,CRITICAL nginx:1.21

Execute the following commands:

```bash
trivy image nginx:1.21
```

```bash
trivy image --severity HIGH,CRITICAL nginx:1.21
```

```bash
trivy image --format json nginx:1.21
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
