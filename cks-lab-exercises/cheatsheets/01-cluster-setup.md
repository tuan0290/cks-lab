# Cheatsheet 01 – Cluster Setup (15%)

## NetworkPolicy

### Deny all ingress (default deny)
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: <namespace>
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```

### Deny all egress
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-egress
  namespace: <namespace>
spec:
  podSelector: {}
  policyTypes:
  - Egress
```

### Deny all ingress + egress (combined)
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: <namespace>
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

### Allow specific ingress from namespace
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-frontend
  namespace: backend
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: frontend
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
```

### Allow specific egress to namespace + DNS
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-egress-to-db
  namespace: app
spec:
  podSelector:
    matchLabels:
      app: myapp
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: database
    ports:
    - protocol: TCP
      port: 5432
  - ports:                  # Allow DNS
    - protocol: UDP
      port: 53
```

### NetworkPolicy commands
```bash
kubectl get networkpolicy -n <namespace>
kubectl describe networkpolicy <name> -n <namespace>
kubectl apply -f networkpolicy.yaml
# Test connectivity (from inside a pod)
kubectl exec -it <pod> -n <ns> -- curl <target-ip>:<port>
kubectl exec -it <pod> -n <ns> -- nc -zv <target-ip> <port>
```

---

## Pod Security Standards (PSS)

### Label namespace with PSS level
```bash
# Enforce restricted (blocks violating pods)
kubectl label namespace <ns> pod-security.kubernetes.io/enforce=restricted

# Warn + audit (non-blocking)
kubectl label namespace <ns> pod-security.kubernetes.io/warn=restricted
kubectl label namespace <ns> pod-security.kubernetes.io/audit=restricted

# Set version pin
kubectl label namespace <ns> pod-security.kubernetes.io/enforce-version=v1.29

# Remove label
kubectl label namespace <ns> pod-security.kubernetes.io/enforce-
```

### PSS levels
| Level | Description |
|-------|-------------|
| `privileged` | No restrictions |
| `baseline` | Prevents known privilege escalations |
| `restricted` | Hardened, follows security best practices |

### PSS namespace YAML
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: secure-ns
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: v1.29
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/audit: restricted
```

---

## Ingress TLS

### Generate self-signed certificate
```bash
# Generate key + cert
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=myapp.example.com/O=myapp"

# With SAN (Subject Alternative Name)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=myapp.example.com" \
  -addext "subjectAltName=DNS:myapp.example.com"
```

### Create TLS secret
```bash
kubectl create secret tls <secret-name> \
  --cert=tls.crt \
  --key=tls.key \
  -n <namespace>

# Verify
kubectl get secret <secret-name> -n <namespace> -o yaml
```

### Ingress with TLS YAML
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  namespace: <namespace>
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  tls:
  - hosts:
    - myapp.example.com
    secretName: myapp-tls
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp-svc
            port:
              number: 80
```

### Test TLS
```bash
curl -k https://myapp.example.com
curl --cacert tls.crt https://myapp.example.com
openssl s_client -connect myapp.example.com:443 -showcerts
```

---

## kube-bench (CIS Benchmark)

```bash
# Run all checks
kube-bench

# Run checks for specific component
kube-bench master          # control plane
kube-bench node            # worker node
kube-bench etcd            # etcd
kube-bench controlplane    # kube-apiserver, controller-manager, scheduler

# Run specific check by ID
kube-bench --check 1.2.1

# Output to JSON
kube-bench --json > results.json

# Run as a Kubernetes Job
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml
kubectl logs job/kube-bench
```

### Key CIS check IDs
| ID | Component | Check |
|----|-----------|-------|
| 1.1.x | API Server files | File permissions |
| 1.2.x | API Server | Flags (anonymous-auth, audit, etc.) |
| 1.3.x | Controller Manager | Flags |
| 1.4.x | Scheduler | Flags |
| 2.x | etcd | TLS, auth |
| 4.2.x | Kubelet | Config flags |

---

## Quick Reference

| Task | Command |
|------|---------|
| List NetworkPolicies | `kubectl get netpol -A` |
| Describe NetworkPolicy | `kubectl describe netpol <name> -n <ns>` |
| Get namespace labels | `kubectl get ns <name> --show-labels` |
| Label namespace PSS | `kubectl label ns <name> pod-security.kubernetes.io/enforce=restricted` |
| Create TLS secret | `kubectl create secret tls <name> --cert=tls.crt --key=tls.key` |
| List Ingress | `kubectl get ingress -A` |
| Run kube-bench | `kube-bench master` |
| Test pod connectivity | `kubectl exec -it <pod> -- nc -zv <host> <port>` |
