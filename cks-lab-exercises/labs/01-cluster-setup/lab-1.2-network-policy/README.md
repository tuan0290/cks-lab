# Lab 1.2: NetworkPolicy - Deny All Ingress

## Metadata

- **Domain**: 1 - Cluster Setup
- **Difficulty**: Medium
- **Estimated Time**: 13 minutes
- **Exam Weight**: 15%

## Learning Objectives

- Understand NetworkPolicy - Deny All Ingress
- Create and enforce policies

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- kubectl configured
- Kubernetes cluster v1.29+

## Scenario

```yaml
# Chặn tất cả ingress traffic vào namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```

## Requirements

1. Create namespace `lab-1-2` with label `env=lab`
2. Deploy pods `frontend` (label: `app=frontend`) and `backend` (label: `app=backend`) in namespace `lab-1-2`
3. Create a NetworkPolicy `default-deny-ingress` that denies all ingress to all pods in `lab-1-2`
4. Create a NetworkPolicy `allow-frontend-to-backend` that allows only `frontend` pods to reach `backend` pods on port 8080

## Questions

> **Exam-style tasks** — Complete all tasks below before running `./verify.sh`

1. **Task**: Create namespace `lab-1-2` with label `env=lab`.

2. **Task**: Create a Pod named `frontend` in namespace `lab-1-2` with label `app=frontend` using image `nginx:1.25`.

3. **Task**: Create a Pod named `backend` in namespace `lab-1-2` with label `app=backend` using image `nginx:1.25`.

4. **Task**: Create a NetworkPolicy named `default-deny-ingress` in namespace `lab-1-2` that:
   - Applies to **all pods** (`podSelector: {}`)
   - Denies **all ingress** traffic (policyTypes: `[Ingress]` with no ingress rules)

5. **Task**: Create a NetworkPolicy named `allow-frontend-to-backend` in namespace `lab-1-2` that:
   - Applies to pods with label `app=backend`
   - Allows ingress **only** from pods with label `app=frontend`
   - Only on TCP port `8080`

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
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy

Create and apply the following Kubernetes resources:

```yaml
# Chặn tất cả ingress traffic vào namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```

```yaml
# Cho phép frontend → backend port 8080
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
```
*- Ingress*


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
