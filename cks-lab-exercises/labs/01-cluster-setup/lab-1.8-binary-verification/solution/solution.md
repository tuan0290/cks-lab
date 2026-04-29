# Solution: Kubernetes Binary Verification

Run the commands from Steps 2-4 of the README to compute the SHA256 of the kubectl binary and store it in ConfigMaps.

```bash
KUBECTL_PATH=$(which kubectl)
sha256sum "$KUBECTL_PATH"
```

Compare the output with the official checksum at `https://dl.k8s.io/release/<version>/bin/linux/amd64/kubectl.sha256`.
