# Solution: Lab 6.12 - Runtime Immutability - Immutable Containers and Read-Only Filesystems

## Overview

This solution demonstrates how to implement immutable container patterns using `readOnlyRootFilesystem` and `emptyDir` volumes.

## Step-by-Step Solution

### Step 1: Create immutable pod

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

### Step 2: Verify read-only enforcement

```bash
# This should FAIL with "Read-only file system"
kubectl exec -n lab-6-12 immutable-pod -- touch /test-file
# Output: touch: /test-file: Read-only file system

# This should SUCCEED
kubectl exec -n lab-6-12 immutable-pod -- touch /tmp/test-file
# Output: (no error)

# This should SUCCEED
kubectl exec -n lab-6-12 immutable-pod -- touch /var/cache/nginx/test
# Output: (no error)
```

### Step 3: Create immutable deployment

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

### Step 4: Deploy Falco rules

```bash
cat > falco-immutability-rules.yaml << 'EOF'
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
EOF

kubectl create configmap falco-immutability-rules \
  --from-file=falco-immutability-rules.yaml \
  -n falco \
  --dry-run=client -o yaml | kubectl apply -f -
```

## Key Concepts

### readOnlyRootFilesystem

Setting `readOnlyRootFilesystem: true` in the container's `securityContext` mounts the container's root filesystem as read-only. This prevents:
- Malware installation
- Configuration tampering
- Log injection
- Binary replacement

### emptyDir Volumes

`emptyDir` volumes provide writable temporary storage that:
- Is created when the pod starts
- Is deleted when the pod terminates
- Is not shared between pods
- Can be used for `/tmp`, cache directories, and runtime files

### Common Writable Directories Needed

| Directory | Purpose |
|-----------|---------|
| `/tmp` | Temporary files |
| `/var/cache` | Application cache |
| `/var/run` | PID files, sockets |
| `/var/log` | Log files (if not using stdout) |

## Security Benefits

1. **Prevents runtime modification**: Attackers cannot install tools or modify binaries
2. **Reduces attack surface**: No persistent changes survive container restart
3. **Compliance**: Meets immutable infrastructure requirements
4. **Forensics**: Container state is predictable and auditable

## CKS Exam Tips

- `readOnlyRootFilesystem: true` is a key security context setting
- Always pair with `emptyDir` volumes for necessary writable paths
- Combine with `allowPrivilegeEscalation: false` and `capabilities.drop: [ALL]`
- Know that nginx needs `/var/cache/nginx`, `/var/run`, and `/tmp` to be writable
