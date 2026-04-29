# Lab 2.1: Cấu hình API Server Security

## Metadata

- **Domain**: 2 - Cluster Hardening
- **Difficulty**: Hard
- **Estimated Time**: 19 minutes
- **Exam Weight**: 15%

## Learning Objectives

- Understand Cấu hình API Server Security
- Apply security best practices

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- kubectl configured
- Kubernetes cluster v1.29+

## Scenario

```bash
# Các tham số quan trọng của kube-apiserver
--anonymous-auth=false                              # Tắt anonymous access
--authorization-mode=Node,RBAC                      # Chỉ dùng RBAC
--enable-admission-plugins=NodeRestriction,EventRateLimit
--secure-port=6443                                  # Chỉ dùng HTTPS
--tls-cert-file=/etc/kubernetes/pki/apiserver.crt
--tls-private-key-file=/etc/kubernetes/pki/apiserver.key
--client-ca-file=/etc/kubernetes/pki/ca.crt
--service-account-lookup=t

## Requirements

1. Create namespace `lab-2-1` with label `security=api-server`
2. Audit the current kube-apiserver flags and document findings
3. Create a ConfigMap `apiserver-security-audit` documenting current vs recommended flags
4. Create a ConfigMap `apiserver-hardening-plan` with specific remediation steps

## Questions

> **Exam-style tasks** — Complete all tasks below before running `./verify.sh`

1. **Task**: Create namespace `lab-2-1` with label `security=api-server`.

2. **Task**: Inspect the current kube-apiserver configuration:
   ```bash
   cat /etc/kubernetes/manifests/kube-apiserver.yaml | grep -E "\-\-"
   ```
   Identify which of these security flags are present or missing:
   - `--anonymous-auth=false`
   - `--authorization-mode=Node,RBAC`
   - `--enable-admission-plugins=NodeRestriction`
   - `--audit-log-path`
   - `--profiling=false`

3. **Task**: Create a ConfigMap named `apiserver-security-audit` in namespace `lab-2-1` with:
   - Key `anonymous-auth`: current value (true/false)
   - Key `authorization-mode`: current value
   - Key `admission-plugins`: current enabled plugins
   - Key `audit-logging`: enabled or disabled

4. **Task**: Create a ConfigMap named `apiserver-hardening-plan` in namespace `lab-2-1` documenting at least 4 recommended flags with their values and the security reason for each.

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
--anonymous-auth=false                              # Tắt anonymous access
--authorization-mode=Node,RBAC                      # Chỉ dùng RBAC

Execute the following commands:

```bash
--anonymous-auth=false                              # Tắt anonymous access
```

```bash
--authorization-mode=Node,RBAC                      # Chỉ dùng RBAC
```

```bash
--enable-admission-plugins=NodeRestriction,EventRateLimit
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
