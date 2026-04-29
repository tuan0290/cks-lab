# Solution: Certificate Management

Follow Steps 3-5 from the README. Key commands:

```bash
# Generate key and CSR
openssl genrsa -out /tmp/dev-user.key 2048
openssl req -new -key /tmp/dev-user.key -out /tmp/dev-user.csr -subj "/CN=dev-user/O=developers"

# Approve
kubectl certificate approve dev-user-csr

# Retrieve signed cert
kubectl get csr dev-user-csr -o jsonpath='{.status.certificate}' | base64 -d > /tmp/dev-user.crt
```
