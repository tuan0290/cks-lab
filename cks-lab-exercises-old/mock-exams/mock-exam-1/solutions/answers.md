# Đáp án Mock Exam 1

## Tổng điểm: 100 | Điểm đạt: 67

---

## Q1 – NetworkPolicy (8 điểm)

```bash
# Deny all ingress + egress trong exam-backend
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: exam-backend
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF

# Allow ingress từ exam-frontend trên port 8080
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend
  namespace: exam-backend
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: exam-frontend
    ports:
    - protocol: TCP
      port: 8080
EOF
```

---

## Q2 – Pod Security Standards (7 điểm)

```bash
kubectl label namespace exam-restricted \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=latest
```

---

## Q3 – RBAC Least Privilege (8 điểm)

```bash
kubectl delete clusterrolebinding exam-sa-admin

kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader
  namespace: exam-rbac
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list"]
EOF

kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: exam-sa-secret-reader
  namespace: exam-rbac
subjects:
- kind: ServiceAccount
  name: exam-sa
  namespace: exam-rbac
roleRef:
  kind: Role
  name: secret-reader
  apiGroup: rbac.authorization.k8s.io
EOF
```

---

## Q4 – ServiceAccount Token (7 điểm)

```bash
kubectl patch serviceaccount no-token-sa -n exam-rbac \
  -p '{"automountServiceAccountToken": false}'

kubectl delete pod no-token-pod -n exam-rbac

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: no-token-pod
  namespace: exam-rbac
spec:
  serviceAccountName: no-token-sa
  automountServiceAccountToken: false
  containers:
  - name: app
    image: nginx:1.25-alpine
EOF
```

---

## Q5 – AppArmor (5 điểm)

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: apparmor-pod
  namespace: exam-system
  annotations:
    container.apparmor.security.beta.kubernetes.io/main: localhost/exam-deny-write
spec:
  containers:
  - name: main
    image: nginx:1.25-alpine
EOF
```

---

## Q6 – Seccomp + SecurityContext (5 điểm)

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: hardened-pod
  namespace: exam-system
spec:
  securityContext:
    seccompProfile:
      type: RuntimeDefault
    runAsNonRoot: true
    runAsUser: 1000
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop: [ALL]
    volumeMounts:
    - name: tmp
      mountPath: /tmp
  volumes:
  - name: tmp
    emptyDir: {}
EOF
```

---

## Q7 – Trivy Image Scan (6 điểm)

```bash
trivy image --severity CRITICAL nginx:1.14.0 2>/dev/null | \
  grep "Total:" | tee /tmp/trivy-result.txt

kubectl delete pod vulnerable-app -n exam-micro
kubectl run vulnerable-app --image=nginx:1.25-alpine \
  --namespace=exam-micro --restart=Never
```

---

## Q8 – Secret Volume Mount (7 điểm)

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: secure-mount
  namespace: exam-micro
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    volumeMounts:
    - name: creds
      mountPath: /etc/credentials
      readOnly: true
  volumes:
  - name: creds
    secret:
      secretName: exam-credentials
      defaultMode: 0400
EOF
```

---

## Q9 – RuntimeClass (7 điểm)

```bash
kubectl apply -f - <<EOF
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: exam-sandbox
handler: runsc
EOF

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: sandboxed-app
  namespace: exam-micro
spec:
  runtimeClassName: exam-sandbox
  containers:
  - name: app
    image: nginx:1.25-alpine
EOF
```

---

## Q10 – cosign Image Signing (7 điểm)

```bash
mkdir -p /tmp/exam-cosign
cd /tmp/exam-cosign
COSIGN_PASSWORD="" cosign generate-key-pair
COSIGN_PASSWORD="" cosign sign --key cosign.key nginx:1.25-alpine
echo "cosign verify --key /tmp/exam-cosign/cosign.pub nginx:1.25-alpine" \
  > /tmp/exam-cosign/verify-cmd.txt
```

---

## Q11 – Static Analysis (6 điểm)

```bash
# Phân tích
kubesec scan /tmp/exam-insecure.yaml
# hoặc: trivy config /tmp/exam-insecure.yaml

# Tạo manifest đã sửa
sed 's/privileged: true/privileged: false/g; s/hostPID: true/hostPID: false/g' \
  /tmp/exam-insecure.yaml > /tmp/exam-fixed.yaml
```

---

## Q12 – Image Policy (7 điểm)

```bash
kubectl apply -f - <<EOF
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8sexamallowedrepos
spec:
  crd:
    spec:
      names:
        kind: K8sExamAllowedRepos
      validation:
        openAPIV3Schema:
          type: object
          properties:
            repos:
              type: array
              items:
                type: string
  targets:
  - target: admission.k8s.gatekeeper.sh
    rego: |
      package k8sexamallowedrepos
      violation[{"msg": msg}] {
        container := input.review.object.spec.containers[_]
        satisfied := [good | repo = input.parameters.repos[_]; good = startswith(container.image, repo)]
        not any(satisfied)
        msg := sprintf("Image not from allowed repo: %v", [container.image])
      }
EOF

kubectl apply -f - <<EOF
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sExamAllowedRepos
metadata:
  name: exam-allowed-repos
spec:
  match:
    kinds:
    - apiGroups: [""]
      kinds: ["Pod"]
    namespaces:
    - exam-policy
  parameters:
    repos:
    - "registry.k8s.io"
    - "docker.io/library"
EOF
```

---

## Q13 – Falco Rules (7 điểm)

```bash
sudo mkdir -p /etc/falco/rules.d
sudo tee /etc/falco/rules.d/exam-rules.yaml <<'EOF'
- rule: Detect curl or wget in container
  desc: Detect network tools curl or wget running inside a container
  condition: >
    spawned_process
    and container
    and proc.name in (curl, wget)
  output: >
    Network tool detected in container
    (user=%user.name pod=%k8s.pod.name ns=%k8s.ns.name
     tool=%proc.name cmdline=%proc.cmdline)
  priority: WARNING
  tags: [network, container]
EOF
```

---

## Q14 – Audit Log Analysis (6 điểm)

```bash
# Q14a: User xóa exam-secret
jq -r 'select(.objectRef.resource=="secrets" and .verb=="delete" and .objectRef.name=="exam-secret") | .user.username' /tmp/exam-audit.log
# Đáp án: alice

# Q14b: Số request 403
jq 'select(.responseStatus.code==403)' /tmp/exam-audit.log | wc -l
# Đáp án: 2

# Q14c: User exec vào pod
jq -r 'select(.objectRef.subresource=="exec") | .user.username' /tmp/exam-audit.log
# Đáp án: alice

cat > /tmp/exam-audit-answers.txt <<EOF
Q14a: alice
Q14b: 2
Q14c: alice (exec vào pod web-pod)
EOF
```

---

## Q15 – Immutable Container (7 điểm)

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: immutable-exam
  namespace: exam-runtime
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
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
    - name: run
      mountPath: /var/run
  volumes:
  - name: tmp
    emptyDir: {}
  - name: run
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
