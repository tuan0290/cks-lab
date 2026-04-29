# Solution: Cluster Upgrade Security

Run Steps 2-5 from the README to gather version info and create all three ConfigMaps.

```bash
# Quick check of cluster version
kubectl version -o json

# Check for deprecated APIs in use
kubectl api-resources --verbs=list -o name 2>/dev/null | head -5
```
