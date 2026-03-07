# Namespaced vs. Cluster-Scoped Resources

In Kubernetes, resources sit at two different levels of the hierarchy: **Namespaced** or **Cluster-Scoped**. Understanding this distinction is the key to mastering RBAC and resource management.

---

## 🏗️ 1. Concept: Virtual vs. Global

### Namespaced Resources
These resources live inside a **Namespace** (a virtual cluster). They are isolated from other namespaces. 
*   **Isolation**: A pod in namespace `A` is completely separate from a pod in namespace `B`.
*   **Deletion**: If you delete a namespace, all namespaced resources inside it are deleted.
*   **RBAC**: Managed by `Roles` and `RoleBindings`.

### Cluster-Scoped Resources
These resources are **global** to the entire cluster. They sit "above" namespaces.
*   **Scope**: They are visible and shared across the whole cluster.
*   **RBAC**: Managed by `ClusterRoles` and `ClusterRoleBindings`.

---

## 🔍 2. How to discover resource scope

The most important tool for the CKA exam is `kubectl api-resources`. Use the `--namespaced` flag to filter the list.

### List all Namespaced Resources
Use this when you want to see what can be managed with a regular **Role**.
```bash
kubectl api-resources --namespaced=true
```
*Common results: Pods, Services, Deployments, ConfigMaps, Secrets, PVCs.*

### List all Cluster-Scoped Resources
Use this when you want to see what requires a **ClusterRole**.
```bash
kubectl api-resources --namespaced=false
```
*Common results: Nodes, PersistentVolumes, Namespaces, StorageClasses.*

---

## 📊 3. Common Resource Comparison

| Namespaced (The "Inside" Stuff) | Cluster-Scoped (The "Infrastructure") |
| :--- | :--- |
| **Pods** | **Nodes** |
| **Deployments / StatefulSets** | **PersistentVolumes (PV)** |
| **Services / Ingresses** | **StorageClasses** |
| **ConfigMaps / Secrets** | **Namespaces** (Yes, namespaces are global!) |
| **PersistentVolumeClaims (PVC)** | **CustomResourceDefinitions (CRD)** |

---

## 🛡️ 4. Why this matters for RBAC (Role vs ClusterRole)

The scope of the resource dictates which RBAC object you **must** use:

1.  **If the resource is Namespaced**: You can use either a `Role` (local access) or a `ClusterRole` (global access).
2.  **If the resource is Cluster-Scoped**: You **MUST** use a `ClusterRole`. A regular `Role` cannot grant permissions to Nodes or PVs because those resources don't belong to any namespace.

---

## 🧪 5. Testing Scope in the CLI

If you aren't sure if a resource is namespaced, try running `get` without a namespace and then with one:

```bash
# Nodes don't have namespaces (Cluster-scoped)
kubectl get nodes -n default 
# Result: Still shows all nodes, as the namespace flag is ignored.

# Pods are namespaced
kubectl get pods -n default
# Result: Shows only pods in 'default'.
```

---

> [!TIP]
> **CKA Strategy**: If a question asks you to "List all resources that are NOT namespaced," the answer is exactly the output of `kubectl api-resources --namespaced=false`.
