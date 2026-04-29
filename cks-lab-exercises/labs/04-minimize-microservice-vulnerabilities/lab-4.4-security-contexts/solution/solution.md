# Solution: Security Contexts

Apply both pod manifests from Steps 2-3 of the README.

Key verification:
```bash
kubectl get pod secure-app -n lab-4-4 -o jsonpath='{.spec.securityContext}'
kubectl get pod secure-app -n lab-4-4 -o jsonpath='{.spec.containers[0].securityContext}'
```
