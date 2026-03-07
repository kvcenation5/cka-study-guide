# RBAC: Role-Based Access Control

Authorization is the process of determining **what** an authenticated user is allowed to do. In Kubernetes, the standard way to manage this is through **RBAC (Role-Based Access Control)**.

---

## 🏗️ 1. The RBAC Matrix

RBAC is built on four core objects. To understand them, you must distinguish between **Scope** (Namespace vs. Cluster).

| Object | Scope | Description |
| :--- | :--- | :--- |
| **Role** | Namespace | Defines permissions **within a specific namespace**. |
| **ClusterRole** | Cluster | Defines permissions **across the entire cluster** (or for non-namespaced resources like Nodes). |
| **RoleBinding** | Namespace | Grants the permissions defined in a Role to a user/group **within a namespace**. |
| **ClusterRoleBinding** | Cluster | Grants the permissions defined in a ClusterRole to a user/group **cluster-wide**. |

---

## 📄 2. Defining Permissions (The "Rules")

A Role contains a list of **Rules**. Each rule has three parts:
1.  **apiGroups**: Which API group the resource belongs to (e.g., `""` for core, `"apps"` for deployments).
2.  **resources**: What you want to access (e.g., `pods`, `services`, `deployments`).
3.  **verbs**: What you are allowed to do (e.g., `get`, `list`, `watch`, `create`, `update`, `delete`).

### Example Role YAML
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: blue
  name: pod-reader
rules:
- apiGroups: [""] # "" indicates the core API group
  resources: ["pods"]
  verbs: ["get", "watch", "list"]
```

---

## 🔗 3. Binding: Linking Users to Roles

A **Binding** connects a **Subject** (User, Group, or ServiceAccount) to a **Role**.

### Example RoleBinding YAML
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
  namespace: blue
subjects:
- kind: User
  name: jane
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-reader # Must match the name of the Role
  apiGroup: rbac.authorization.k8s.io
```

---

## 🛠️ 4. Essential kubectl Commands

The CKA exam heavily uses these "imperative" commands to save time.

### Create RBAC Objects Fast
```bash
# Create a Role
kubectl create role developer --verb=get,list,create --resource=pods,services -n development

# Create a RoleBinding
kubectl create rolebinding dev-user-binding --role=developer --user=jane -n development

# Create a ClusterRole
kubectl create clusterrole node-reader --verb=get,list --resource=nodes

# Create a ClusterRoleBinding
kubectl create clusterrolebinding jane-node-binding --clusterrole=node-reader --user=jane
```

### 🧪 Testing Permissions (The Gold Mine)
Before you finish a task, always verify it works using the `can-i` command.

```bash
# Can I do this?
kubectl auth can-i create pods

# Can "Jane" do this? (Requires Admin)
kubectl auth can-i list secrets --as jane

# Can "Jane" do this in a specific namespace?
kubectl auth can-i list pods --as jane -n blue
```

---

## 🤖 5. ServiceAccounts and RBAC

**ServiceAccounts** are for processes (Pods) rather than humans.
*   When a Pod needs to talk to the API (e.g., a dashboard or a CI/CD tool), it uses a ServiceAccount.
*   You bind a Role to a ServiceAccount exactly like you do for a User.

```bash
kubectl create serviceaccount dashboard-sa
kubectl create rolebinding dash-bind --role=pod-reader --serviceaccount=default:dashboard-sa
```

---

## 🚩 6. CKA Exam Strategy

1.  **Namespace Awareness**: If a question mentions a namespace, use `Role` and `RoleBinding`. If it's cluster-wide (Nodes, PVs) or "across all namespaces," use `ClusterRole`.
2.  **Check API Groups**: If you can't remember if `deployments` belongs to `apps` or `""`, run `kubectl api-resources`.
3.  **Verify with `can-i`**: This is the only way to be 100% sure your RBAC setup is correct before moving to the next question.

---

> [!IMPORTANT]
> **Superuser Alert**: The built-in ClusterRole **`cluster-admin`** and the group **`system:masters`** have "God Mode" permissions. They can do anything to any resource. Be extremely careful when binding to these!
