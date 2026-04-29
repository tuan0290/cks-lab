# Lab 2.4: Kubelet Security Configuration

## Metadata

- **Domain**: 2 - Cluster Hardening
- **Difficulty**: Easy
- **Estimated Time**: 11 minutes
- **Exam Weight**: 15%

## Learning Objectives

- Understand Kubelet Security Configuration
- Configure Kubelet Security Configuration correctly
- Apply security best practices

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- kubectl configured
- Kubernetes cluster v1.29+

## Scenario

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
readOnlyPort: 0             # Quan trọng: tắt rea

## Requirements

1. Create namespace `lab-2-4`
2. Inspect the kubelet configuration at `/var/lib/kubelet/config.yaml`
3. Ensure `authentication.anonymous.enabled: false`
4. Ensure `authorization.mode: Webhook`
5. Ensure `readOnlyPort: 0` (disabled)
6. Create a ConfigMap `kubelet-security-audit` documenting the current and recommended settings

## Questions

> **Exam-style tasks** — Complete all tasks below before running `./verify.sh`

1. **Task**: Create namespace `lab-2-4`.

2. **Task**: Inspect the kubelet configuration:
   ```bash
   cat /var/lib/kubelet/config.yaml
   ```
   Verify or set the following security settings in `/var/lib/kubelet/config.yaml`:
   - `authentication.anonymous.enabled: false`
   - `authorization.mode: Webhook`
   - `readOnlyPort: 0`
   - `rotateCertificates: true`

3. **Task**: If you modified the kubelet config, restart the kubelet:
   ```bash
   systemctl restart kubelet
   systemctl status kubelet
   ```

4. **Task**: Verify anonymous access to the kubelet is blocked:
   ```bash
   curl -sk https://localhost:10250/pods
   # Should return 401 Unauthorized, not pod list
   ```

5. **Task**: Create a ConfigMap named `kubelet-security-audit` in namespace `lab-2-4` with keys:
   - `anonymous-auth`: `false`
   - `authorization-mode`: `Webhook`
   - `readonly-port`: `0`
   - `rotate-certificates`: `true`

6. **Verify**: Run `./verify.sh` — all checks must pass.

## Instructions

### Step 1: Set up the lab environment

Run the setup script to create the initial resources:

```bash
./setup.sh
```

This will create the necessary namespace and base resources.

### Step 2: Complete the main task

```yaml
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:

Create and apply the following Kubernetes resources:

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
