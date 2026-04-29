# Solution: Lab 3.4 - Kernel Security Parameters (sysctl)

## Overview

This solution provides step-by-step instructions for completing the Kernel Security Parameters (sysctl) lab exercise.

## Solution Steps

### Step 1: Run the setup script

Execute the setup script to create the initial environment:

```bash
./setup.sh
```

### Step 2: Execute command 1

```bash
net.ipv4.ip_forward=0
```

### Step 3: Execute command 2

```bash
net.ipv4.conf.all.send_redirects=0
```

### Step 4: Execute command 3

```bash
net.ipv4.conf.default.send_redirects=0
```

### Step 5: Execute command 4

```bash
net.ipv4.conf.all.accept_source_route=0
```

### Step 6: Execute command 5

```bash
net.ipv4.conf.all.accept_redirects=0
```

### Step 7: Execute command 6

```bash
net.ipv4.icmp_echo_ignore_broadcasts=1
```

### Step 8: Execute command 7

```bash
net.ipv4.conf.all.log_martians=1
```

### Step 9: Execute command 8

```bash
kernel.kexec_load_disabled=1
```

### Step 10: Execute command 9

```bash
kernel.yama.ptrace_scope=1
```

### Step 11: Execute command 10

```bash
fs.protected_hardlinks=1
```

### Step 12: Execute command 11

```bash
fs.protected_symlinks=1
```

### Step 13: Execute command 12

```bash
fs.suid_dumpable=0
```

### Step 14: Execute command 13

```bash
sysctl -p /etc/sysctl.d/99-kubernetes-security.conf
```

### Step 15: Verify the configuration

Run the verification script to confirm everything is working:

```bash
./verify.sh
```

## Verification

After completing all steps, verify your solution:

```bash
./verify.sh
```

Expected output: All checks should pass.

## Common Mistakes

- Forgetting to create the namespace before applying resources
- Not waiting for resources to be ready before verification
- Incorrect YAML indentation
- Missing required labels or annotations
- Incorrect security context configuration
- Not considering resource dependencies

## Troubleshooting

**Issue**: Resources not being created

**Solution**: Check kubectl logs and describe the resources to see error messages. Verify YAML syntax and API versions.

**Issue**: Verification script fails

**Solution**: Review the specific check that failed. Use kubectl get/describe commands to inspect the actual state of resources.

## Key Takeaways

- Understanding Kernel Security Parameters (sysctl) is essential for Kubernetes security
- Always verify configurations before deploying to production
- Security controls should be tested regularly
