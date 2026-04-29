# Lab 6.10: Container Behavior Analysis with Falco and Audit Logs

## Metadata

- **Domain**: 6 - Monitoring, Logging & Runtime Security
- **Difficulty**: Hard
- **Estimated Time**: 30 minutes
- **Exam Weight**: 20%

## Learning Objectives

- Analyze container runtime behavior using Falco event streams
- Correlate Falco alerts with Kubernetes audit log entries
- Identify anomalous behavior patterns in container workloads
- Use `jq` to query and filter audit log data
- Build a behavioral baseline and detect deviations
- Create comprehensive Falco rules based on observed behavior

## Prerequisites

- Kubernetes cluster v1.29+
- kubectl configured and connected to the cluster
- Falco installed and running
- jq installed for log analysis
- Kubernetes audit logging enabled

## Scenario

You are a security analyst investigating suspicious behavior in the production cluster. Multiple alerts have been triggered and you need to:
1. Analyze Falco event logs to understand what happened
2. Correlate with Kubernetes audit logs to build a complete picture
3. Identify the attack vector and affected resources
4. Create detection rules to prevent future occurrences

## Requirements

1. Configure Falco to output structured JSON logs for analysis
2. Create Falco rules to capture comprehensive container behavior
3. Use `jq` to analyze and filter Falco JSON output
4. Query Kubernetes audit logs to find suspicious API calls
5. Correlate Falco events with audit log entries by timestamp
6. Generate a behavior analysis report

## Instructions

### Step 1: Set up the lab environment

```bash
./setup.sh
```

### Step 2: Create comprehensive behavior monitoring rules

Create `falco-behavior-rules.yaml`:

```yaml
# falco-behavior-rules.yaml

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
    outbound and container and
    not fd.sport in (53)
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
    (fd.name startswith /etc/ or
     fd.name startswith /root/ or
     fd.name startswith /home/) and
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
```

### Step 3: Deploy the behavior monitoring rules

```bash
kubectl create configmap falco-behavior-rules \
  --from-file=falco-behavior-rules.yaml \
  -n falco \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl rollout restart daemonset/falco -n falco
kubectl rollout status daemonset/falco -n falco
```

### Step 4: Generate behavior data

```bash
# Get the test pod
TEST_POD=$(kubectl get pod -n lab-6-10 -l app=behavior-test -o jsonpath='{.items[0].metadata.name}')

# Generate various behaviors
kubectl exec -n lab-6-10 $TEST_POD -- ls /etc/
kubectl exec -n lab-6-10 $TEST_POD -- cat /etc/hostname
kubectl exec -n lab-6-10 $TEST_POD -- wget -q --spider http://example.com 2>/dev/null || true
kubectl exec -n lab-6-10 $TEST_POD -- ps aux
```

### Step 5: Analyze Falco logs with jq

```bash
# Get Falco pod name
FALCO_POD=$(kubectl get pod -n falco -l app.kubernetes.io/name=falco -o jsonpath='{.items[0].metadata.name}')

# Get recent Falco events in JSON format
kubectl logs -n falco $FALCO_POD --tail=100 > /tmp/falco-events.log

# Analyze events by rule
echo "=== Events by Rule ==="
cat /tmp/falco-events.log | grep -o '"rule":"[^"]*"' | sort | uniq -c | sort -rn

# Find WARNING and above events
echo "=== High Priority Events ==="
cat /tmp/falco-events.log | grep -E '"priority":"(WARNING|ERROR|CRITICAL)"' | \
    jq -r '[.time, .rule, .output] | @tsv' 2>/dev/null || \
    grep -E "WARNING|ERROR|CRITICAL" /tmp/falco-events.log | tail -20

# Find events for specific container
echo "=== Events for behavior-test container ==="
cat /tmp/falco-events.log | grep "behavior-test" | tail -10
```

### Step 6: Analyze Kubernetes audit logs

```bash
AUDIT_LOG="/var/log/kubernetes/audit.log"

if [ -f "$AUDIT_LOG" ]; then
    echo "=== API calls in last 5 minutes ==="
    jq --arg since "$(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-5M +%Y-%m-%dT%H:%M:%SZ)" \
       'select(.requestReceivedTimestamp > $since) | {time: .requestReceivedTimestamp, user: .user.username, verb: .verb, resource: .objectRef.resource}' \
       "$AUDIT_LOG" | tail -20

    echo "=== Secret access events ==="
    grep '"resource":"secrets"' "$AUDIT_LOG" | \
        jq 'select(.stage=="ResponseComplete") | {time: .requestReceivedTimestamp, user: .user.username, verb: .verb, name: .objectRef.name}' | \
        tail -10

    echo "=== Exec events ==="
    grep '"subresource":"exec"' "$AUDIT_LOG" | \
        jq '{time: .requestReceivedTimestamp, user: .user.username, pod: .objectRef.name, namespace: .objectRef.namespace}' | \
        tail -10
else
    echo "Audit log not found. Checking alternative locations..."
    find /var/log -name "audit.log" 2>/dev/null | head -3
fi
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

- [Falco Output Formats](https://falco.org/docs/outputs/)
- [Kubernetes Audit Logging](https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/)
- [jq Manual](https://stedolan.github.io/jq/manual/)
- [CKS Exam Curriculum](https://github.com/cncf/curriculum)
