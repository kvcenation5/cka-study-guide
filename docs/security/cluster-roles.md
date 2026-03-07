# ClusterRoles: Cluster-Wide Permissions

In Kubernetes, a **ClusterRole** is a non-namespaced resource. While a regular `Role` is always trapped inside a specific namespace, a `ClusterRole` defines permissions that apply at the **Cluster Level**.

---

## 🏗️ 1. Why do we need Cluster-Level Roles?

There are three specific scenarios where a regular `Role` simply cannot work:

### A. Non-Namespaced Resources
Some resources in Kubernetes don't belong to any namespace. You cannot use a `Role` to manage them.
*   **Examples**: `Nodes`, `PersistentVolumes`, `Namespaces`, `CustomResourceDefinitions`.

### B. Access Across ALL Namespaces
If you want a user (like a Security Auditor) to be able to "list pods" in every single namespace in the cluster, you don't want to create 50 separate `Roles`. A single `ClusterRole` can grant this power globally.

### C. Non-Resource Endpoints
Permissions for administrative URLs that exist outside of the standard API paths.
*   **Example**: `/healthz`, `/metrics`, `/logs`.

---

## 📄 2. ClusterRole YAML Example

A `ClusterRole` looks identical to a `Role` but **must NOT** have a `namespace` field.

```yaml
# cluster-admin-role.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: storage-auditor # Unique name at the cluster level
rules:
- apiGroups: [""]
  # Resources that are NOT namespaced (Global)
  resources: ["persistentvolumes", "nodes"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["storage.k8s.io"]
  # Resources in a specific API Group
  resources: ["storageclasses"]
  verbs: ["get", "list"]
- apiGroups: [""]
  # Namespaced resources (but granting access to ALL of them globally)
  resources: ["persistentvolumeclaims"]
  verbs: ["get", "list"]
```

---

## 🔗 3. The Power of the Binding

The most important thing to remember is that a `ClusterRole` can be used by **two different types of bindings**, and the result is completely different:

| Binding Used | Resulting Scope | Example Use Case |
| :--- | :--- | :--- |
| **ClusterRoleBinding** | **Global** | An Admin who can see everything in the cluster. |
| **RoleBinding** | **Namespaced** | A Developer who is given the "view" ClusterRole, but only inside the `frontend` namespace. |

---

## 🛠️ 4. Essential kubectl Commands

### Create a ClusterRole
```bash
# Imperative command
kubectl create clusterrole storage-admin --verb=get,list,create --resource=persistentvolumes
```

### View ClusterRoles
```bash
# Notice you don't need a -n flag
kubectl get clusterroles
```

### Check Scope
To verify which resources are cluster-level vs namespace-level:
```bash
kubectl api-resources --namespaced=false
```

---

## 🚩 5. CKA Exam Strategy: Spotting the Difference

If a question asks you to grant permissions, look for these keywords to decide if you need a `ClusterRole`:

1.  **"Across all namespaces"** -> Use `ClusterRole`.
2.  **"Manage Nodes"** or **"Manage PVs"** -> Use `ClusterRole` (these aren't in namespaces).
3.  **"Manage Cluster-level resources"** -> Use `ClusterRole`.

---

> [!IMPORTANT]
> **Built-in ClusterRoles**: Kubernetes comes with several pre-defined ClusterRoles that you should use instead of writing your own whenever possible:
> - `cluster-admin`: Full power over everything.
> - `admin`: Full power within a namespace (when bound via RoleBinding).
> - `edit`: Can create/modify resources in a namespace.
> - `view`: Read-only access to a namespace.
