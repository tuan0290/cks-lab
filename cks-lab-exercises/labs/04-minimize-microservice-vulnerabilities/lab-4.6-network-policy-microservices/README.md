# Lab 4.6: NetworkPolicy for Microservices

## Metadata

- **Domain**: 4 - Minimize Microservice Vulnerabilities
- **Difficulty**: Medium
- **Estimated Time**: 20 minutes
- **Exam Weight**: 20%

## Learning Objectives

- Implement default-deny NetworkPolicy for a microservices namespace
- Allow only required inter-service communication
- Isolate frontend, backend, and database tiers

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- CNI plugin supporting NetworkPolicy

## Scenario

You have a 3-tier application (frontend, backend, database) and need to implement network segmentation so each tier can only communicate with the tier it needs.

## Requirements

1. Create namespace `lab-4-6`
2. Deploy pods: `frontend` (label: tier=frontend), `backend` (label: tier=backend), `database` (label: tier=database)
3. Create NetworkPolicy `default-deny` that denies all ingress and egress
4. Create NetworkPolicy `allow-frontend-to-backend` allowing frontend → backend on port 8080
5. Create NetworkPolicy `allow-backend-to-database` allowing backend → database on port 5432

## Questions

> **Exam-style tasks** — Complete all tasks below before running `./verify.sh`

1. **Task**: Create namespace `lab-4-6`.

2. **Task**: Create three Pods in namespace `lab-4-6`:
   - `frontend` with label `tier=frontend`
   - `backend` with label `tier=backend`
   - `database` with label `tier=database`

3. **Task**: Create a NetworkPolicy named `default-deny` in namespace `lab-4-6` that denies **all** ingress and egress for all pods (`podSelector: {}`, `policyTypes: [Ingress, Egress]`).

4. **Task**: Create a NetworkPolicy named `allow-frontend-to-backend` in namespace `lab-4-6` that allows ingress to pods with `tier=backend` **only** from pods with `tier=frontend` on TCP port `8080`.

5. **Task**: Create a NetworkPolicy named `allow-backend-to-database` in namespace `lab-4-6` that allows ingress to pods with `tier=database` **only** from pods with `tier=backend` on TCP port `5432`.

6. **Task**: Verify the policies are in place:
   ```bash
   kubectl get networkpolicies -n lab-4-6
   # Should show: default-deny, allow-frontend-to-backend, allow-backend-to-database
   ```

7. **Verify**: Run `./verify.sh` — all checks must pass.

## Instructions

```bash
for tier in frontend backend database; do
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: $tier
  namespace: lab-4-6
  labels:
    tier: $tier
spec:
  containers:
  - name: app
    image: nginx:1.25
    resources:
      limits:
        cpu: "100m"
        memory: "64Mi"
EOF
done
```

### Step 3: Create default-deny NetworkPolicy

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: lab-4-6
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF
```

### Step 4: Allow frontend → backend

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: lab-4-6
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
    - protocol: TCP
      port: 8080
EOF
```

### Step 5: Allow backend → database

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-to-database
  namespace: lab-4-6
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
    - protocol: TCP
      port: 5432
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

- **Default-deny**: Empty `podSelector: {}` applies to all pods; no ingress/egress rules = deny all
- **Tier isolation**: Each tier only accepts traffic from the tier that needs it
- **policyTypes**: Must list both Ingress and Egress for full default-deny

## Additional Resources

- [NetworkPolicy](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [NetworkPolicy Recipes](https://github.com/ahmetb/kubernetes-network-policy-recipes)
