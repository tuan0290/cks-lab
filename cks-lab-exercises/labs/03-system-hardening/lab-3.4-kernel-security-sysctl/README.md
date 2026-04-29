# Lab 3.4: Kernel Security Parameters (sysctl)

## Metadata

- **Domain**: 3 - System Hardening
- **Difficulty**: Hard
- **Estimated Time**: 22 minutes
- **Exam Weight**: 15%

## Learning Objectives

- Understand Kernel Security Parameters (sysctl)
- Apply security best practices

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- kubectl configured
- Kubernetes cluster v1.29+

## Scenario

```bash
# /etc/sysctl.d/99-kubernetes-security.conf

## Requirements

1. Create namespace `lab-3-4`
2. Apply kernel security parameters via sysctl on the node
3. Create a Pod using `securityContext.sysctls` for namespace-scoped parameters
4. Create a ConfigMap documenting the sysctl settings

## Questions

> **Exam-style tasks** — Complete all tasks below before running `./verify.sh`

1. **Task**: Create namespace `lab-3-4`.

2. **Task**: Apply node-level sysctl hardening on the node:
   ```bash
   # Disable IP forwarding (if not needed)
   sysctl -w net.ipv4.ip_forward=0
   # Disable ICMP redirects
   sysctl -w net.ipv4.conf.all.accept_redirects=0
   sysctl -w net.ipv4.conf.all.send_redirects=0
   # Enable SYN flood protection
   sysctl -w net.ipv4.tcp_syncookies=1
   ```
   Make persistent: `echo "net.ipv4.conf.all.accept_redirects=0" >> /etc/sysctl.d/99-k8s-security.conf`

3. **Task**: Create a Pod named `sysctl-pod` in namespace `lab-3-4` using image `nginx:1.25` with namespace-scoped sysctl settings:
   ```yaml
   securityContext:
     sysctls:
     - name: net.core.somaxconn
       value: "1024"
   ```

4. **Task**: Create a ConfigMap named `sysctl-security-config` in namespace `lab-3-4` documenting at least 5 sysctl parameters with their security purpose:
   - `net.ipv4.conf.all.accept_redirects=0` — disable ICMP redirects
   - `net.ipv4.tcp_syncookies=1` — SYN flood protection
   - `kernel.dmesg_restrict=1` — restrict dmesg access
   - `kernel.kptr_restrict=2` — hide kernel pointers
   - `net.ipv4.conf.all.rp_filter=1` — reverse path filtering

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
net.ipv4.ip_forward=0
net.ipv4.conf.all.send_redirects=0

Execute the following commands:

```bash
net.ipv4.ip_forward=0
```

```bash
net.ipv4.conf.all.send_redirects=0
```

```bash
net.ipv4.conf.default.send_redirects=0
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
