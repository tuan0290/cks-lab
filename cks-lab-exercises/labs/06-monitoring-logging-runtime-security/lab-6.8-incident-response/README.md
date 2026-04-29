# Lab 6.8: Kubernetes Incident Response Procedures

## Metadata

- **Domain**: 6 - Monitoring, Logging & Runtime Security
- **Difficulty**: Hard
- **Estimated Time**: 35 minutes
- **Exam Weight**: 20%

## Learning Objectives

- Execute a structured incident response process for Kubernetes security events
- Identify and contain compromised workloads using NetworkPolicy
- Collect forensic evidence from running containers
- Analyze RBAC permissions to identify privilege escalation paths
- Revoke compromised credentials and service account tokens
- Restore cluster to a known-good state after an incident

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- jq installed for log analysis
- Basic understanding of Kubernetes RBAC and NetworkPolicy

## Scenario

A security alert has been triggered: a pod in the `production` namespace is exhibiting suspicious behavior. The pod appears to be running reconnaissance commands and attempting to access the Kubernetes API server. You must:

1. **Detect**: Identify the compromised pod and its behavior
2. **Contain**: Isolate the pod using NetworkPolicy
3. **Investigate**: Collect forensic evidence
4. **Eradicate**: Remove the threat and revoke compromised credentials
5. **Recover**: Restore normal operations
6. **Document**: Record the incident timeline

## Requirements

1. Identify the compromised pod using kubectl and audit logs
2. Apply a NetworkPolicy to isolate the compromised pod (block all ingress/egress)
3. Collect forensic evidence: running processes, network connections, environment variables
4. Identify and revoke the compromised ServiceAccount token
5. Delete the compromised pod and recreate it from a clean image
6. Verify the cluster is back to normal operation
7. Create a post-incident Falco rule to detect similar future attacks

## Questions

> **Exam-style tasks** — Complete all tasks below before running `./verify.sh`

1. **Task**: Create namespace `lab-6-8` and run setup:
   ```bash
   ./setup.sh
   ```

2. **Task**: Identify the suspicious pod:
   ```bash
   kubectl get pods -n lab-6-8 --show-labels
   kubectl describe pod <suspicious-pod> -n lab-6-8
   ```

3. **Task**: Isolate the compromised pod by creating a NetworkPolicy named `quarantine-policy` in namespace `lab-6-8` that blocks **all** ingress and egress for pods with label `quarantine=true`. Then label the suspicious pod:
   ```bash
   kubectl label pod <suspicious-pod> -n lab-6-8 quarantine=true
   ```

4. **Task**: Collect forensic evidence:
   ```bash
   # Capture running processes
   kubectl exec <suspicious-pod> -n lab-6-8 -- ps aux > /tmp/forensics-processes.txt
   # Capture environment variables (may contain stolen credentials)
   kubectl exec <suspicious-pod> -n lab-6-8 -- env > /tmp/forensics-env.txt
   ```

5. **Task**: Create a ConfigMap named `incident-report` in namespace `lab-6-8` documenting:
   - Incident timeline
   - Affected resources
   - Evidence collected
   - Containment actions taken
   - Recovery steps

6. **Task**: Create a Falco rule ConfigMap named `post-incident-rules` in namespace `lab-6-8` to detect similar future attacks.

7. **Verify**: Run `./verify.sh` — all checks must pass.

## Instructions

### Step 1: Set up the lab environment

```bash
./setup.sh
```

This creates a simulated compromised environment with a suspicious pod.

### Step 2: Detect - Identify the compromised pod

```bash
# List all pods and look for suspicious ones
kubectl get pods -n lab-6-8 -o wide

# Check pod details for suspicious configurations
kubectl describe pod suspicious-pod -n lab-6-8

# Check what the pod is doing
kubectl logs suspicious-pod -n lab-6-8 --tail=20

# Check if the pod has unusual RBAC permissions
kubectl get rolebindings,clusterrolebindings -n lab-6-8 -o yaml | grep -A5 "suspicious"
```

### Step 3: Contain - Isolate the compromised pod

```bash
# Apply emergency isolation NetworkPolicy
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: emergency-isolation
  namespace: lab-6-8
spec:
  podSelector:
    matchLabels:
      status: compromised
  policyTypes:
  - Ingress
  - Egress
EOF

echo "Pod isolated - all network traffic blocked"
```

### Step 4: Investigate - Collect forensic evidence

```bash
# Capture running processes
echo "=== Running Processes ===" > /tmp/incident-evidence.txt
kubectl exec -n lab-6-8 suspicious-pod -- ps aux >> /tmp/incident-evidence.txt 2>/dev/null || true

# Capture network connections
echo "=== Network Connections ===" >> /tmp/incident-evidence.txt
kubectl exec -n lab-6-8 suspicious-pod -- netstat -an >> /tmp/incident-evidence.txt 2>/dev/null || \
kubectl exec -n lab-6-8 suspicious-pod -- ss -an >> /tmp/incident-evidence.txt 2>/dev/null || true

# Capture environment variables (may contain secrets)
echo "=== Environment Variables ===" >> /tmp/incident-evidence.txt
kubectl exec -n lab-6-8 suspicious-pod -- env >> /tmp/incident-evidence.txt 2>/dev/null || true

# Capture mounted files
echo "=== Mounted Volumes ===" >> /tmp/incident-evidence.txt
kubectl exec -n lab-6-8 suspicious-pod -- mount >> /tmp/incident-evidence.txt 2>/dev/null || true

echo "Evidence collected in /tmp/incident-evidence.txt"
cat /tmp/incident-evidence.txt
```

### Step 5: Investigate - Check RBAC and ServiceAccount

```bash
# Find the ServiceAccount used by the pod
SA=$(kubectl get pod suspicious-pod -n lab-6-8 -o jsonpath='{.spec.serviceAccountName}')
echo "ServiceAccount: $SA"

# Check what permissions this SA has
kubectl auth can-i --list --as=system:serviceaccount:lab-6-8:$SA -n lab-6-8

# Check for ClusterRoleBindings
kubectl get clusterrolebindings -o json | \
    jq --arg sa "$SA" --arg ns "lab-6-8" \
    '.items[] | select(.subjects[]? | select(.kind=="ServiceAccount" and .name==$sa and .namespace==$ns)) | .metadata.name'
```

### Step 6: Eradicate - Revoke credentials and remove threat

```bash
# Delete the compromised ServiceAccount token (forces token rotation)
SA=$(kubectl get pod suspicious-pod -n lab-6-8 -o jsonpath='{.spec.serviceAccountName}')

# Delete all secrets associated with the ServiceAccount
kubectl get secrets -n lab-6-8 -o json | \
    jq -r --arg sa "$SA" '.items[] | select(.metadata.annotations["kubernetes.io/service-account.name"]==$sa) | .metadata.name' | \
    xargs -I{} kubectl delete secret {} -n lab-6-8 --ignore-not-found=true

# Delete the compromised pod
kubectl delete pod suspicious-pod -n lab-6-8

echo "Compromised pod and credentials removed"
```

### Step 7: Recover - Restore normal operations

```bash
# Remove the emergency isolation policy
kubectl delete networkpolicy emergency-isolation -n lab-6-8 --ignore-not-found=true

# Deploy a clean replacement pod
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: clean-replacement
  namespace: lab-6-8
  labels:
    app: webapp
    status: clean
spec:
  serviceAccountName: default
  containers:
  - name: app
    image: nginx:1.25
    securityContext:
      readOnlyRootFilesystem: true
      runAsNonRoot: true
      runAsUser: 101
      allowPrivilegeEscalation: false
    volumeMounts:
    - name: tmp
      mountPath: /tmp
    - name: cache
      mountPath: /var/cache/nginx
    - name: run
      mountPath: /var/run
  volumes:
  - name: tmp
    emptyDir: {}
  - name: cache
    emptyDir: {}
  - name: run
    emptyDir: {}
EOF

echo "Clean replacement pod deployed"
```

### Step 8: Create post-incident detection rule

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: falco-incident-rules
  namespace: falco
data:
  incident-rules.yaml: |
    - rule: K8s API Access from Container
      desc: Detect container accessing Kubernetes API server
      condition: >
        outbound and container and
        (fd.sip = "kubernetes.default.svc.cluster.local" or
         fd.sport = 443 or fd.sport = 6443) and
        not proc.name in (kubectl, helm, kube-proxy)
      output: >
        Container accessing K8s API (user=%user.name proc=%proc.name
        connection=%fd.name container=%container.name
        image=%container.image.repository pod=%k8s.pod.name)
      priority: WARNING
      tags: [kubernetes, api, incident, cks]
EOF
```

### Step 9: Verify your solution

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

- [Kubernetes Security Incident Response](https://kubernetes.io/docs/concepts/security/)
- [NIST Incident Response Guide](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-61r2.pdf)
- [CKS Exam Curriculum](https://github.com/cncf/curriculum)
