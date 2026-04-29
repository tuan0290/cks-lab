# Cheatsheet 04 – Minimize Microservice Vulnerabilities (20%)

## Trivy Image Scanning

### Basic scan
```bash
# Scan an image
trivy image nginx:1.25

# Scan with severity filter
trivy image --severity HIGH,CRITICAL nginx:1.25

# Scan only CRITICAL
trivy image --severity CRITICAL nginx:1.25

# Output as JSON
trivy image --format json --output results.json nginx:1.25

# Scan and exit with non-zero if vulnerabilities found
trivy image --exit-code 1 --severity CRITICAL nginx:1.25

# Ignore unfixed vulnerabilities
trivy image --ignore-unfixed nginx:1.25

# Scan a local tarball
trivy image --input image.tar

# Scan with specific vuln types
trivy image --vuln-type os,library nginx:1.25
```

### Scan a running pod's image
```bash
# Get image name from pod
IMAGE=$(kubectl get pod <pod-name> -o jsonpath='{.spec.containers[0].image}')
trivy image --severity CRITICAL $IMAGE
```

---

## EncryptionConfiguration (Secret at Rest)

### Generate AES key (32 bytes, base64)
```bash
head -c 32 /dev/urandom | base64
```

### EncryptionConfiguration YAML
```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
- resources:
  - secrets
  providers:
  - aescbc:
      keys:
      - name: key1
        secret: <base64-encoded-32-byte-key>
  - identity: {}   # Fallback: allows reading unencrypted secrets
```

### Apply to kube-apiserver
```bash
# 1. Save config to /etc/kubernetes/enc/encryption-config.yaml
# 2. Add to /etc/kubernetes/manifests/kube-apiserver.yaml:
#    --encryption-provider-config=/etc/kubernetes/enc/encryption-config.yaml
# 3. Mount the file in the static pod spec (hostPath volume)

# 4. Restart kube-apiserver (edit manifest triggers restart)
# 5. Re-encrypt existing secrets
kubectl get secrets -A -o json | kubectl replace -f -
```

### Verify encryption in etcd
```bash
# Check that secret value is encrypted (should show 'k8s:enc:aescbc:' prefix)
ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/<namespace>/<secret-name> | hexdump -C | head -20

# If encrypted, output starts with: k8s:enc:aescbc:v1:key1:
```

---

## RuntimeClass (gVisor / Kata Containers)

### RuntimeClass YAML for gVisor
```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc          # gVisor handler name
```

### RuntimeClass YAML for Kata Containers
```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: kata-containers
handler: kata
```

### Use RuntimeClass in Pod
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: sandboxed-pod
spec:
  runtimeClassName: gvisor
  containers:
  - name: app
    image: nginx:1.25
```

### Commands
```bash
kubectl get runtimeclass
kubectl describe runtimeclass gvisor
# Verify pod is using sandbox runtime
kubectl get pod <name> -o jsonpath='{.spec.runtimeClassName}'
```

---

## Secret Volume Mount

### Secret as volume (recommended)
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-pod
spec:
  containers:
  - name: app
    image: nginx:1.25
    volumeMounts:
    - name: secret-vol
      mountPath: /etc/secrets
      readOnly: true
  volumes:
  - name: secret-vol
    secret:
      secretName: my-secret
      defaultMode: 0400    # Owner read-only (octal)
```

### Mount specific keys only
```yaml
  volumes:
  - name: secret-vol
    secret:
      secretName: my-secret
      defaultMode: 0400
      items:
      - key: username
        path: username.txt
      - key: password
        path: password.txt
        mode: 0400
```

### Secret as env var (avoid in CKS — visible in kubectl describe)
```yaml
# AVOID: exposes secret in pod description
env:
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: my-secret
      key: password
```

### Commands
```bash
# Create secret
kubectl create secret generic my-secret \
  --from-literal=username=admin \
  --from-literal=password=s3cr3t

# Verify secret is mounted as file
kubectl exec <pod> -- ls -la /etc/secrets/
kubectl exec <pod> -- cat /etc/secrets/username

# Check file permissions
kubectl exec <pod> -- stat /etc/secrets/username
```

---

## Quick Reference

| Task | Command |
|------|---------|
| Scan image (CRITICAL only) | `trivy image --severity CRITICAL <image>` |
| Scan with exit code | `trivy image --exit-code 1 --severity CRITICAL <image>` |
| Generate AES key | `head -c 32 /dev/urandom \| base64` |
| Verify etcd encryption | `etcdctl get /registry/secrets/<ns>/<name> \| hexdump -C \| head` |
| Re-encrypt all secrets | `kubectl get secrets -A -o json \| kubectl replace -f -` |
| List RuntimeClasses | `kubectl get runtimeclass` |
| Check pod runtime | `kubectl get pod <name> -o jsonpath='{.spec.runtimeClassName}'` |
| Create secret | `kubectl create secret generic <name> --from-literal=key=val` |
| Check secret mount | `kubectl exec <pod> -- ls -la /etc/secrets/` |

---

## Cilium CLI

### Kiểm tra trạng thái Cilium

```bash
# Xem tổng quan trạng thái Cilium
cilium status

# Xem chi tiết
cilium status --verbose

# Kiểm tra connectivity giữa các pod
cilium connectivity test
```

### Kiểm tra encryption

```bash
# Xem trạng thái encryption
cilium encrypt status

# Xem WireGuard keys
cilium encrypt status --verbose
```

### Kiểm tra Cilium pods

```bash
# Xem Cilium DaemonSet pods
kubectl get pods -n kube-system -l k8s-app=cilium

# Xem logs Cilium
kubectl logs -n kube-system -l k8s-app=cilium --tail=50

# Exec vào Cilium pod để chạy cilium CLI
kubectl exec -n kube-system -it <cilium-pod> -- cilium status
```

### Bật WireGuard encryption

```bash
# Dùng Helm
helm upgrade cilium cilium/cilium \
  --namespace kube-system \
  --reuse-values \
  --set encryption.enabled=true \
  --set encryption.type=wireguard

# Hoặc patch ConfigMap
kubectl patch configmap cilium-config -n kube-system \
  --type merge \
  -p '{"data":{"enable-wireguard":"true"}}'

kubectl rollout restart daemonset/cilium -n kube-system
```

### CiliumNetworkPolicy

```yaml
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: allow-client-to-server
  namespace: <namespace>
spec:
  endpointSelector:
    matchLabels:
      app: server
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: client
    toPorts:
    - ports:
      - port: "80"
        protocol: TCP
```

### Quick Reference – Cilium CLI

| Task | Command |
|------|---------|
| Check Cilium status | `cilium status` |
| Check encryption | `cilium encrypt status` |
| Test connectivity | `cilium connectivity test` |
| List Cilium pods | `kubectl get pods -n kube-system -l k8s-app=cilium` |
| Enable WireGuard | `helm upgrade cilium ... --set encryption.enabled=true --set encryption.type=wireguard` |
| Restart Cilium | `kubectl rollout restart daemonset/cilium -n kube-system` |
