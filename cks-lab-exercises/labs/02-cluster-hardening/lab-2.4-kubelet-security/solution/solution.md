# Solution: Lab 2.4 - Kubelet Security Configuration

## Overview

This solution provides step-by-step instructions for completing the Kubelet Security Configuration lab exercise.

## Solution Steps

### Step 1: Run the setup script

Execute the setup script to create the initial environment:

```bash
./setup.sh
```

### Step 2: Apply Unknown

Create a file with the following content:

```yaml
# /var/lib/kubelet/config.yaml
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false          # Quan trọng: tắt anonymous auth
  webhook:
    enabled: true
    cacheTTL: 2m
  x509:
    clientCAFile: /etc/kubernetes/pki/ca.crt
authorization:
  mode: Webhook             # Dùng Webhook (không dùng AlwaysAllow)
  webhook:
    cacheAuthorizedTTL: 5m
    cacheUnauthorizedTTL: 30s
address: 0.0.0.0
port: 10250
readOnlyPort: 0             # Quan trọng: tắt readonly port (mặc định 10255)
rotateCertificates: true
serverTLSBootstrap: true
clusterDomain: cluster.local
clusterDNS:
  - 10.96.0.10
maxPods: 110
staticPodPath: /etc/kubernetes/manifests
cgroupDriver: systemd
```

Apply the manifest:

```bash
kubectl apply -f <filename>
```

### Step 3: Verify the configuration

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

- Understanding Kubelet Security Configuration is essential for Kubernetes security
- Always verify configurations before deploying to production
- Security controls should be tested regularly
