# Real-World Case Study: EMR on EKS Auth (RBAC + OIDC)

When running **Amazon EMR on EKS**, you navigate a three-way intersection of **IAM Roles**, **OIDC Authentication**, and **Kubernetes RBAC**. This is a perfect example of how ClusterRoles manage infrastructure while Roles manage the data jobs.

---

## 🏗️ 1. The "Trust" Architecture (OIDC)

Kubernetes itself doesn't know about AWS IAM. To bridge this gap, we use **IRSA (IAM Roles for Service Accounts)**.

1.  **OIDC Provider**: Each EKS cluster has a unique OIDC Identity Provider (IdP).
2.  **ServiceAccount**: You create a standard Kubernetes ServiceAccount and **annotate** it with the IAM Role ARN.
3.  **Trust Policy**: The IAM Role has a policy that says: *"I trust the EKS OIDC provider, but only for requests coming from this specific ServiceAccount."*

---

## ⚡ 2. Role vs. ClusterRole in EMR

In EMR on EKS, permissions are split between the **EMR Service itself** and the **Spark Job**.

### A. The EMR Service Role (ClusterRole)
The EMR service needs to manage resources across the entire cluster (like creating Namespaces or viewing Nodes). This requires a **ClusterRole**.

**Common ClusterRole permissions for EMR:**
*   `nodes`: (get, list) to see where to place pods.
*   `namespaces`: (get, list, create) to manage virtual clusters.
*   `certificatesigningrequests`: (create, get) if using internal TLS.

### B. The Job Execution Role (Role)
The Spark Pod (Driver/Executor) is usually locked into a single namespace. It only needs a namespaced **Role**.

**Example Job Role YAML:**
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: emr-spark-job-role
  namespace: spark-jobs
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps"]
  verbs: ["get", "list", "watch", "create", "delete"]
```

---

## 🔗 3. Putting it Together: The ServiceAccount

This is the "Glue" that connects your RBAC to your AWS IAM.

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: emr-execution-sa
  namespace: spark-jobs
  annotations:
    # This connects the SA to the AWS IAM Role!
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/EMRJobExecutionRole
```

---

## 🛠️ 4. Essential Troubleshooting for EMR on EKS

### 1. Check the Webhook
If your Pods are not getting AWS credentials, check if the EKS Pod Identity Webhook is working:
```bash
kubectl get pods -n kube-system | grep pod-identity-webhook
```

### 2. Verify the Token
When OIDC is working, the webhook injects a token into the pod. You can see it by describing a Spark pod:
```bash
kubectl describe pod <spark-pod-name>
# Look for 'AWS_WEB_IDENTITY_TOKEN_FILE' in environment variables
```

### 3. RBAC "Permission Denied"
If EMR fails to start the job, it's often a missing **RoleBinding**.
*   **Fix**: Ensure your `RoleBinding` links the `emr-execution-sa` to the `emr-spark-job-role`.

---

> [!IMPORTANT]
> **Least Privilege**: In EMR on EKS, always prefer **Roles** over **ClusterRoles** for Spark jobs. A Spark job should NEVER have the power to view nodes or delete namespaces. Keep those permissions in a dedicated administrative `ClusterRole`.
