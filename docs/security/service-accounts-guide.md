# ServiceAccounts: Identity for Pods

While **Users** are for humans, **ServiceAccounts** are the identity for processes running inside your Pods. They allow applications like monitoring agents or CI/CD tools to talk to the Kubernetes API securely.

---

## 🏗️ 1. Practical Use Cases

When does a Pod need an identity?
*   **Logging/Monitoring**: A `Prometheus` pod needs a ServiceAccount to discover other pods in the cluster via the API.
*   **CI/CD**: A `Jenkins` agent needs a ServiceAccount to create/update Deployments.
*   **Dashboards**: The Kubernetes Dashboard needs an identity to list and display cluster resources.
*   **Cloud Integration (IRSA)**: In EKS, a ServiceAccount is used to map a Pod to an AWS IAM Role.

---

## 🔗 2. Attaching a ServiceAccount to a Pod

By default, every namespace has a ServiceAccount named `default`. If you don't specify one, your Pod uses the `default` account (which usually has zero permissions).

### Step A: Create the ServiceAccount
```bash
kubectl create serviceaccount dashboard-sa
```

### Step B: Attach it in the Pod Spec
Use the `serviceAccountName` field in your YAML.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
spec:
  # This links the Pod to the identity
  serviceAccountName: dashboard-sa
  containers:
  - name: my-container
    image: nginx
```

---

## 🔐 3. Modern Token Management (Ephemeral Tokens)

Since Kubernetes **v1.22+**, the security model has changed. Instead of creating a permanent `Secret` for every ServiceAccount, Kubernetes now uses **Projected Volumes**.

### How it works:
1.  **Mounting**: The Kubelet automatically mounts a volume at `/var/run/secrets/kubernetes.io/serviceaccount/`.
2.  **Ephemeral Tokens**: The token inside this volume is generated specifically for **that Pod instance**.
3.  **Lifecycle**: The token is **Bound** to the pod. When the Pod is deleted, the token is automatically revoked by the API Server. It does not live on in a Secret on the disk.

---

## 🧪 4. How to see the Token at Runtime

If you want to see the actual JWT token the Pod is using to authenticate, you can peek inside the container.

### Step-by-Step Inspection:
1.  **Exec into the Pod**:
    ```bash
    kubectl exec <pod-name> -it -- sh
    ```

2.  **Read the Token file**:
    ```bash
    cat /var/run/secrets/kubernetes.io/serviceaccount/token
    ```
    *This will output a long Base64 string (the JWT).*

3.  **Verify the Namespace & CA**:
    In the same directory, you can also see the namespace the pod is in and the cluster's root certificate:
    ```bash
    ls /var/run/secrets/kubernetes.io/serviceaccount/
    # Output: ca.crt  namespace  token
    ```

---

## 🛡️ 5. Security: Controlling Token Auto-Mounting

By default, Kubernetes **always** mounts the ServiceAccount token into every Pod. If your application doesn't need to talk to the API, this is a security risk. You can disable this behavior in two places:

### Option A: At the ServiceAccount Level
Disables auto-mounting for **any Pod** that uses this ServiceAccount.
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: restricted-sa
automountServiceAccountToken: false
```

### Option B: At the Pod Level (Overrides SA)
Disables it for a single specific Pod, even if the ServiceAccount allows it.
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: standalone-app
spec:
  # This field tells K8s NOT to mount the token
  automountServiceAccountToken: false
  serviceAccountName: default
  containers:
  - name: secure-container
    image: nginx
```

---

## 🚩 6. CKA Exam Strategy

1.  **Don't look for Secrets**: In modern K8s, `kubectl get secrets` will likely NOT show a token for your new ServiceAccount. This is normal!
2.  **The YAML Field**: Remember it is `serviceAccountName`, NOT `serviceAccount`.
3.  **RBAC Link**: A ServiceAccount is useless without a **RoleBinding**. After creating the SA, you almost always need to bind it to a Role or ClusterRole:
    ```bash
    kubectl create rolebinding sa-view --role=view --serviceaccount=default:dashboard-sa
    ```
