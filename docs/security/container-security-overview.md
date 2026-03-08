# Container Security Overview

Container security in Kubernetes is not a single setting, but a multi-layered approach often called "Defense in Depth." This guide summarizes the focus areas for securing individual containers and their runtime environment.

---

## 🏗️ 1. The 4C's of Cloud Native Security

Kubernetes security is often divided into four distinct layers. If one layer is weak, the others are at risk.

1.  **Cloud**: The underlying infrastructure (AWS, GCP, Bare Metal). If the API is exposed or IAM is too broad, the cluster is lost.
2.  **Cluster**: The Kubernetes components (API Server, Etcd). Secured via TLS, RBAC, and Network Policies.
3.  **Container**: The focus of this guide. Secured via Image Scanning and Security Contexts.
4.  **Code**: The application logic itself. Secured via Static Analysis and safe coding practices.

---

## 🛠️ 2. Hardening the Container Runtime

Beyond RBAC and ServiceAccounts, you must secure the actual process running on the host.

### A. Seccomp (Secure Computing Mode)
Seccomp restricts the system calls (syscalls) a container can make to the Linux kernel. 
*   **Default Profile**: In modern K8s, use the `RuntimeDefault` profile to block dangerous syscalls (like `reboot` or `mount`).
*   **YAML Configuration**:
    ```yaml
    securityContext:
      seccompProfile:
        type: RuntimeDefault
    ```

### B. AppArmor & SELinux
These are Linux Security Modules (LSM) that provide "Mandatory Access Control." They prevent a container from reading/writing to files it shouldn't access on the host, even if it has root privileges.

---

## 🔍 3. Secure Container Lifecycle (Build, Ship, Run)

### 1. Build Phase (Secure Images)
*   **Scan**: Use scanners (Trivy) to find vulnerabilities in dependencies.
*   **Minimize**: Use "Distroless" or "Small" base images to remove tools that hackers use (like `wget`, `curl`, `netcat`).
*   **Non-Root**: Never run your application as the `root` user.

### 2. Ship Phase (Registry Security)
*   **Private Registries**: Use `imagePullSecrets` to restrict who can download your code.
*   **Image Signing**: Use tools like `Cosign` to sign images. The cluster can then reject any image that doesn't have a valid signature.

### 3. Run Phase (Runtime Security)
*   **Immutability**: Set `readOnlyRootFilesystem: true`. This prevents a hacker from downloading a script or binary into the container after it's running.
*   **Capabilities**: Drop all default Linux capabilities and add back only the bare minimum.

---

## 📊 4. Comparison of Isolation Levels

| Level | Description | Security |
| :--- | :--- | :--- |
| **Standard Container** | Uses Namespaces and Cgroups. Shared Kernel. | Moderate |
| **GVisor / Katacontainers** | Provides a "Sandboxed" kernel for each container. | High |
| **Privileged Container** | No isolation. Full access to host hardware. | **Dangerous** |

---

## 🚩 5. CKA/CKS Exam Perspective

*   **CKA**: Focus on `imagePullSecrets`, `SecurityContext` (runAsUser, Privileged), and `ServiceAccounts`.
*   **CKS**: Focus on `Seccomp`, `AppArmor`, Runtime Security Monitoring (Falco), and Vulnerability Scanning.

---

> [!TIP]
> **Checklist for Production**:
> - [ ] Is it running as non-root?
> - [ ] Is the root filesystem read-only?
> - [ ] Are all capabilities dropped?
> - [ ] Is there a CPU/Memory limit set (to prevent DoS)?
> - [ ] Is the image scanned and signed?
