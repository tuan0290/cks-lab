# Lab 6.7: Advanced NetworkPolicy - Multi-Tier Application Isolation

## Metadata

- **Domain**: 6 - Monitoring, Logging & Runtime Security
- **Difficulty**: Hard
- **Estimated Time**: 30 minutes
- **Exam Weight**: 20%

## Learning Objectives

- Design and implement complex multi-tier NetworkPolicy configurations
- Implement default-deny policies with selective allow rules
- Configure namespace-level network isolation
- Apply egress restrictions to prevent data exfiltration
- Combine ingress and egress policies for comprehensive network segmentation
- Verify network connectivity using kubectl exec and network tools

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- CNI plugin that supports NetworkPolicy (Calico, Cilium, or Weave)
- Basic understanding of Kubernetes NetworkPolicy

## Scenario

You are securing a three-tier web application consisting of:
- **Frontend** tier: Nginx web servers (accepts external traffic on port 80)
- **Backend** tier: API servers (only accessible from frontend on port 8080)
- **Database** tier: PostgreSQL (only accessible from backend on port 5432)

You must implement NetworkPolicies to enforce strict network segmentation:
1. Default deny all ingress and egress in the application namespace
2. Allow frontend to receive traffic from outside on port 80
3. Allow frontend to communicate with backend on port 8080 only
4. Allow backend to communicate with database on port 5432 only
5. Allow DNS resolution (UDP/TCP port 53) for all tiers
6. Block all other communication paths

## Requirements

1. Create a default-deny-all NetworkPolicy that blocks all ingress and egress traffic
2. Create a NetworkPolicy allowing frontend pods to receive traffic on port 80
3. Create a NetworkPolicy allowing frontend to reach backend on port 8080
4. Create a NetworkPolicy allowing backend to reach database on port 5432
5. Create a NetworkPolicy allowing DNS resolution for all pods
6. Verify that unauthorized traffic paths are blocked

## Questions

> **Exam-style tasks** — Complete all tasks below before running `./verify.sh`

1. **Task**: Create namespace `lab-6-7` and deploy 3 pods:
   - `frontend` with label `tier=frontend` and `app=web`
   - `backend` with label `tier=backend` and `app=api`
   - `database` with label `tier=database` and `app=db`

2. **Task**: Create a NetworkPolicy named `default-deny-all` in namespace `lab-6-7` that denies **all** ingress and egress for all pods (`podSelector: {}`, `policyTypes: [Ingress, Egress]`).

3. **Task**: Create a NetworkPolicy named `allow-frontend-ingress` in namespace `lab-6-7` that allows ingress to `tier=frontend` pods on TCP port 80 from any source.

4. **Task**: Create a NetworkPolicy named `allow-frontend-to-backend` in namespace `lab-6-7` that allows:
   - Egress from `tier=frontend` to `tier=backend` on TCP port 8080
   - Ingress to `tier=backend` from `tier=frontend` on TCP port 8080

5. **Task**: Create a NetworkPolicy named `allow-backend-to-database` in namespace `lab-6-7` that allows:
   - Egress from `tier=backend` to `tier=database` on TCP port 5432
   - Ingress to `tier=database` from `tier=backend` on TCP port 5432

6. **Task**: Create a NetworkPolicy named `allow-dns` in namespace `lab-6-7` that allows egress to `kube-system` namespace on UDP/TCP port 53 for all pods.

7. **Verify**: Run `./verify.sh` — all checks must pass.

## Instructions

### Step 1: Set up the lab environment

```bash
./setup.sh
```

This creates the `lab-6-7` namespace with frontend, backend, and database pods.

### Step 2: Verify initial connectivity (before policies)

```bash
# Get pod names
FRONTEND=$(kubectl get pod -n lab-6-7 -l tier=frontend -o jsonpath='{.items[0].metadata.name}')
BACKEND=$(kubectl get pod -n lab-6-7 -l tier=backend -o jsonpath='{.items[0].metadata.name}')
DB=$(kubectl get pod -n lab-6-7 -l tier=database -o jsonpath='{.items[0].metadata.name}')

# Test connectivity (should work before policies)
kubectl exec -n lab-6-7 $FRONTEND -- wget -qO- --timeout=3 http://backend-svc:8080/health 2>/dev/null && echo "CONNECTED" || echo "FAILED"
```

### Step 3: Apply default-deny-all policy

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: lab-6-7
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF
```

### Step 4: Allow DNS resolution for all pods

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: lab-6-7
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

### Step 5: Allow external traffic to frontend on port 80

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-ingress
  namespace: lab-6-7
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

### Step 6: Allow frontend to backend communication

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: lab-6-7
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
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-egress-backend
  namespace: lab-6-7
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

### Step 7: Allow backend to database communication

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-to-database
  namespace: lab-6-7
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
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-egress-database
  namespace: lab-6-7
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

### Step 8: Verify the policies

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

- [Kubernetes NetworkPolicy Documentation](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [NetworkPolicy Editor](https://editor.networkpolicy.io/)
- [CKS Exam Curriculum](https://github.com/cncf/curriculum)
