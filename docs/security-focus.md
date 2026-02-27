# 🔐 CKA Security Focus

In the CKA exam, security is not a standalone domain but a critical thread woven through the most important tasks. This page highlights the **Security Focus** for each question in our 17-question plan.

## Security Mapping (17 Questions)

| Domain | Weight | Questions | Security Focus Area | Key Tasks |
| :--- | :--- | :--- | :--- | :--- |
| **Troubleshooting** | 30% | **~5** | **Auth & Certs** | Fix broken RBAC, troubleshoot expired Kubeadm certs, debug API 401/403 errors. |
| **Arch & Intro** | 25% | **~4** | **RBAC** | Create Roles/ClusterRoles, Bindings, and verify permissions with `auth can-i`. |
| **Networking** | 20% | **~3** | **Network Isolation** | Implement Ingress/Egress NetworkPolicies and secure Ingress with TLS Secrets. |
| **Workloads** | 15% | **~3** | **Identity & Secrets** | Manage ServiceAccounts for Pods and securely inject Secrets/ConfigMaps. |
| **Storage** | 10% | **~2** | **N/A** | Volume access modes and persistence. |

---

## 🎯 Top Security Tasks to Master

### 1. RBAC (Role Based Access Control)
*   **Create Roles/ClusterRoles**: Grant specific verbs (get, list, watch, create) to resources.
*   **Bindings**: Link users or ServiceAccounts to those roles.
*   **Verification**: Always use `kubectl auth can-i ...` to test your work.

### 2. NetworkPolicies
*   **Default Deny**: Understand how to isolate a namespace.
*   **Selective Allow**: Permit traffic only from specific Pods (label selectors) or CIDR ranges.
*   **Port Security**: Limit traffic to specific ports (e.g., 80, 443, 6379).

### 3. Secrets Management
*   **Creation**: Create secrets from literal values or files.
*   **Mounting**: Inject secrets as environment variables or as volumes in the Pod spec.

### 4. Certificates & TLS
*   **Control Plane Security**: Know where the CA, Server, and Client certs live (usually `/etc/kubernetes/pki`).
*   **Kubeconfig**: Manage user credentials and context within the kubeconfig file.

---

> [!TIP]
> **Pro-Tip**: When troubleshooting in the exam, if a Pod is failing to start or a command is failing with "Forbidden", **RBAC** or **SecurityContext** is the usual suspect!
