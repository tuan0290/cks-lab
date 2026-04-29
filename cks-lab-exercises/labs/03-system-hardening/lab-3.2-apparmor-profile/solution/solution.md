# Solution: Lab 3.2 - AppArmor Configuration

## Overview

This solution provides step-by-step instructions for completing the AppArmor Configuration lab exercise.

## Solution Steps

### Step 1: Run the setup script

Execute the setup script to create the initial environment:

```bash
./setup.sh
```

### Step 2: Execute command 1

```bash
profile nginx-apparmor flags=(attach_disconnected) {
```

### Step 3: Execute command 2

```bash
network inet stream,
```

### Step 4: Execute command 3

```bash
network inet6 stream,
```

### Step 5: Execute command 4

```bash
/etc/nginx/** r,
```

### Step 6: Execute command 5

```bash
/var/www/** r,
```

### Step 7: Execute command 6

```bash
/var/log/nginx/** w,
```

### Step 8: Execute command 7

```bash
/run/nginx.pid w,
```

### Step 9: Execute command 8

```bash
capability setgid,
```

### Step 10: Execute command 9

```bash
capability setuid,
```

### Step 11: Execute command 10

```bash
deny /etc/shadow rwx,
```

### Step 12: Execute command 11

```bash
deny /root/** rwx,
```

### Step 13: Execute command 12

```bash
audit deny /** w,
```

### Step 14: Execute command 13

```bash
}
```

### Step 15: }

```bash
sudo apparmor_parser -r /etc/apparmor.d/nginx-apparmor
```

}

### Step 16: }

```bash
sudo aa-status | grep nginx
```

}

### Step 17: sudo aa-status | grep nginx

Create a file with the following content:

```yaml
# Áp dụng AppArmor vào Pod
apiVersion: v1
kind: Pod
metadata:
  name: nginx-apparmor
spec:
  containers:
  - name: nginx
    image: nginx
    securityContext:
      appArmorProfile:
        type: Localhost
        localhostProfile: nginx-apparmor
```

Apply the manifest:

```bash
kubectl apply -f <filename>
```

### Step 18: Verify the configuration

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

- Understanding AppArmor Configuration is essential for Kubernetes security
- Always verify configurations before deploying to production
- Security controls should be tested regularly
