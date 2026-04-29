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

1. Execute the necessary commands to configure Cấu hình API Server Security
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
