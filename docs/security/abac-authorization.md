# ABAC: Attribute-Based Access Control

**ABAC (Attribute-Based Access Control)** is a legacy authorization mechanism in Kubernetes that uses a local file containing policies to define permissions. Unlike RBAC, it is **static** and difficult to manage at scale.

---

## 🏗️ 1. How ABAC Works

In ABAC, permissions are defined by a set of **Attributes**. When a request comes in, the API Server compares the request's attributes (User, Resource, Namespace) against the local policy file.

### Attributes Checked:
*   **User**: The name of the authenticated user.
*   **Namespace**: The target namespace.
*   **Resource**: The type of object (e.g., `pods`).
*   **APIGroup**: The API group (e.g., `apps`).
*   **Readonly**: Whether the action only reads data (e.g., `get`, `list`).

---

## 📄 2. The Policy File Format

ABAC policies are written in a special **JSON Lines** format (one JSON object per line). 

**Example Policy File (`/etc/kubernetes/abac-policy.json`):**
```json
{"apiVersion": "abac.authorization.kubernetes.io/v1beta1", "kind": "Policy", "spec": {"user": "alice", "namespace": "project-a", "resource": "pods", "readonly": true}}
{"apiVersion": "abac.authorization.kubernetes.io/v1beta1", "kind": "Policy", "spec": {"user": "bob", "namespace": "*", "resource": "*", "readonly": false}}
```
*   **Alice**: Can only **read pods** in the `project-a` namespace.
*   **Bob**: Can do **anything** in **all** namespaces (Admin-like).

---

## ⚙️ 3. How to Enable ABAC

To use ABAC, you must configure the `kube-apiserver` with two specific flags:

1.  **`--authorization-mode`**: Add `ABAC` to the list.
2.  **`--authorization-policy-file`**: Path to your JSON policy file.

**Example Manifest Snippet:**
```yaml
spec:
  containers:
  - command:
    - kube-apiserver
    - --authorization-mode=Node,RBAC,ABAC
    - --authorization-policy-file=/etc/kubernetes/abac-policy.json
```

---

## 🔄 4. ABAC vs. RBAC

| Feature | ABAC | RBAC |
| :--- | :--- | :--- |
| **Storage** | Local File on Master Disk | etcd (Database) |
| **Management** | Manual file editing + SSH | `kubectl` commands |
| **Updates** | **Requires API Server Restart** | Instant (Dynamic) |
| **Auditability** | Difficult | Easy via `kubectl get roles` |
| **Modern Usage** | Deprecated / Legacy | Standard |

---

## 🧪 5. CKA Exam Perspective

While you are unlikely to perform a complex ABAC setup in the exam, you should know:
1.  **Where to find the flag**: In the `kube-apiserver.yaml` manifest.
2.  **The Main Constraint**: Changes to ABAC require a **restart** of the API Server process, which can cause cluster downtime if not managed as a static pod.

---

> [!WARNING]
> **Security Risk**: Because ABAC is file-based and static, it is prone to human error. In most production environments, you should migrate any remaining ABAC policies to **RBAC** for better security and visibility.
