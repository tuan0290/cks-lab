# Lab 3.6: IAM Roles and Cloud Identity Management

## Metadata

- **Domain**: 3 - System Hardening
- **Difficulty**: Medium
- **Estimated Time**: 20 minutes
- **Exam Weight**: 10%

## Learning Objectives

- Understand how cloud IAM roles interact with Kubernetes workloads
- Configure Workload Identity / IRSA (IAM Roles for Service Accounts)
- Restrict pod access to cloud metadata and IAM credentials
- Apply least-privilege IAM principles to Kubernetes workloads

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster

## Scenario

Your Kubernetes workloads are running on a cloud provider and some pods need access to cloud services (e.g., S3, GCS). Currently, all pods on a node share the same IAM role, which is overly permissive. You need to implement workload identity to give each pod only the permissions it needs.

## Requirements

1. Create namespace `lab-3-6`
2. Create a ServiceAccount `cloud-access-sa` with an annotation simulating workload identity
3. Create a Pod `cloud-app` using the annotated ServiceAccount
4. Create a ConfigMap `iam-best-practices` documenting IAM security best practices
5. Create a NetworkPolicy `block-metadata` to prevent unauthorized metadata access

## Questions

> **Exam-style tasks** — Complete all tasks below before running `./verify.sh`

1. **Task**: Create namespace `lab-3-6`.

2. **Task**: Create a ServiceAccount named `cloud-access-sa` in namespace `lab-3-6` with a workload identity annotation:
   ```yaml
   annotations:
     eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/my-app-role"
   ```

3. **Task**: Create a Pod named `cloud-app` in namespace `lab-3-6` using ServiceAccount `cloud-access-sa` with:
   - `securityContext.runAsNonRoot: true`, `runAsUser: 1000`
   - `containers[0].securityContext.allowPrivilegeEscalation: false`
   - `containers[0].securityContext.readOnlyRootFilesystem: true`

4. **Task**: Create a NetworkPolicy named `block-metadata` in namespace `lab-3-6` that blocks egress to `169.254.169.254/32` for all pods.

5. **Task**: Create a ConfigMap named `iam-best-practices` in namespace `lab-3-6` documenting:
   - The 3 major cloud workload identity mechanisms (AWS IRSA, GCP Workload Identity, Azure Workload Identity)
   - Why blocking the metadata API is important
   - At least 3 IAM anti-patterns to avoid

6. **Verify**: Run `./verify.sh` — all checks must pass.

## Instructions

```bash
# AWS IRSA example annotation
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cloud-access-sa
  namespace: lab-3-6
  annotations:
    # AWS IRSA
    eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/my-app-role"
    # GCP Workload Identity
    # iam.gke.io/gcp-service-account: "my-app@my-project.iam.gserviceaccount.com"
    # Azure Workload Identity
    # azure.workload.identity/client-id: "00000000-0000-0000-0000-000000000000"
automountServiceAccountToken: true
EOF
```

### Step 3: Create the cloud application pod

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: cloud-app
  namespace: lab-3-6
  labels:
    app: cloud-app
spec:
  serviceAccountName: cloud-access-sa
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
  containers:
  - name: app
    image: nginx:1.25
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
    resources:
      limits:
        cpu: "100m"
        memory: "64Mi"
    volumeMounts:
    - name: tmp
      mountPath: /tmp
  volumes:
  - name: tmp
    emptyDir: {}
EOF
```

### Step 4: Block metadata access with NetworkPolicy

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: block-metadata
  namespace: lab-3-6
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
        except:
        - 169.254.169.254/32
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
EOF
```

### Step 5: Create IAM best practices ConfigMap

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: iam-best-practices
  namespace: lab-3-6
data:
  best-practices.md: |
    # IAM Best Practices for Kubernetes
    
    ## Workload Identity (Recommended)
    - AWS: Use IRSA (IAM Roles for Service Accounts)
    - GCP: Use Workload Identity
    - Azure: Use Azure Workload Identity
    
    ## Principles
    - Least privilege: Each pod gets only the permissions it needs
    - No shared node IAM roles for application access
    - Rotate credentials regularly
    - Audit IAM usage with CloudTrail/Cloud Audit Logs
    
    ## Anti-patterns to Avoid
    - Mounting cloud credentials as Secrets
    - Using node IAM roles for application access
    - Overly permissive IAM policies
    - Accessing metadata API without restriction
    
    ## Blocking Metadata API
    - Use NetworkPolicy to block 169.254.169.254
    - Use Workload Identity instead of instance metadata
EOF
```

### Step 6: Verify your solution

```bash
./verify.sh
```

## Verification

```bash
./verify.sh
```

## Cleanup

```bash
./cleanup.sh
```

## Key Concepts

- **IRSA**: IAM Roles for Service Accounts — AWS mechanism for pod-level IAM
- **Workload Identity**: GCP mechanism for pod-level IAM
- **Instance metadata API**: Cloud endpoint at 169.254.169.254 that exposes node credentials
- **Least privilege IAM**: Each workload should have only the permissions it needs

## Additional Resources

- [AWS IRSA](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- [GCP Workload Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)
- [Azure Workload Identity](https://azure.github.io/azure-workload-identity/)
