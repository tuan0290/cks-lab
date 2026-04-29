# Solution: Admission Controllers Configuration

Apply all manifests from Steps 3-5 of the README.

Key: The PodSecurity admission controller is enabled by default in Kubernetes v1.25+. Test it by creating a namespace with `pod-security.kubernetes.io/enforce: restricted` and attempting to create a privileged pod.
