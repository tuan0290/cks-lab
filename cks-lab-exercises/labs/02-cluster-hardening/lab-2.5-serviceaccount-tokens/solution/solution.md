# Solution: ServiceAccount Token Management

Apply all manifests from Steps 2-4 of the README.

Key verification:
```bash
# Confirm no token mounted in no-token-pod
kubectl get pod no-token-pod -n lab-2-5 -o jsonpath='{.spec.automountServiceAccountToken}'
# Expected: false

# Confirm api-reader-sa can only get/list pods
kubectl auth can-i get pods --as=system:serviceaccount:lab-2-5:api-reader-sa -n lab-2-5
# Expected: yes
kubectl auth can-i delete pods --as=system:serviceaccount:lab-2-5:api-reader-sa -n lab-2-5
# Expected: no
```
