# RoleBinding & ClusterRoleBinding

While **Roles** define *what* can be done, **Bindings** define *who* can do it. In Kubernetes, a Binding is the "Glue" that connects a **Subject** to a **Role**.

---

## 👤 1. The Three Types of Subjects

A Binding can grant permissions to three different types of entities:

1.  **User**: A human being (e.g., `CN=jane` from a certificate).
2.  **Group**: A collection of users (e.g., `O=system:masters`).
3.  **ServiceAccount**: An identity for a **Pod** (e.g., `system:serviceaccount:default:my-app`).

---

## 🔗 2. The Three Mapping Patterns

This is the most critical part for the CKA exam. There are three ways to link roles and bindings:

### Pattern A: Role + RoleBinding (Namespace Restricted)
*   **Role**: Defines permissions in Namespace `A`.
*   **RoleBinding**: Created in Namespace `A`.
*   **Result**: The user can only access resources inside Namespace `A`.

### Pattern B: ClusterRole + ClusterRoleBinding (The Whole Cluster)
*   **ClusterRole**: Defines permissions (e.g., "read secrets").
*   **ClusterRoleBinding**: Created at the cluster level (no namespace).
*   **Result**: The user can read secrets in **EVERY** namespace and access cluster-wide resources like Nodes.

### Pattern C: ClusterRole + RoleBinding (The "Limited" Trick)
*   **ClusterRole**: A generic role (e.g., the built-in `view` or `edit` role).
*   **RoleBinding**: Created in Namespace `B`.
*   **Result**: The user gets the permissions of the ClusterRole, but **ONLY** inside Namespace `B`.
*   **Why use this?**: It allows you to define a common role once (like "Admin") and re-use it across many namespaces without duplicating the Role YAML.

---

## 📄 3. Anatomy of a RoleBinding YAML

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: dev-binding
  namespace: development # Where the permissions apply
subjects:
- kind: User
  name: martin
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role # or ClusterRole (for Pattern C)
  name: pod-manager 
  apiGroup: rbac.authorization.k8s.io
```

---

## 🛠️ 4. Essential kubectl Commands

### Create a RoleBinding (to a User)
```bash
kubectl create rolebinding my-binding --role=admin --user=martin -n development
```

### Create a RoleBinding (to a ServiceAccount)
```bash
kubectl create rolebinding sa-binding --role=view --serviceaccount=default:my-sa -n production
```

### Create a ClusterRoleBinding (to a Group)
```bash
kubectl create clusterrolebinding group-binding --clusterrole=view --group=system:serviceaccounts:frontend
```

---

## 🧪 5. Testing with "auth can-i"

Always verify your bindings. If you use `ClusterRole + RoleBinding`, you must specify the namespace in your test!

```bash
# Verify Pattern C (ClusterRole + RoleBinding)
# Does Jane have 'view' access (from ClusterRole) in namespace 'blue'?
kubectl auth can-i get pods --as jane -n blue
# Expected: yes

# Does she have it in namespace 'red'?
kubectl auth can-i get pods --as jane -n red
# Expected: no (unless there is a binding there too)
```

---

> [!IMPORTANT]
> **Immortal RoleRefs**: Once a RoleBinding is created, you **cannot** change the `roleRef` (the role it points to). If you want to point to a different role, you must **delete** the RoleBinding and recreate it.
