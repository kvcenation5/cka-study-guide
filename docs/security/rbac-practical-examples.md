# Practical RBAC: Lab Examples & YAMLs

This guide provides hands-on, CKA-style examples for **Role-Based Access Control**. We will cover practical scenarios you are likely to encounter in the exam and real-world administration.

---

## 🛠️ Scenario 1: Developing in a Namespace
**Goal**: Allow a developer named `martin` to manage Pods and Deployments in the `development` namespace, but nothing else.

### 1a. Create the Role
Notice the `apiGroups`. `pods` are in `""` (core), while `deployments` are in `"apps"`.

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: development
  name: dev-manager
rules:
- apiGroups: [""]
  resources: ["pods", "services"]
  verbs: ["get", "list", "create", "update", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "create", "update", "patch"]
```

### 1b. Create the RoleBinding
This links the user `martin` to the `dev-manager` role inside the `development` namespace.

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: martin-dev-binding
  namespace: development
subjects:
- kind: User
  name: martin
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: dev-manager
  apiGroup: rbac.authorization.k8s.io
```

---

## 🏗️ Scenario 2: Cluster-Wide Monitoring
**Goal**: Create a service account for a Prometheus-like tool that needs to "list" every Pod in **every namespace**.

### 2a. Create the ClusterRole
Since we want this to apply to all namespaces, we use a `ClusterRole`.

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: global-viewer
rules:
- apiGroups: [""]
  resources: ["pods", "nodes", "namespaces"]
  verbs: ["get", "list", "watch"]
```

### 2b. Create the ClusterRoleBinding
We bind this to a **ServiceAccount** instead of a human user.

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: monitor-global-binding
subjects:
- kind: ServiceAccount
  name: monitoring-sa
  namespace: monitoring # The namespace where the SA lives
roleRef:
  kind: ClusterRole
  name: global-viewer
  apiGroup: rbac.authorization.k8s.io
```

---

## 📂 Scenario 3: Secret Security
**Goal**: Allow a specific support user to read `logs` of pods but **strictly prohibit** them from reading `secrets`.

### 3a. The Support Role
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: production
  name: support-logs
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list"]
```
*Note: In Kubernetes RBAC, everything is **denied by default**. Since we didn't include `secrets` in the list, the user is automatically prohibited from reading them.*

---

## 🧪 4. The CKA "Check-Your-Work" Workflow

In the exam, after creating these files, use the `auth can-i` tool to verify. This is the difference between a pass and a fail.

```bash
# 1. Check if Martin can create a deployment in development
kubectl auth can-i create deployments --as martin -n development
# Expected: yes

# 2. Check if Martin can create a pod in the 'default' namespace
kubectl auth can-i create pods --as martin -n default
# Expected: no (RoleBindings are namespace-scoped)

# 3. Check if the monitoring SA can see nodes
kubectl auth can-i list nodes --as system:serviceaccount:monitoring:monitoring-sa
# Expected: yes
```

---

## ⚡ Imperative Shortcut Table

If you are short on time (under 5 minutes left), use these commands instead of writing YAML:

| Task | Command |
| :--- | :--- |
| **Role** | `kubectl create role <name> --verb=get,list --resource=pods -n <ns>` |
| **ClusterRole** | `kubectl create clusterrole <name> --verb=get --resource=nodes` |
| **RoleBinding** | `kubectl create rolebinding <name> --role=<role> --user=<user> -n <ns>` |
| **Binding to SA** | `kubectl create rolebinding <name> --role=<role> --serviceaccount=<ns>:<sa>` |

---

> [!TIP]
> **Exam Strategy**: Always double-check the `apiGroups`. If you use `apiVersion: rbac.authorization.k8s.io/v1`, the `apiGroups` field in the rule is almost always `[""]` for core objects or `["apps"]` for workloads. Avoid leaving it blank (`[]`) as that often results in a "no permissions" error.
