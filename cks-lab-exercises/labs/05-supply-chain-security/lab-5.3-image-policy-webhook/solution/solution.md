# Solution: Lab 5.3 - ImagePolicyWebhook

## Overview

This solution provides step-by-step instructions for completing the ImagePolicyWebhook lab exercise.

## Solution Steps

### Step 1: Run the setup script

Execute the setup script to create the initial environment:

```bash
./setup.sh
```

### Step 2: Execute command 1

```bash
--enable-admission-plugins=...,ImagePolicyWebhook
```

### Step 3: Execute command 2

```bash
--admission-control-config-file=/etc/kubernetes/image-policy/admission_config.yaml
```

### Step 4: Verify the configuration

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

## Troubleshooting

**Issue**: Resources not being created

**Solution**: Check kubectl logs and describe the resources to see error messages. Verify YAML syntax and API versions.

**Issue**: Verification script fails

**Solution**: Review the specific check that failed. Use kubectl get/describe commands to inspect the actual state of resources.

## Key Takeaways

- Understanding ImagePolicyWebhook is essential for Kubernetes security
- Always verify configurations before deploying to production
- Security controls should be tested regularly
