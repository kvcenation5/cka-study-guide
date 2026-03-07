# Kubernetes API Groups: Core vs. Named APIs

The Kubernetes API is not a single flat list. It is organized into **API Groups** to make it easier to extend and version different parts of the system independently.

---

## 🏗️ 1. API Structure Hierachy

When you talk to the API Server, the URL path tells you exactly where that resource lives in the hierarchy:

1.  **`/api/v1`**: The **Core** group (Legacy).
2.  **`/apis/GROUP_NAME/VERSION`**: The **Named** groups (Modern).

---

## 🍎 2. The Core API Group (`/api`)

The Core group contains the fundamental, "original" ingredients of Kubernetes. It does not have a group name in the URL, just `/api/v1`.

*   **Path**: `/api/v1`
*   **Examples**: Pods, Services, Nodes, Namespaces, ConfigMaps, Secrets.
*   **YAML Syntax**: `apiVersion: v1`

---

## 📂 3. The Named API Groups (`/apis`)

Everything added after the initial release is organized into "Named" groups. This allowed teams to work on `apps` separately from `networking`, for example.

*   **Path**: `/apis/<group>/<version>`
*   **Examples**:
    *   **Apps**: `apiVersion: apps/v1` (Deployments, StatefulSets)
    *   **Networking**: `apiVersion: networking.k8s.io/v1` (Ingress, NetworkPolicies)
    *   **Storage**: `apiVersion: storage.k8s.io/v1` (StorageClasses)
    *   **RBAC**: `apiVersion: rbac.authorization.k8s.io/v1` (Roles, RoleBindings)

---

## 🛠️ 4. How to explore the API Groups

### A. The kubectl Discovery Commands
These are the two most important commands for understanding what your cluster supports:

```bash
# List all API VERSIONS supported by the cluster
kubectl api-versions

# List all RESOURCE TYPES, their shortnames, and their API Group
kubectl api-resources
```

### B. The Proxy Method (Peek inside the API)
If you want to see the raw JSON structure:
1.  Start a proxy: `kubectl proxy`
2.  Open another terminal and curl:
    ```bash
    # See the Core group
    curl http://localhost:8001/api/v1
    
    # See the Apps group
    curl http://localhost:8001/apis/apps/v1
    ```

---

## 🌍 5. Component Breakdown

| Feature | Core Group | Named Groups |
| :--- | :--- | :--- |
| **URL Root** | `/api` | `/apis` |
| **Versions** | `v1` | `v1`, `v1beta1`, `v1alpha1` |
| **YAML Example** | `apiVersion: v1` | `apiVersion: apps/v1` |
| **Resources** | Pods, Nodes, Services | Deployments, Ingresses, Jobs |

---

## 📚 References

- [Official Kubernetes API Overview](https://kubernetes.io/docs/concepts/overview/kubernetes-api/)
- [API Group Discovery Guide](https://kubernetes.io/docs/concepts/overview/kubernetes-api/#api-groups)

---

> [!TIP]
> **CKA Strategy**: If you are unsure which `apiVersion` to use in a YAML file during the exam, run `kubectl api-resources`. It will show you exactly which group each resource belongs to in the `APIVERSION` column.
