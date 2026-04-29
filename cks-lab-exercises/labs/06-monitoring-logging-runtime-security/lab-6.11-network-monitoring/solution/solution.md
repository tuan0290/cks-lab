# Solution: Lab 6.11 - Network Traffic Monitoring and Anomaly Detection

## Overview

This solution demonstrates how to monitor network traffic and detect anomalies using Falco rules and NetworkPolicies.

## Step-by-Step Solution

### Step 1: Create network monitoring Falco rules

```bash
cat > falco-network-monitoring-rules.yaml << 'EOF'
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
    evt.type = sendmsg and container and
    fd.sport = 53 and evt.buflen > 512
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
EOF
```

### Step 2: Deploy the rules

```bash
kubectl create configmap falco-network-monitoring \
  --from-file=falco-network-monitoring-rules.yaml \
  -n falco \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl rollout restart daemonset/falco -n falco
kubectl rollout status daemonset/falco -n falco
```

### Step 3: Test network monitoring

```bash
TEST_POD=$(kubectl get pod -n lab-6-11 -l app=network-test -o jsonpath='{.items[0].metadata.name}')

# Test legitimate internal connection (should NOT trigger alert)
kubectl exec -n lab-6-11 $TEST_POD -- wget -qO- --timeout=3 http://internal-svc 2>/dev/null || true

# Test suspicious port connection (SHOULD trigger alert)
kubectl exec -n lab-6-11 $TEST_POD -- nc -z -w1 1.2.3.4 4444 2>/dev/null || true

# Check Falco logs
sleep 3
kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=20 | grep -i "suspicious\|external"
```

### Step 4: Implement egress restriction NetworkPolicy

```bash
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
  # Allow internal cluster communication only
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

### Step 5: Verify traffic is blocked

```bash
# This should now be blocked by NetworkPolicy
kubectl exec -n lab-6-11 $TEST_POD -- wget -qO- --timeout=3 http://1.2.3.4 2>&1 || echo "Blocked as expected"

# Internal traffic should still work
kubectl exec -n lab-6-11 $TEST_POD -- wget -qO- --timeout=3 http://internal-svc 2>/dev/null && echo "Internal traffic works"
```

## Key Concepts

### RFC1918 Private IP Ranges

| Range | CIDR | Description |
|-------|------|-------------|
| 10.x.x.x | 10.0.0.0/8 | Class A private |
| 172.16-31.x.x | 172.16.0.0/12 | Class B private |
| 192.168.x.x | 192.168.0.0/16 | Class C private |

### Common C2 Ports to Monitor

| Port | Common Use |
|------|-----------|
| 4444 | Metasploit default |
| 1337 | Common backdoor |
| 31337 | Elite/leet port |
| 6666-6669 | IRC (often used for botnets) |
| 8888, 9999 | Common alternative ports |

### Falco Network Fields

| Field | Description |
|-------|-------------|
| `fd.sip` | Source IP address |
| `fd.dip` | Destination IP address |
| `fd.sport` | Source port |
| `fd.dport` | Destination port |
| `fd.name` | Full connection string (ip:port) |
| `outbound` | Macro: outbound connection |
| `inbound` | Macro: inbound connection |

## Network Monitoring Strategy

1. **Baseline**: Understand normal traffic patterns first
2. **Default-deny**: Block all traffic, then allow what's needed
3. **Monitor**: Use Falco to detect deviations from baseline
4. **Alert**: Set appropriate priorities (WARNING for unusual, CRITICAL for known-bad)
5. **Respond**: Have playbooks ready for each alert type

## CKS Exam Tips

- Know RFC1918 private IP ranges by heart
- Understand Falco network macros: `outbound`, `inbound`, `fd.sip`, `fd.sport`
- NetworkPolicy + Falco = defense in depth for network security
- DNS (port 53) must always be explicitly allowed
- Know common attack ports: 4444 (Metasploit), 1337, 31337
