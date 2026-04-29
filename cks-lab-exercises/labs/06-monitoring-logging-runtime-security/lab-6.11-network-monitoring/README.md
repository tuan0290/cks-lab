# Lab 6.11: Network Traffic Monitoring and Anomaly Detection

## Metadata

- **Domain**: 6 - Monitoring, Logging & Runtime Security
- **Difficulty**: Hard
- **Estimated Time**: 30 minutes
- **Exam Weight**: 20%

## Learning Objectives

- Monitor network traffic between Kubernetes pods using Falco
- Detect network anomalies and unauthorized connections
- Implement network-level threat detection rules
- Use Cilium Hubble or similar tools for network observability
- Analyze network flow logs to identify suspicious patterns
- Create NetworkPolicies based on observed traffic patterns

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- Falco installed and running
- CNI plugin with network observability (Cilium with Hubble, or Calico)
- Basic understanding of network protocols and Kubernetes networking

## Scenario

Your security team needs to implement comprehensive network monitoring for the cluster. You must:
1. Set up Falco rules to detect suspicious network connections
2. Monitor for data exfiltration attempts
3. Detect port scanning and reconnaissance activities
4. Identify connections to known malicious IP ranges
5. Create NetworkPolicies to enforce the observed legitimate traffic patterns

## Requirements

1. Create Falco rules to detect unexpected outbound connections on non-standard ports
2. Create Falco rules to detect connections to external IP addresses
3. Create Falco rules to detect port scanning behavior
4. Implement NetworkPolicies to restrict traffic to observed legitimate patterns
5. Verify that unauthorized connections are blocked and detected
6. Generate a network traffic analysis report

## Questions

> **Exam-style tasks** — Complete all tasks below before running `./verify.sh`

1. **Task**: Create namespace `lab-6-11`.

2. **Task**: Create a ConfigMap named `falco-network-rules` in namespace `falco` with Falco rules for:

   **Rule 1 — Unexpected outbound connection**:
   ```yaml
   - rule: Unexpected Outbound Connection
     desc: Detect outbound connections on non-standard ports from containers
     condition: >
       outbound and container and
       k8s.ns.name = "lab-6-11" and
       not fd.sport in (80, 443, 53, 8080, 8443)
     output: >
       Unexpected outbound connection
       (user=%user.name cmd=%proc.cmdline connection=%fd.name pod=%k8s.pod.name)
     priority: WARNING
   ```

3. **Task**: Create a NetworkPolicy named `restrict-egress` in namespace `lab-6-11` that:
   - Allows egress to `kube-system` on port 53 (DNS)
   - Allows egress to pods within the same namespace
   - Blocks all other egress

4. **Task**: Create a Pod named `network-test` in namespace `lab-6-11` using image `alpine:3.19` with command `["sleep", "3600"]`.

5. **Task**: Test the NetworkPolicy:
   ```bash
   # Should be blocked
   kubectl exec network-test -n lab-6-11 -- wget -T 3 -q https://google.com -O /dev/null 2>&1 || echo "Blocked as expected"
   ```

6. **Task**: Create a ConfigMap named `network-analysis-report` in namespace `lab-6-11` documenting:
   - Observed legitimate traffic patterns
   - Blocked connection attempts
   - Falco alerts generated
   - NetworkPolicy rules applied

7. **Verify**: Run `./verify.sh` — all checks must pass.

## Instructions

### Step 1: Set up the lab environment

```bash
./setup.sh
```

### Step 2: Create network monitoring Falco rules

Create `falco-network-monitoring-rules.yaml`:

```yaml
# falco-network-monitoring-rules.yaml

# Rule 1: Detect connections to external IPs (non-RFC1918)
- rule: External Network Connection
  desc: Detect container connecting to external (non-private) IP addresses
  condition: >
    outbound and container and
    not fd.sip in (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 127.0.0.0/8) and
    not fd.sport in (53, 80, 443)
  output: >
    External network connection detected (user=%user.name proc=%proc.name
    connection=%fd.name container=%container.name
    image=%container.image.repository pod=%k8s.pod.name
    namespace=%k8s.ns.name)
  priority: WARNING
  tags: [network, external, cks]

# Rule 2: Detect connections on suspicious ports
- rule: Suspicious Port Connection
  desc: Detect connections on ports commonly used for C2 or data exfiltration
  condition: >
    outbound and container and
    fd.sport in (4444, 4445, 1337, 31337, 8888, 9999, 6666, 6667, 6668, 6669)
  output: >
    Suspicious port connection (user=%user.name proc=%proc.name
    port=%fd.sport connection=%fd.name container=%container.name
    image=%container.image.repository pod=%k8s.pod.name)
  priority: CRITICAL
  tags: [network, c2, suspicious, cks]

# Rule 3: Detect DNS tunneling indicators
- rule: DNS Tunneling Indicator
  desc: Detect potential DNS tunneling via unusually long DNS queries
  condition: >
    evt.type = sendmsg and
    container and
    fd.sport = 53 and
    evt.buflen > 512
  output: >
    Potential DNS tunneling (user=%user.name proc=%proc.name
    container=%container.name image=%container.image.repository
    pod=%k8s.pod.name data_size=%evt.buflen)
  priority: WARNING
  tags: [network, dns, tunneling, cks]

# Rule 4: Detect unexpected inter-namespace connections
- rule: Cross-Namespace Connection
  desc: Detect unexpected connections between different namespaces
  condition: >
    inbound and container and
    k8s.ns.name != k8s.pod.namespace and
    not k8s.ns.name in (kube-system, monitoring, falco)
  output: >
    Cross-namespace connection detected (src_ns=%k8s.ns.name
    dst_pod=%k8s.pod.name dst_ns=%k8s.pod.namespace
    container=%container.name proc=%proc.name)
  priority: WARNING
  tags: [network, namespace, cks]
```

### Step 3: Deploy the network monitoring rules

```bash
kubectl create configmap falco-network-monitoring \
  --from-file=falco-network-monitoring-rules.yaml \
  -n falco \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl rollout restart daemonset/falco -n falco
kubectl rollout status daemonset/falco -n falco
```

### Step 4: Test network monitoring

```bash
# Get the test pod
TEST_POD=$(kubectl get pod -n lab-6-11 -l app=network-test -o jsonpath='{.items[0].metadata.name}')

# Test legitimate internal connection (should NOT trigger alert)
kubectl exec -n lab-6-11 $TEST_POD -- wget -qO- --timeout=3 http://internal-svc 2>/dev/null || true

# Test suspicious external connection (SHOULD trigger alert)
kubectl exec -n lab-6-11 $TEST_POD -- wget -qO- --timeout=3 http://1.2.3.4:4444 2>/dev/null || true

# Test DNS resolution (should work)
kubectl exec -n lab-6-11 $TEST_POD -- nslookup kubernetes.default.svc.cluster.local 2>/dev/null || true
```

### Step 5: Implement NetworkPolicies based on observed traffic

```bash
# Apply strict egress policy based on observed legitimate traffic
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: restrict-egress
  namespace: lab-6-11
spec:
  podSelector:
    matchLabels:
      app: network-test
  policyTypes:
  - Egress
  egress:
  # Allow DNS
  - ports:
    - port: 53
      protocol: UDP
    - port: 53
      protocol: TCP
  # Allow internal cluster communication
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: lab-6-11
    ports:
    - port: 80
      protocol: TCP
    - port: 8080
      protocol: TCP
EOF
```

### Step 6: Analyze network traffic with Falco logs

```bash
# Get Falco pod
FALCO_POD=$(kubectl get pod -n falco -l app.kubernetes.io/name=falco -o jsonpath='{.items[0].metadata.name}')

# Check for network alerts
kubectl logs -n falco $FALCO_POD --tail=100 | grep -E "network|connection|port" | tail -20

# Count network events by type
kubectl logs -n falco $FALCO_POD --tail=200 | \
    grep -o '"rule":"[^"]*"' | \
    grep -i "network\|connection\|port" | \
    sort | uniq -c | sort -rn
```

### Step 7: Verify your solution

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

- [Falco Network Rules](https://falco.org/docs/rules/default-macros/)
- [Cilium Hubble](https://docs.cilium.io/en/stable/gettingstarted/hubble/)
- [Kubernetes NetworkPolicy](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [CKS Exam Curriculum](https://github.com/cncf/curriculum)
