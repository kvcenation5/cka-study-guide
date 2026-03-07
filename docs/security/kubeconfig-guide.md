# Kubeconfig: Managing Cluster Access

A **kubeconfig** file is a YAML file that stores information about clusters, users, namespaces, and authentication mechanisms. It is how `kubectl` knows which cluster to talk to and who you are.

---

## 🏗️ 1. The Three Pillars of Kubeconfig

Every kubeconfig is built using three main sections:

### 1. Clusters
Contains the connection details for your clusters.
*   **Server**: The API Server URL (e.g., `https://192.168.1.10:6443`).
*   **Certificate Authority**: The `ca.crt` (or its base64 data) used to verify the cluster's identity.

### 2. Users
Contains your credentials.
*   **Client Certificate/Key**: Path to your `.crt` and `.key` files.
*   **Token**: A static or dynamic bearer token.
*   **Password**: Username/Password (rarely used now).

### 3. Contexts
The "Glue" that binds a **User** to a **Cluster**.
*   **Context Name**: A nickname (e.g., `prod-context`).
*   **Cluster**: Which cluster to use.
*   **User**: Which credentials to use.
*   **Namespace**: (Optional) The default namespace for this context.

---

## 📄 2. Kubeconfig YAML Example

Here is a complete example showing how these sections are structured in a single file:

```yaml
apiVersion: v1
kind: Config

# 1. Clusters Section
clusters:
- name: production-cluster
  cluster:
    server: https://10.0.0.10:6443
    certificate-authority: /etc/kubernetes/pki/ca.crt

# 2. Users Section
users:
- name: admin-user
  user:
    client-certificate: /etc/kubernetes/pki/admin.crt
    client-key: /etc/kubernetes/pki/admin.key

# 3. Contexts Section (The Mapping)
contexts:
- name: prod-admin-context
  context:
    cluster: production-cluster
    user: admin-user
    namespace: finance

# 4. Current Context (Setting the Default)
current-context: prod-admin-context
```

---

## 📂 2. File Location & Precedence

Kubernetes looks for configurations in this specific order:

1.  **`--kubeconfig` flag**: `kubectl get pods --kubeconfig=/path/to/custom-config`
2.  **`KUBECONFIG` env variable**: `export KUBECONFIG=$HOME/.kube/config:$HOME/.kube/dev-config` (Merges both!)
3.  **Default Location**: `$HOME/.kube/config`

---

## 🛠️ 3. Common kubectl Commands

### View Configuration
```bash
# View the current configuration (Warning: Shows secrets!)
kubectl config view

# View only the minified config for the current context
kubectl config view --minify
```

### Switch Contexts (The CKA Daily Routine)
```bash
# Get list of contexts
kubectl config get-contexts

# Identify current context
kubectl config current-context

# Switch to a different context
kubectl config use-context my-cluster-name
```

### Create/Modify Configs
```bash
# Set a new cluster entry
kubectl config set-cluster development --server=https://1.2.3.4:6443 --certificate-authority=/pki/ca.crt

# Set a new user with a token
kubectl config set-credentials developer --token=qwerty124

# Create a new context linking them
kubectl config set-context dev-context --cluster=development --user=developer --namespace=frontend
```

---

## 🔐 4. Base64 in Kubeconfig

In a standard `~/.kube/config`, you will often see `certificate-authority-data` or `client-key-data` instead of file paths. This is just the file content encoded in **Base64**.

**How to convert a file to Kubeconfig data:**
```bash
cat ca.crt | base64 | tr -d '\n'
```

---

## 🧪 5. CKA Exam Tip: Context Switching

In the CKA exam, you will be given multiple clusters. **EVERY QUESTION** will start with a command to switch contexts:

> "Task: Create a pod in cluster X. First, switch to context X: `kubectl config use-context cluster-x`"

**CRITICAL**: If you forget to run this, you will perform the task in the **wrong cluster** and get zero points for that question. Always check `kubectl config current-context` before starting a task.

---

> [!IMPORTANT]
> **Merge vs. Overwrite**: If you have two different config files, don't try to manually copy-paste them. Use the environment variable:
> `export KUBECONFIG=file1:file2`
> `kubectl config view --flatten > merged-config`
