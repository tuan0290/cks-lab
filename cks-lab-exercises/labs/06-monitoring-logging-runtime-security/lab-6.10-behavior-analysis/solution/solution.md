# Solution: Lab 6.10 - Container Behavior Analysis with Falco and Audit Logs

## Overview

This solution demonstrates how to analyze container behavior using Falco event streams and Kubernetes audit logs.

## Step-by-Step Solution

### Step 1: Create comprehensive behavior monitoring rules

```bash
cat > falco-behavior-rules.yaml << 'EOF'
# Rule 1: Track all process executions in containers
- rule: Container Process Execution
  desc: Track all process executions in containers for behavior analysis
  condition: >
    spawned_process and container and
    not proc.name in (pause, containerd-shim)
  output: >
    Process executed in container (user=%user.name proc=%proc.name
    cmdline=%proc.cmdline parent=%proc.pname container=%container.name
    image=%container.image.repository pod=%k8s.pod.name
    namespace=%k8s.ns.name time=%evt.time)
  priority: INFORMATIONAL
  tags: [behavior, process, cks]

# Rule 2: Track network connections
- rule: Container Network Connection
  desc: Track outbound network connections from containers
  condition: >
    outbound and container and not fd.sport in (53)
  output: >
    Network connection from container (user=%user.name proc=%proc.name
    connection=%fd.name container=%container.name
    image=%container.image.repository pod=%k8s.pod.name)
  priority: INFORMATIONAL
  tags: [behavior, network, cks]

# Rule 3: Detect anomalous file access patterns
- rule: Anomalous File Access Pattern
  desc: Detect access to multiple sensitive files in short time
  condition: >
    open_read and container and
    (fd.name startswith /etc/ or fd.name startswith /root/ or fd.name startswith /home/) and
    not proc.name in (nginx, apache2, httpd, node, python, java)
  output: >
    Anomalous file access (user=%user.name proc=%proc.name
    file=%fd.name container=%container.name
    image=%container.image.repository pod=%k8s.pod.name)
  priority: WARNING
  tags: [behavior, filesystem, cks]

# Rule 4: Detect crypto mining indicators
- rule: Crypto Mining Indicators
  desc: Detect processes that may indicate crypto mining activity
  condition: >
    spawned_process and container and
    (proc.name in (xmrig, minerd, cpuminer, cgminer, bfgminer) or
     proc.cmdline contains "stratum+tcp" or
     proc.cmdline contains "mining.pool")
  output: >
    Potential crypto mining detected (user=%user.name proc=%proc.name
    cmdline=%proc.cmdline container=%container.name
    image=%container.image.repository)
  priority: CRITICAL
  tags: [behavior, cryptomining, cks]
EOF
```

### Step 2: Deploy the rules

```bash
kubectl create configmap falco-behavior-rules \
  --from-file=falco-behavior-rules.yaml \
  -n falco \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl rollout restart daemonset/falco -n falco
kubectl rollout status daemonset/falco -n falco
```

### Step 3: Generate behavior data

```bash
TEST_POD=$(kubectl get pod -n lab-6-10 -l app=behavior-test -o jsonpath='{.items[0].metadata.name}')

# Generate various behaviors
kubectl exec -n lab-6-10 $TEST_POD -- ls /etc/
kubectl exec -n lab-6-10 $TEST_POD -- cat /etc/hostname
kubectl exec -n lab-6-10 $TEST_POD -- ps aux
```

### Step 4: Analyze Falco logs

```bash
# Get Falco pod
FALCO_POD=$(kubectl get pod -n falco -l app.kubernetes.io/name=falco -o jsonpath='{.items[0].metadata.name}')

# Collect logs
kubectl logs -n falco $FALCO_POD --tail=200 > /tmp/falco-events.log

# Count events by rule
echo "=== Events by Rule ==="
grep -o '"rule":"[^"]*"' /tmp/falco-events.log | sort | uniq -c | sort -rn

# Find high priority events
echo "=== WARNING+ Events ==="
grep -E '"priority":"(WARNING|ERROR|CRITICAL)"' /tmp/falco-events.log | \
    python3 -c "import sys,json; [print(json.dumps({k:v for k,v in json.loads(l).items() if k in ['time','rule','output','priority']}, indent=2)) for l in sys.stdin if l.strip()]" 2>/dev/null || \
    grep -E "WARNING|ERROR|CRITICAL" /tmp/falco-events.log | tail -20
```

### Step 5: Analyze Kubernetes audit logs

```bash
AUDIT_LOG="/var/log/kubernetes/audit.log"

if [ -f "$AUDIT_LOG" ]; then
    # Recent API calls
    echo "=== Recent API Calls ==="
    tail -100 "$AUDIT_LOG" | \
        jq '{time: .requestReceivedTimestamp, user: .user.username, verb: .verb, resource: .objectRef.resource, name: .objectRef.name}' | \
        head -50

    # Secret access
    echo "=== Secret Access ==="
    grep '"resource":"secrets"' "$AUDIT_LOG" | \
        jq 'select(.stage=="ResponseComplete") | {time: .requestReceivedTimestamp, user: .user.username, verb: .verb, name: .objectRef.name}' | \
        tail -10

    # Exec events
    echo "=== Exec Events ==="
    grep '"subresource":"exec"' "$AUDIT_LOG" | \
        jq '{time: .requestReceivedTimestamp, user: .user.username, pod: .objectRef.name, namespace: .objectRef.namespace}' | \
        tail -10

    # Failed requests
    echo "=== Failed Requests ==="
    jq 'select(.responseStatus.code >= 400) | {time: .requestReceivedTimestamp, user: .user.username, code: .responseStatus.code, verb: .verb, resource: .objectRef.resource}' "$AUDIT_LOG" | \
        tail -20
fi
```

## Key Analysis Techniques

### Falco Log Analysis with jq

```bash
# Parse Falco JSON output
kubectl logs -n falco $FALCO_POD | \
    grep "^{" | \
    jq 'select(.priority == "WARNING") | {time, rule, output}' | \
    head -20

# Count by container
kubectl logs -n falco $FALCO_POD | \
    grep "^{" | \
    jq -r '.output' | \
    grep -o 'container=[^ ]*' | \
    sort | uniq -c | sort -rn
```

### Audit Log Correlation

```bash
# Find all actions by a specific user
USER="system:serviceaccount:default:default"
grep "\"username\":\"$USER\"" "$AUDIT_LOG" | \
    jq '{time: .requestReceivedTimestamp, verb: .verb, resource: .objectRef.resource}' | \
    tail -20

# Build timeline of events
jq -r '[.requestReceivedTimestamp, .user.username, .verb, .objectRef.resource, .objectRef.name] | @tsv' "$AUDIT_LOG" | \
    sort | tail -30
```

## CKS Exam Tips

- Know how to use `jq` to filter and format JSON output
- Understand Falco output fields: `time`, `rule`, `priority`, `output`
- Know key audit log fields: `requestReceivedTimestamp`, `user.username`, `verb`, `objectRef`
- Practice correlating timestamps between Falco and audit logs
- Remember: `stage=="ResponseComplete"` filters for completed API calls
