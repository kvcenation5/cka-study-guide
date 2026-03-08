# Container Image Security

Securing the images that run in your cluster is the first line of defense. If a malicious image is allowed to run, it won't matter how strong your RBAC is. This guide covers how to secure, pull, and verify container images in Kubernetes.

---

## 🏗️ 1. Private Registries and Credentials

By default, Kubernetes tries to pull images from public registries (like Docker Hub) without credentials. For private registries, you must provide a way for the cluster to authenticate.

### Step A: Create a Docker-Registry Secret
You must create a special type of secret to store your registry credentials.
```bash
kubectl create secret docker-registry my-registry-key \
  --docker-server=DOCKER_REGISTRY_SERVER \
  --docker-username=DOCKER_USER \
  --docker-password=DOCKER_PASSWORD \
  --docker-email=DOCKER_EMAIL
```

### Step B: Using `imagePullSecrets` in a Pod
You must explicitly tell the Pod to use that secret when pulling the image.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: private-app
spec:
  containers:
  - name: my-container
    image: my-private-repo/app:v1
  # The secret must be in the SAME namespace as the Pod
  imagePullSecrets:
  - name: my-registry-key
```

---

## 🛡️ 2. Admission Controllers: ImagePolicyWebhook

The **ImagePolicyWebhook** is a specialized admission controller that can verify image attributes before a Pod is created.

*   **How it works**: The API Server sends a request to an external service (like OPA or a vulnerability scanner).
*   **The Decision**: The external service can reject the Pod if:
    *   The image has high-severity vulnerabilities.
    *   The image hasn't been signed.
    *   The image comes from an unapproved registry (e.g., public Docker Hub instead of a private JFrog).

---

## 🧹 3. Best Practices for Image Security

To minimize the attack surface, follow these "Least Privilege" rules for your images:

| Practice | Why it matters |
| :--- | :--- |
| **Use Specific Tags** | Never use `:latest`. It is non-deterministic and makes rollbacks impossible. Use versions or SHA256 hashes. |
| **Thin Images** | Use base images like `Alpine` or `Distroless`. If there's no `curl` or `sh` in the image, a hacker can't use them. |
| **Non-Root Users** | Build your images to run as a non-root user. Use the `USER` directive in your Dockerfile. |
| **ImagePullPolicy** | Set `ImagePullPolicy: Always`. This ensures the Kubelet always checks the registry for the latest authorized version, even if the image is already cached on the node. |

---

## 🔍 4. Image Vulnerability Scanning

Security should start in the CI/CD pipeline, not just inside the cluster.
*   **Static Analysis**: Tools like `Trivy`, `Clair`, or `Grype` scan the image layers for known CVEs.
*   **Runtime Security**: Tools like `Falco` monitor what the container actually *does* while running, alerting you if it makes unexpected network connections or writes to sensitive files.

---

## 🚩 5. CKA Exam Perspective

1.  **Registry Secrets**: You will likely be asked to create a `docker-registry` secret and attach it to a deployment. Remember: **Secrets are namespace-scoped**. If your secret is in `default` but your pod is in `prod`, it will fail to pull.
2.  **Pull Policy**: Be prepared to change the `ImagePullPolicy` on a running deployment to fix an "ImagePullBackOff" or security issue.
3.  **Forbidden Registries**: If a pod stays in `Pending` with a "Forbidden" error, check for an **Admission Controller** or **ImagePolicyWebhook** that might be blocking untrusted registries.

---

> [!TIP]
> **One-Time Use**: If you find yourself manually creating `imagePullSecrets` for every pod, you can add the secret to the **ServiceAccount** instead. Any pod using that ServiceAccount will automatically inherit the secret!
> `kubectl patch serviceaccount default -p '{"imagePullSecrets": [{"name": "my-registry-key"}]}'`
