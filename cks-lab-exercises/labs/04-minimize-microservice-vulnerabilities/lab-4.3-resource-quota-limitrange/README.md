# Lab 4.3: ResourceQuota & LimitRange

## Metadata

- **Domain**: 4 - Minimize Microservice Vulnerabilities
- **Difficulty**: Easy
- **Estimated Time**: 11 minutes
- **Exam Weight**: 15%

## Learning Objectives

- Understand ResourceQuota & LimitRange

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- kubectl configured
- Kubernetes cluster v1.29+

## Scenario

```yaml
# ResourceQuota — Giới hạn tổng tài nguyên namespace
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-resources
  namespace: production
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    persistentvolumeclaims: "4"
---
# LimitRange — Giới hạn mặc định cho từng Pod/Container
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: production
spec:
  limits:
  - default:          # Limit mặc định nế

## Requirements

1. Create namespace `lab-4-3`
2. Create a ResourceQuota `lab-quota` limiting CPU, memory, and pod count
3. Create a LimitRange `lab-limits` setting default CPU/memory limits
4. Verify a Pod without resource limits gets defaults applied from LimitRange

## Questions

> **Exam-style tasks** — Complete all tasks below before running `./verify.sh`

1. **Task**: Create namespace `lab-4-3`.

2. **Task**: Create a ResourceQuota named `lab-quota` in namespace `lab-4-3` with:
   - `pods: "5"`
   - `requests.cpu: "1"`
   - `requests.memory: 1Gi`
   - `limits.cpu: "2"`
   - `limits.memory: 2Gi`

3. **Task**: Create a LimitRange named `lab-limits` in namespace `lab-4-3` with container defaults:
   - `default.cpu: 200m`
   - `default.memory: 128Mi`
   - `defaultRequest.cpu: 100m`
   - `defaultRequest.memory: 64Mi`
   - `max.cpu: 500m`
   - `max.memory: 512Mi`

4. **Task**: Create a Pod named `test-pod` in namespace `lab-4-3` **without** specifying resource limits. Then verify the LimitRange applied defaults:
   ```bash
   kubectl get pod test-pod -n lab-4-3 \
     -o jsonpath='{.spec.containers[0].resources}'
   # Should show cpu: 200m, memory: 128Mi from LimitRange defaults
   ```

5. **Task**: Verify the ResourceQuota status:
   ```bash
   kubectl describe resourcequota lab-quota -n lab-4-3
   ```

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
apiVersion: v1
kind: ResourceQuota

Create and apply the following Kubernetes resources:

```yaml
# ResourceQuota — Giới hạn tổng tài nguyên namespace
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-resources
  namespace: production
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    persistentvolumeclaims: "4"
---
# LimitRange — Giới hạn mặc định cho từng Pod/Container
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: production
spec:
  limits:
  - default:          # Limit mặc định nếu không khai báo
      cpu: 500m
      memory: 512Mi
    defaultRequest:   # Request mặc định nếu không khai báo
      cpu: 100m
      memory: 128Mi
    max:              # Giới hạn tối đa
      cpu: "2"
      memory: 4Gi
    min:              # Giới hạn tối thiểu
      cpu: 50m
      memory: 64Mi
    type: Container
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
