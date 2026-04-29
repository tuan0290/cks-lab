# Lab 4.5: Secret Management

## Metadata

- **Domain**: 4 - Minimize Microservice Vulnerabilities
- **Difficulty**: Medium
- **Estimated Time**: 20 minutes
- **Exam Weight**: 20%

## Learning Objectives

- Create and manage Kubernetes Secrets securely
- Mount secrets as environment variables and volumes
- Restrict Secret access using RBAC
- Understand Secret encryption at rest

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster

## Scenario

Your application needs database credentials stored securely. You must create Secrets, mount them properly, and restrict access using RBAC so only the application's ServiceAccount can read them.

## Requirements

1. Create namespace `lab-4-5`
2. Create a Secret `db-credentials` with `username` and `password` fields
3. Create a ServiceAccount `app-sa` with a Role allowing only `get` on the specific secret
4. Create a Pod `app-pod` that mounts the secret as a volume (not env vars)
5. Verify that another ServiceAccount cannot access the secret

## Questions

> **Exam-style tasks** — Complete all tasks below before running `./verify.sh`

1. **Task**: Create namespace `lab-4-5`.

2. **Task**: Create a Secret named `db-credentials` in namespace `lab-4-5` with:
   - `username: dbuser`
   - `password: S3cur3P@ssw0rd`
   Use `kubectl create secret generic`, not a YAML manifest with plaintext values.

3. **Task**: Create a ServiceAccount named `app-sa` in namespace `lab-4-5` with `automountServiceAccountToken: false`.

4. **Task**: Create a Role named `secret-reader` in namespace `lab-4-5` that allows only `get` on the specific secret `db-credentials` (use `resourceNames`).

5. **Task**: Create a RoleBinding named `app-secret-binding` binding `secret-reader` to `app-sa`.

6. **Task**: Create a Pod named `app-pod` in namespace `lab-4-5` that:
   - Uses ServiceAccount `app-sa`
   - Mounts `db-credentials` as a **volume** (not env vars) at `/etc/secrets`
   - Sets `defaultMode: 0400` on the secret volume
   - Has `readOnlyRootFilesystem: true`

7. **Verify**: Run `./verify.sh` — all checks must pass.

## Instructions

```bash
kubectl create secret generic db-credentials \
  --from-literal=username=dbuser \
  --from-literal=password=S3cur3P@ssw0rd \
  -n lab-4-5 \
  --dry-run=client -o yaml | kubectl apply -f -
```

### Step 3: Create RBAC for secret access

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa
  namespace: lab-4-5
automountServiceAccountToken: false
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader
  namespace: lab-4-5
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["db-credentials"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-secret-binding
  namespace: lab-4-5
subjects:
- kind: ServiceAccount
  name: app-sa
  namespace: lab-4-5
roleRef:
  kind: Role
  name: secret-reader
  apiGroup: rbac.authorization.k8s.io
EOF
```

### Step 4: Create the application pod mounting the secret

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: app-pod
  namespace: lab-4-5
spec:
  serviceAccountName: app-sa
  automountServiceAccountToken: false
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
        drop: [ALL]
        add: [NET_BIND_SERVICE]
    volumeMounts:
    - name: db-creds
      mountPath: /etc/secrets
      readOnly: true
    - name: tmp
      mountPath: /tmp
    - name: cache
      mountPath: /var/cache/nginx
    - name: run
      mountPath: /var/run
    resources:
      limits:
        cpu: "100m"
        memory: "64Mi"
  volumes:
  - name: db-creds
    secret:
      secretName: db-credentials
      defaultMode: 0400
  - name: tmp
    emptyDir: {}
  - name: cache
    emptyDir: {}
  - name: run
    emptyDir: {}
EOF
```

### Step 5: Verify your solution

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

- **Secret as volume**: More secure than env vars — not visible in `kubectl describe pod`
- **defaultMode: 0400**: Read-only for owner only
- **resourceNames**: RBAC can restrict access to specific named resources
- **Encryption at rest**: Enable EncryptionConfiguration to encrypt Secrets in etcd

## Additional Resources

- [Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Encrypting Secret Data at Rest](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/)
