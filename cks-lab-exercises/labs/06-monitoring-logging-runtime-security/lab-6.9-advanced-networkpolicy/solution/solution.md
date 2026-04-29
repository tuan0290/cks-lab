# Solution: Lab 6.9 - Advanced NetworkPolicy - Multi-Tier Application Isolation

## Overview

This solution implements a complete multi-tier network segmentation using Kubernetes NetworkPolicies.

## Architecture

```
Internet → [Frontend:80] → [Backend:8080] → [Database:5432]
              ↑                  ↑                 ↑
         allow-frontend-    allow-frontend-   allow-backend-
           ingress          to-backend        to-database
```

## Step-by-Step Solution

### Step 1: Apply default-deny-all policy

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: lab-6-9
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF
```

### Step 2: Allow DNS resolution

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: lab-6-9
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - ports:
    - port: 53
      protocol: UDP
    - port: 53
      protocol: TCP
EOF
```

### Step 3: Allow external traffic to frontend

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-ingress
  namespace: lab-6-9
spec:
  podSelector:
    matchLabels:
      tier: frontend
  policyTypes:
  - Ingress
  ingress:
  - ports:
    - port: 80
      protocol: TCP
EOF
```

### Step 4: Allow frontend → backend communication

```bash
kubectl apply -f - <<'EOF'
# Backend ingress from frontend
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: lab-6-9
spec:
  podSelector:
    matchLabels:
      tier: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: frontend
    ports:
    - port: 8080
      protocol: TCP
---
# Frontend egress to backend
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-egress-backend
  namespace: lab-6-9
spec:
  podSelector:
    matchLabels:
      tier: frontend
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          tier: backend
    ports:
    - port: 8080
      protocol: TCP
EOF
```

### Step 5: Allow backend → database communication

```bash
kubectl apply -f - <<'EOF'
# Database ingress from backend
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-to-database
  namespace: lab-6-9
spec:
  podSelector:
    matchLabels:
      tier: database
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: backend
    ports:
    - port: 5432
      protocol: TCP
---
# Backend egress to database
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-egress-database
  namespace: lab-6-9
spec:
  podSelector:
    matchLabels:
      tier: backend
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          tier: database
    ports:
    - port: 5432
      protocol: TCP
EOF
```

### Step 6: Verify all policies

```bash
kubectl get networkpolicy -n lab-6-9
```

Expected output:
```
NAME                           POD-SELECTOR    AGE
allow-backend-egress-database  tier=backend    1m
allow-backend-to-database      tier=database   1m
allow-dns                      <none>          2m
allow-frontend-egress-backend  tier=frontend   1m
allow-frontend-ingress         tier=frontend   2m
allow-frontend-to-backend      tier=backend    1m
default-deny-all               <none>          3m
```

## Key Concepts

### NetworkPolicy Selectors

| Selector | Purpose |
|----------|---------|
| `podSelector: {}` | Selects ALL pods in namespace |
| `podSelector: {matchLabels: {tier: frontend}}` | Selects only frontend pods |
| `namespaceSelector` | Selects pods from specific namespaces |

### Policy Types

- **Ingress**: Controls incoming traffic TO the selected pods
- **Egress**: Controls outgoing traffic FROM the selected pods
- Both must be specified for complete isolation

### Common Pitfalls

1. **Forgetting DNS**: Always add a DNS allow policy when using default-deny
2. **One-way policies**: Both ingress (on destination) AND egress (on source) needed
3. **Empty podSelector**: `podSelector: {}` means ALL pods, not no pods
4. **Missing policyTypes**: Explicitly list Ingress and/or Egress

## CKS Exam Tips

- Default-deny is always the first policy to apply
- DNS (port 53) must be explicitly allowed
- NetworkPolicy requires a CNI that supports it (Calico, Cilium, Weave)
- Use `kubectl describe networkpolicy` to verify policy details
- Test connectivity with `kubectl exec -- wget/curl/nc`
