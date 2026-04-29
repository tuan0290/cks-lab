# Solution: Lab 6.6 - Audit Log Query & Analysis

## Overview

This solution provides step-by-step instructions for completing the Audit Log Query & Analysis lab exercise.

## Solution Steps

### Step 1: Run the setup script

Execute the setup script to create the initial environment:

```bash
./setup.sh
```

### Step 2: Execute command 1

```bash
grep '"resource":"secrets"' /var/log/kubernetes/audit.log | \
```

### Step 3: Execute command 2

```bash
jq 'select(.stage=="ResponseComplete") | {user, verb, resource, statusCode}'
```

### Step 4: Execute command 3

```bash
jq 'select(.responseStatus.code==401)' /var/log/kubernetes/audit.log
```

### Step 5: Execute command 4

```bash
jq 'select(.object.kind=="Deployment" and (.verb=="create" or .verb=="delete"))' \
```

### Step 6: Execute command 5

```bash
/var/log/kubernetes/audit.log
```

### Step 7: Execute command 6

```bash
jq -r '.user.username' /var/log/kubernetes/audit.log | \
```

### Step 8: Execute command 7

```bash
sort | uniq -c | sort -rn
```

### Step 9: Execute command 8

```bash
jq 'select(.requestReceivedTimestamp >= "2026-01-24T00:00:00Z")' \
```

### Step 10: Execute command 9

```bash
/var/log/kubernetes/audit.log
```

### Step 11: Execute command 10

```bash
jq 'select(.object.kind=="Secret" and .verb=="delete") |
```

### Step 12: Execute command 11

```bash
{user: .user.username, name: .object.metadata.name,
```

### Step 13: Execute command 12

```bash
namespace: .object.metadata.namespace, time: .requestReceivedTimestamp}' \
```

### Step 14: Execute command 13

```bash
/var/log/kubernetes/audit.log
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

- Understanding Audit Log Query & Analysis is essential for Kubernetes security
- Always verify configurations before deploying to production
- Security controls should be tested regularly
