# RBAC kubectl Cheatsheet

This is a comprehensive reference for all `kubectl` commands related to Role-Based Access Control. Use these imperative commands during the CKA exam to save time and avoid YAML errors.

---

## 🏗️ 1. Create Commands (Imperative)

### Roles & ClusterRoles
```bash
# Create a Role with multiple verbs and resources
kubectl create role developer --verb=get,list,create,delete --resource=pods,services -n development

# Create a ClusterRole
kubectl create clusterrole node-reader --verb=get,list --resource=nodes

# Create a Role that can access specific resource names
kubectl create role config-manager --verb=get,update --resource=configmaps --resource-name=my-config
```

### RoleBindings & ClusterRoleBindings
```bash
# Bind a Role to a User
kubectl create rolebinding dev-user-binding --role=developer --user=jane -n development

# Bind a ClusterRole to a User (Cluster-wide)
kubectl create clusterrolebinding admin-binding --clusterrole=admin --user=bob

# Bind a Role to a ServiceAccount
kubectl create rolebinding sa-binding --role=view --serviceaccount=default:my-sa -n production

# Bind a Role to a Group
kubectl create rolebinding group-binding --role=view --group=system:serviceaccounts:frontend -n frontend
```

---

## 🔍 2. View & Inspect Commands

### List RBAC Objects
```bash
# List all Roles in the current namespace
kubectl get roles

# List all ClusterRoles
kubectl get clusterroles

# List Bindings with more detail (shows the Role they point to)
kubectl get rolebindings -o wide
```

### Describe for Detail
```bash
# See the exact rules inside a Role
kubectl describe role developer

# See who is assigned to a ClusterRole
kubectl describe clusterrolebinding admin-binding
```

---

## 🛠️ 3. Modify & Delete Commands

### Edit Existing Objects
```bash
# Open the Role in your default editor
kubectl edit role developer -n development

# Patch a Role (useful for quick updates)
kubectl patch role developer -n development -p '{"rules": [...] }'
```

### Delete Objects
```bash
kubectl delete role developer -n development
kubectl delete clusterrolebinding admin-binding
```

---

## 🧪 4. Authorization Testing (`auth can-i`)
This is the **most important tool** for the CKA exam to verify your work.

### Check your own permissions
```bash
# Can I list pods in the current namespace?
kubectl auth can-i list pods
```

### Impersonate a User/ServiceAccount
```bash
# Can Jane list secrets in namespace 'prod'?
kubectl auth can-i list secrets --as jane -n prod

# Can the ServiceAccount 'pipeline' create deployments?
kubectl auth can-i create deployments --as system:serviceaccount:default:pipeline -n dev
```

### Check a specific resource instance
```bash
# Can I update the configmap named 'app-config'?
kubectl auth can-i update configmap/app-config
```

---

## 🍎 5. Helper Commands

### Find API Groups
If you don't know the `apiGroup` for a resource (needed for YAML), run:
```bash
kubectl api-resources
```
*Look at the `APIVERSION` column (e.g., `apps/v1` means the group is `apps`).*

### Reconcile (Advanced)
```bash
# Reconcile RBAC objects from a file (creates/updates as needed)
kubectl auth reconcile -f my-rbac.yaml
```

---

> [!TIP]
> **CKA Speed Hack**: Instead of writing a full `RoleBinding` YAML, always try `kubectl create rolebinding ...` first. If you need to add multiple subjects, you can output it to YAML and edit:
> `kubectl create rolebinding test --role=view --user=u1 --dry-run=client -o yaml > rb.yaml`
