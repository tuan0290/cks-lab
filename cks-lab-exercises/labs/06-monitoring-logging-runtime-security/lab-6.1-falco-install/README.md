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

1. Create namespace `falco` and install Falco using Helm with eBPF driver
2. Verify Falco pods are running and generating events
3. Create a ConfigMap `falco-install-config` documenting the installation
4. Test Falco is detecting events by triggering a known rule

## Questions

> **Exam-style tasks** — Complete all tasks below before running `./verify.sh`

1. **Task**: Install Falco using Helm in namespace `falco`:
   ```bash
   helm repo add falcosecurity https://falcosecurity.github.io/charts
   helm repo update
   helm install falco falcosecurity/falco \
     --namespace falco --create-namespace \
     --set driver.kind=ebpf \
     --set tty=true
   ```

2. **Task**: Verify Falco pods are running:
   ```bash
   kubectl get pods -n falco
   kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=20
   ```

3. **Task**: Trigger a Falco alert by running a shell in a container:
   ```bash
   kubectl run test-falco --image=alpine:3.19 -it --rm \
     --restart=Never -- sh -c "cat /etc/shadow 2>/dev/null; exit 0"
   ```
   Then check Falco logs for the alert.

4. **Task**: Create a ConfigMap named `falco-install-config` in namespace `falco` documenting:
   - Driver type used (`ebpf`)
   - Helm chart version
   - How to view Falco alerts: `kubectl logs -n falco -l app.kubernetes.io/name=falco`
   - Key default rules that are active

5. **Verify**: Run `./verify.sh` — all checks must pass.

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
