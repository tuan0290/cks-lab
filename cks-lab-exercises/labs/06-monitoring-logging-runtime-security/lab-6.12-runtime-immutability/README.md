# Lab 6.12: Runtime Immutability - Immutable Containers and Read-Only Filesystems

## Metadata

- **Domain**: 6 - Monitoring, Logging & Runtime Security
- **Difficulty**: Medium
- **Estimated Time**: 25 minutes
- **Exam Weight**: 20%

## Learning Objectives

- Configure containers with read-only root filesystems
- Use `emptyDir` volumes for writable temporary storage
- Implement immutable container patterns to prevent runtime modifications
- Detect filesystem write attempts using Falco
- Understand the security benefits of immutable infrastructure
- Apply runtime immutability at both pod and container levels

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- Basic understanding of Kubernetes security contexts

## Scenario

Your security policy requires that all production containers run with immutable filesystems to prevent attackers from modifying container contents at runtime. You need to configure pods with `readOnlyRootFilesystem: true` and provide writable volumes only for necessary temporary directories. Additionally, you must set up Falco rules to detect any attempts to write to the filesystem.

## Requirements

1. Deploy a pod with `readOnlyRootFilesystem: true` in the security context
2. Mount an `emptyDir` volume at `/tmp` for temporary file storage
3. Mount an `emptyDir` volume at `/var/cache` for cache storage
4. Verify the container cannot write to the root filesystem
5. Verify the container CAN write to the mounted writable volumes
6. Create a Falco rule to detect write attempts to read-only filesystems
7. Apply the immutability configuration to a Deployment

## Questions

> **Exam-style tasks** — Complete all tasks below before running `./verify.sh`

1. **Task**: Create namespace `lab-6-12`.

2. **Task**: Create a Pod named `immutable-pod` in namespace `lab-6-12` using image `nginx:1.25` with:
   - `securityContext.readOnlyRootFilesystem: true`
   - `securityContext.runAsNonRoot: true`, `runAsUser: 101`
   - `securityContext.allowPrivilegeEscalation: false`
   - `securityContext.capabilities.drop: [ALL]`, `add: [NET_BIND_SERVICE]`
   - `emptyDir` volumes mounted at `/tmp`, `/var/cache/nginx`, `/var/run`

3. **Task**: Verify the root filesystem is read-only:
   ```bash
   kubectl exec immutable-pod -n lab-6-12 -- touch /test-file 2>&1
   # Expected: touch: /test-file: Read-only file system
   ```

4. **Task**: Verify writable volumes work:
   ```bash
   kubectl exec immutable-pod -n lab-6-12 -- touch /tmp/test-file
   # Expected: success (no error)
   ```

5. **Task**: Create a Deployment named `immutable-deployment` in namespace `lab-6-12` with 2 replicas applying the same immutability settings.

6. **Task**: Create a ConfigMap named `falco-immutability-rule` in namespace `lab-6-12` with a Falco rule that detects writes to container root filesystems (excluding `/tmp`, `/var/cache`, `/var/run`).

7. **Verify**: Run `./verify.sh` — all checks must pass.

## Instructions

### Step 1: Set up the lab environment

```bash
./setup.sh
```

### Step 2: Create a pod with read-only root filesystem

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: immutable-pod
  namespace: lab-6-12
  labels:
    app: immutable-app
spec:
  containers:
  - name: app
    image: nginx:1.25
    securityContext:
      readOnlyRootFilesystem: true
      runAsNonRoot: true
      runAsUser: 101
      allowPrivilegeEscalation: false
    volumeMounts:
    - name: tmp-volume
      mountPath: /tmp
    - name: cache-volume
      mountPath: /var/cache/nginx
    - name: run-volume
      mountPath: /var/run
  volumes:
  - name: tmp-volume
    emptyDir: {}
  - name: cache-volume
    emptyDir: {}
  - name: run-volume
    emptyDir: {}
EOF
```

### Step 3: Verify read-only filesystem enforcement

```bash
# Wait for pod to be ready
kubectl wait --for=condition=Ready pod/immutable-pod -n lab-6-12 --timeout=60s

# Try to write to root filesystem (should FAIL)
kubectl exec -n lab-6-12 immutable-pod -- touch /test-file 2>&1 || echo "Write blocked as expected"

# Try to write to /tmp (should SUCCEED)
kubectl exec -n lab-6-12 immutable-pod -- touch /tmp/test-file && echo "Write to /tmp succeeded"

# Try to write to /var/cache/nginx (should SUCCEED)
kubectl exec -n lab-6-12 immutable-pod -- touch /var/cache/nginx/test && echo "Write to cache succeeded"
```

### Step 4: Create a Deployment with immutability enforced

```bash
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: immutable-deployment
  namespace: lab-6-12
spec:
  replicas: 2
  selector:
    matchLabels:
      app: immutable-deployment
  template:
    metadata:
      labels:
        app: immutable-deployment
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 2000
      containers:
      - name: app
        image: busybox:1.35
        command: ["sleep", "3600"]
        securityContext:
          readOnlyRootFilesystem: true
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
        volumeMounts:
        - name: tmp
          mountPath: /tmp
      volumes:
      - name: tmp
        emptyDir: {}
EOF
```

### Step 5: Create Falco rule to detect filesystem write attempts

Create `falco-immutability-rules.yaml`:

```yaml
# falco-immutability-rules.yaml
- rule: Write to Non-Writable Volume
  desc: Detect write attempt to a container's read-only filesystem
  condition: >
    open_write and
    container and
    not fd.name startswith /tmp and
    not fd.name startswith /var/cache and
    not fd.name startswith /var/run and
    not fd.name startswith /proc and
    not fd.name startswith /dev
  output: >
    Write to read-only filesystem detected (user=%user.name
    command=%proc.cmdline file=%fd.name container=%container.name
    image=%container.image.repository pod=%k8s.pod.name)
  priority: WARNING
  tags: [filesystem, immutability, cks]
```

```bash
kubectl create configmap falco-immutability-rules \
  --from-file=falco-immutability-rules.yaml \
  -n falco \
  --dry-run=client -o yaml | kubectl apply -f -
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

## Additional Resources

- [Kubernetes Security Contexts](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/)
- [Immutable Infrastructure](https://kubernetes.io/docs/concepts/workloads/pods/#pod-immutability)
- [CKS Exam Curriculum](https://github.com/cncf/curriculum)
