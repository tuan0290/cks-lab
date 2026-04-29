# Solution: Lab 6.11 - Kubernetes Incident Response Procedures

## Overview

This solution demonstrates a complete incident response process for a Kubernetes security event.

## Incident Response Framework (PICERL)

1. **Prepare**: Have tools and procedures ready
2. **Identify**: Detect and confirm the incident
3. **Contain**: Limit the damage
4. **Eradicate**: Remove the threat
5. **Recover**: Restore normal operations
6. **Lessons Learned**: Improve defenses

## Step-by-Step Solution

### Phase 1: Identify

```bash
# List all pods and check for suspicious ones
kubectl get pods -n lab-6-11 -o wide

# Check pod details
kubectl describe pod suspicious-pod -n lab-6-11

# Check pod logs for suspicious activity
kubectl logs suspicious-pod -n lab-6-11 --tail=50

# Check RBAC permissions
SA=$(kubectl get pod suspicious-pod -n lab-6-11 -o jsonpath='{.spec.serviceAccountName}')
echo "ServiceAccount: $SA"
kubectl auth can-i --list --as=system:serviceaccount:lab-6-11:$SA -n lab-6-11

# Check for overprivileged RoleBindings
kubectl get rolebindings -n lab-6-11 -o yaml | grep -A10 "compromised"
```

### Phase 2: Contain

```bash
# Apply emergency isolation NetworkPolicy
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: emergency-isolation
  namespace: lab-6-11
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

### Phase 3: Investigate

```bash
# Collect forensic evidence
echo "=== Running Processes ===" > /tmp/incident-evidence.txt
kubectl exec -n lab-6-11 suspicious-pod -- ps aux >> /tmp/incident-evidence.txt 2>/dev/null || true

echo "=== Network Connections ===" >> /tmp/incident-evidence.txt
kubectl exec -n lab-6-11 suspicious-pod -- netstat -an >> /tmp/incident-evidence.txt 2>/dev/null || \
kubectl exec -n lab-6-11 suspicious-pod -- ss -an >> /tmp/incident-evidence.txt 2>/dev/null || true

echo "=== Environment Variables ===" >> /tmp/incident-evidence.txt
kubectl exec -n lab-6-11 suspicious-pod -- env >> /tmp/incident-evidence.txt 2>/dev/null || true

echo "=== Files in /tmp ===" >> /tmp/incident-evidence.txt
kubectl exec -n lab-6-11 suspicious-pod -- ls -la /tmp/ >> /tmp/incident-evidence.txt 2>/dev/null || true

cat /tmp/incident-evidence.txt
```

### Phase 4: Eradicate

```bash
# Revoke ServiceAccount credentials
SA=$(kubectl get pod suspicious-pod -n lab-6-11 -o jsonpath='{.spec.serviceAccountName}')

# Delete associated secrets (forces token rotation)
kubectl get secrets -n lab-6-11 -o json | \
    jq -r --arg sa "$SA" '.items[] | select(.metadata.annotations["kubernetes.io/service-account.name"]==$sa) | .metadata.name' | \
    xargs -I{} kubectl delete secret {} -n lab-6-11 --ignore-not-found=true

# Delete the compromised pod
kubectl delete pod suspicious-pod -n lab-6-11

# Remove overprivileged RBAC (if appropriate)
# kubectl delete rolebinding compromised-binding -n lab-6-11
# kubectl delete role overprivileged-role -n lab-6-11

echo "Threat eradicated"
```

### Phase 5: Recover

```bash
# Remove emergency isolation (after threat is gone)
kubectl delete networkpolicy emergency-isolation -n lab-6-11 --ignore-not-found=true

# Deploy clean replacement with hardened security
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: clean-replacement
  namespace: lab-6-11
  labels:
    app: webapp
    status: clean
spec:
  serviceAccountName: default
  automountServiceAccountToken: false
  containers:
  - name: app
    image: nginx:1.25
    securityContext:
      readOnlyRootFilesystem: true
      runAsNonRoot: true
      runAsUser: 101
      allowPrivilegeEscalation: false
      capabilities:
        drop:
        - ALL
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
```

### Phase 6: Post-Incident Detection Rule

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

    - rule: ServiceAccount Token Read
      desc: Detect reading of ServiceAccount token from container
      condition: >
        open_read and container and
        fd.name startswith /var/run/secrets/kubernetes.io/serviceaccount/token
      output: >
        ServiceAccount token read (user=%user.name proc=%proc.name
        container=%container.name image=%container.image.repository
        pod=%k8s.pod.name)
      priority: WARNING
      tags: [kubernetes, serviceaccount, incident, cks]
EOF
```

## Incident Timeline Template

```
INCIDENT TIMELINE
=================
Time: [timestamp]
Alert: [what triggered the alert]

Detection:
- [timestamp]: Alert received from [source]
- [timestamp]: Identified pod [name] in namespace [ns]

Containment:
- [timestamp]: Applied NetworkPolicy emergency-isolation
- [timestamp]: Pod isolated, no network access

Investigation:
- [timestamp]: Collected forensic evidence
- [timestamp]: Identified compromised ServiceAccount: [name]
- [timestamp]: Found overprivileged RBAC: [binding name]

Eradication:
- [timestamp]: Revoked ServiceAccount tokens
- [timestamp]: Deleted compromised pod
- [timestamp]: Removed overprivileged RBAC

Recovery:
- [timestamp]: Deployed clean replacement pod
- [timestamp]: Verified normal operation

Lessons Learned:
- [what went wrong]
- [how to prevent recurrence]
- [new detection rules added]
```

## CKS Exam Tips

- Know the incident response phases: Identify → Contain → Investigate → Eradicate → Recover
- NetworkPolicy is the primary containment tool in Kubernetes
- Always collect forensic evidence BEFORE deleting the compromised pod
- `kubectl auth can-i --list --as=system:serviceaccount:ns:sa` checks SA permissions
- `automountServiceAccountToken: false` prevents unnecessary API access
- Know how to revoke ServiceAccount tokens by deleting associated secrets
