# Lab 6.1: Cài đặt Falco

## Metadata

- **Domain**: 6 - Monitoring, Logging & Runtime Security
- **Difficulty**: Hard
- **Estimated Time**: 19 minutes
- **Exam Weight**: 15%

## Learning Objectives

- Understand Cài đặt Falco

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- falco
- kubectl configured
- Kubernetes cluster v1.29+

## Scenario

```bash
# Cài Falco bằng Helm
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update
helm install falco falcosecurity/falco \
  --namespace falco --create-namespace \
  --set driver.kind=ebpf \
  --set tty=true

## Requirements

1. Execute the necessary commands to configure Cài đặt Falco
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
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update

Execute the following commands:

```bash
helm repo add falcosecurity https://falcosecurity.github.io/charts
```

```bash
helm repo update
```

```bash
helm install falco falcosecurity/falco \
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
