# Đáp án Mock Exam 2

## Tổng điểm: 100 | Điểm đạt: 67

---

## Q1 – Fix NetworkPolicy (8 điểm)

```bash
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: broken-policy
  namespace: fix-backend
spec:
  podSelector: {}
  policyTypes:
  - Ingress
EOF
# Không có ingress rules = chặn tất cả ingress
```

---

## Q2 – Fix PSS Label (7 điểm)

```bash
kubectl label namespace fix-pss \
  pod-security.kubernetes.io/enforce=restricted \
  --overwrite
```

---

## Q3 – Fix RBAC Wildcard (8 điểm)

```bash
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: broken-role
  namespace: fix-rbac
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
EOF
```

---

## Q4 – Fix Audit Policy (7 điểm)

```bash
cat > /tmp/fixed-audit-policy.yaml <<'EOF'
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: RequestResponse
  resources:
  - group: ""
    resources: ["secrets"]
- level: Metadata
  omitStages:
  - RequestReceived
EOF
```

---

## Q5 – Fix AppArmor Annotation (5 điểm)

```bash
kubectl delete pod broken-apparmor -n fix-system

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: broken-apparmor
  namespace: fix-system
  annotations:
    container.apparmor.security.beta.kubernetes.io/app: runtime/default
spec:
  containers:
  - name: app
    image: nginx:1.25-alpine
EOF
```

---

## Q6 – Fix SecurityContext (5 điểm)

```bash
kubectl delete pod insecure-pod -n fix-system

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: insecure-pod
  namespace: fix-system
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
  containers:
  - name: app
    image: nginx:1.25-alpine
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      capabilities:
        drop: [ALL]
EOF
```

---

## Q7 – Fix Image Version (6 điểm)

```bash
kubectl set image deployment/web-deploy web=nginx:1.25-alpine -n fix-micro
```

---

## Q8 – Fix Secret Mount (7 điểm)

```bash
kubectl delete pod bad-secret-pod -n fix-micro

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: bad-secret-pod
  namespace: fix-micro
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    volumeMounts:
    - name: secret-vol
      mountPath: /etc/app-secret
      readOnly: true
  volumes:
  - name: secret-vol
    secret:
      secretName: app-secret
      defaultMode: 0400
EOF
```

---

## Q9 – Fix EncryptionConfiguration (7 điểm)

```bash
cat > /tmp/fixed-encryption.yaml <<'EOF'
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
- resources:
  - secrets
  providers:
  - aescbc:
      keys:
      - name: key1
        secret: c2VjcmV0a2V5MTIzNDU2Nzg5MDEyMzQ1Ng==
  - identity: {}
EOF
# aescbc phải là provider ĐẦU TIÊN để mã hóa khi ghi
```

---

## Q10 – Verify cosign Signature (7 điểm)

```bash
mkdir -p /tmp/fix-cosign
cd /tmp/fix-cosign
COSIGN_PASSWORD="" cosign generate-key-pair
COSIGN_PASSWORD="" cosign sign --key cosign.key nginx:1.25-alpine
COSIGN_PASSWORD="" cosign verify --key cosign.pub nginx:1.25-alpine \
  > /tmp/fix-cosign/verify-output.txt 2>&1
```

---

## Q11 – Fix Insecure Dockerfile (6 điểm)

```dockerfile
# /tmp/fixed-dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:20-alpine
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY . .
USER appuser
EXPOSE 3000
CMD ["node", "server.js"]
```

```bash
cat > /tmp/fixed-dockerfile <<'EOF'
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:20-alpine
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY . .
USER appuser
EXPOSE 3000
CMD ["node", "server.js"]
EOF
```

---

## Q12 – Fix Gatekeeper Constraint (7 điểm)

```bash
kubectl apply -f - <<EOF
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sFixAllowedRepos
metadata:
  name: fix-allowed-repos
spec:
  match:
    kinds:
    - apiGroups: [""]
      kinds: ["Pod"]
    namespaces:
    - fix-policy
  parameters:
    repos:
    - "registry.k8s.io"
    - "docker.io/library"
EOF
```

---

## Q13 – Fix Falco Rule (7 điểm)

```bash
cat > /tmp/fixed-falco-rule.yaml <<'EOF'
- rule: Detect shell in container
  desc: A shell was spawned in a container
  condition: spawned_process and container and shell_procs
  output: >
    Shell spawned in container
    (user=%user.name pod=%k8s.pod.name ns=%k8s.ns.name
     shell=%proc.name cmdline=%proc.cmdline)
  priority: WARNING
  tags: [container, shell]
EOF
```

---

## Q14 – Audit Log Forensics (6 điểm)

```bash
# Q14a: SA tạo pod
jq -r 'select(.objectRef.resource=="pods" and .verb=="create") | .user.username' /tmp/fix-audit.log
# Đáp án: system:serviceaccount:fix-audit:deploy-sa

# Q14b: Lần đầu đọc fix-secret
jq -r 'select(.objectRef.resource=="secrets" and .objectRef.name=="fix-secret") | .requestReceivedTimestamp' /tmp/fix-audit.log | head -1
# Đáp án: 2024-10-15T08:30:00Z

# Q14c: Số lần exec
jq 'select(.objectRef.subresource=="exec")' /tmp/fix-audit.log | wc -l
# Đáp án: 2

cat > /tmp/fix-audit-answers.txt <<EOF
Q14a: system:serviceaccount:fix-audit:deploy-sa
Q14b: 2024-10-15T08:30:00Z
Q14c: 2 lần exec (alice vào web-pod, bob vào db-pod)
EOF
```

---

## Q15 – Fix Mutable Container (7 điểm)

```bash
kubectl delete pod mutable-pod -n fix-runtime

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: mutable-pod
  namespace: fix-runtime
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 101
  containers:
  - name: app
    image: nginx:1.25-alpine
    securityContext:
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
      capabilities:
        drop: [ALL]
    volumeMounts:
    - name: tmp
      mountPath: /tmp
    - name: cache
      mountPath: /var/cache/nginx
  volumes:
  - name: tmp
    emptyDir: {}
  - name: cache
    emptyDir: {}
EOF
```

---

## Bảng điểm

| Domain | Câu | Điểm tối đa | Điểm của bạn |
|--------|-----|-------------|--------------|
| Cluster Setup | Q1, Q2 | 15 | ___ |
| Cluster Hardening | Q3, Q4 | 15 | ___ |
| System Hardening | Q5, Q6 | 10 | ___ |
| Microservice Vulnerabilities | Q7, Q8, Q9 | 20 | ___ |
| Supply Chain Security | Q10, Q11, Q12 | 20 | ___ |
| Monitoring/Runtime | Q13, Q14, Q15 | 20 | ___ |
| **Tổng** | | **100** | **___** |
