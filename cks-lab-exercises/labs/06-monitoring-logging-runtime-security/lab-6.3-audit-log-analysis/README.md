# Lab 6.3: Audit Log Query & Analysis

## Metadata

- **Domain**: 6 - Monitoring, Logging & Runtime Security
- **Difficulty**: Hard
- **Estimated Time**: 22 minutes
- **Exam Weight**: 15%

## Learning Objectives

- Understand Audit Log Query & Analysis

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- kubectl configured
- Kubernetes cluster v1.29+

## Scenario

```bash
# Tìm các thao tác với Secret
grep '"resource":"secrets"' /var/log/kubernetes/audit.log | \
  jq 'select(.stage=="ResponseComplete") | {user, verb, resource, statusCode}'

## Requirements

1. Create namespace `lab-6-3`
2. Ensure audit logging is enabled on the API server
3. Query audit logs to find Secret access events
4. Query audit logs to find failed authentication attempts
5. Create ConfigMaps documenting the analysis results

## Questions

> **Exam-style tasks** — Complete all tasks below before running `./verify.sh`

1. **Task**: Create namespace `lab-6-3`.

2. **Task**: Verify audit logging is enabled and find the log file:
   ```bash
   grep "audit-log-path" /etc/kubernetes/manifests/kube-apiserver.yaml
   # Note the path, typically /var/log/kubernetes/audit.log
   ```

3. **Task**: Query the audit log to find all Secret access events:
   ```bash
   grep '"resource":"secrets"' /var/log/kubernetes/audit.log | \
     jq -r 'select(.stage=="ResponseComplete") | "\(.user.username) \(.verb) \(.objectRef.name) \(.responseStatus.code)"' | \
     tail -20
   ```

4. **Task**: Query the audit log to find failed requests (HTTP 403/401):
   ```bash
   cat /var/log/kubernetes/audit.log | \
     jq -r 'select(.responseStatus.code >= 400) | "\(.user.username) \(.verb) \(.objectRef.resource) \(.responseStatus.code)"' | \
     tail -20
   ```

5. **Task**: Create a ConfigMap named `audit-analysis-results` in namespace `lab-6-3` with:
   - `secret-access-count`: number of secret access events found
   - `failed-requests-count`: number of 4xx responses found
   - `analysis-date`: current timestamp
   - `audit-log-path`: path to the audit log file

6. **Task**: Create a ConfigMap named `audit-query-commands` in namespace `lab-6-3` documenting 4 useful `jq` queries for audit log analysis.

7. **Verify**: Run `./verify.sh` — all checks must pass.

## Instructions

### Step 1: Set up the lab environment

Run the setup script to create the initial resources:

```bash
./setup.sh
```

This will create the necessary namespace and base resources.

### Step 2: Complete the main task

```bash
grep '"resource":"secrets"' /var/log/kubernetes/audit.log | \
  jq 'select(.stage=="ResponseComplete") | {user, verb, resource, statusCode}'

Execute the following commands:

```bash
grep '"resource":"secrets"' /var/log/kubernetes/audit.log | \
```

```bash
jq 'select(.stage=="ResponseComplete") | {user, verb, resource, statusCode}'
```

```bash
jq 'select(.responseStatus.code==401)' /var/log/kubernetes/audit.log
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
