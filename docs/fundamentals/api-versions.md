# Kubernetes API Versions Guide

Understanding `apiVersion` is critical for writing correct Kubernetes manifests. This guide explains why some resources use `v1` while others use `apps/v1`, `batch/v1`, etc.

---

## The History (Why the Split?)

### The "Core" API (v1)
When Kubernetes was first created, everything was in the **core API** (`v1`). These are the "original" resources that form the foundation of Kubernetes:
*   Pod
*   Service
*   ConfigMap
*   Secret
*   Namespace
*   PersistentVolume
*   PersistentVolumeClaim

**Why `v1`?** These are so fundamental that they don't need a group name. They're just "version 1 of the core API."

### The "Apps" API (apps/v1)
As Kubernetes evolved, they needed to add **new resource types** without breaking the core API. So they created **API Groups**.

*   Deployment
*   ReplicaSet
*   StatefulSet
*   DaemonSet

**Why `apps/v1`?** These are all related to **application workloads**, so they were grouped together in the `apps` API group.

---

## API Version Format

The format is: `<group>/<version>`

*   **No group** = Core API → Just `v1`
*   **With group** = Named API → `apps/v1`, `batch/v1`, etc.

**Examples:**
```yaml
apiVersion: v1              # Core API (no group)
kind: Pod

apiVersion: apps/v1         # Apps API group
kind: Deployment

apiVersion: batch/v1        # Batch API group
kind: Job
```

---

## Complete API Version Reference

| Resource | API Version | API Group | Category |
| :--- | :--- | :--- | :--- |
| **Pod** | `v1` | (core) | Workload |
| **Service** | `v1` | (core) | Networking |
| **ConfigMap** | `v1` | (core) | Configuration |
| **Secret** | `v1` | (core) | Configuration |
| **Namespace** | `v1` | (core) | Organization |
| **PersistentVolume** | `v1` | (core) | Storage |
| **PersistentVolumeClaim** | `v1` | (core) | Storage |
| **Node** | `v1` | (core) | Cluster |
| **ServiceAccount** | `v1` | (core) | Security |
| **Endpoints** | `v1` | (core) | Networking |
| **Event** | `v1` | (core) | Monitoring |
| **LimitRange** | `v1` | (core) | Resource Management |
| **ResourceQuota** | `v1` | (core) | Resource Management |
| **Deployment** | `apps/v1` | apps | Workload |
| **ReplicaSet** | `apps/v1` | apps | Workload |
| **StatefulSet** | `apps/v1` | apps | Workload |
| **DaemonSet** | `apps/v1` | apps | Workload |
| **Job** | `batch/v1` | batch | Workload |
| **CronJob** | `batch/v1` | batch | Workload |
| **Ingress** | `networking.k8s.io/v1` | networking | Networking |
| **NetworkPolicy** | `networking.k8s.io/v1` | networking | Security |
| **IngressClass** | `networking.k8s.io/v1` | networking | Networking |
| **Role** | `rbac.authorization.k8s.io/v1` | rbac | Security |
| **RoleBinding** | `rbac.authorization.k8s.io/v1` | rbac | Security |
| **ClusterRole** | `rbac.authorization.k8s.io/v1` | rbac | Security |
| **ClusterRoleBinding** | `rbac.authorization.k8s.io/v1` | rbac | Security |
| **HorizontalPodAutoscaler** | `autoscaling/v2` | autoscaling | Scaling |
| **VerticalPodAutoscaler** | `autoscaling.k8s.io/v1` | autoscaling | Scaling |
| **PodDisruptionBudget** | `policy/v1` | policy | Availability |
| **StorageClass** | `storage.k8s.io/v1` | storage | Storage |
| **VolumeAttachment** | `storage.k8s.io/v1` | storage | Storage |
| **CSIDriver** | `storage.k8s.io/v1` | storage | Storage |
| **PriorityClass** | `scheduling.k8s.io/v1` | scheduling | Scheduling |
| **CustomResourceDefinition** | `apiextensions.k8s.io/v1` | apiextensions | Extension |

---

## Why This Matters

### 1. Evolution Without Breaking Changes
By using API groups, Kubernetes can:
*   Add new features to `apps/v2` without breaking `apps/v1`
*   Deprecate old versions gradually
*   Keep the core API stable

**Example:**
```yaml
# Old version (deprecated)
apiVersion: extensions/v1beta1
kind: Deployment

# Current version (stable)
apiVersion: apps/v1
kind: Deployment
```

### 2. Organization by Purpose
Resources are grouped by **functionality**:
*   `apps/*` → Application workloads (Deployments, StatefulSets)
*   `batch/*` → Batch processing (Jobs, CronJobs)
*   `networking.k8s.io/*` → Networking (Ingress, NetworkPolicy)
*   `rbac.authorization.k8s.io/*` → Access control (Roles, RoleBindings)

### 3. Custom Resources
You can create your own API groups for **Custom Resource Definitions (CRDs)**:
```yaml
apiVersion: mycompany.com/v1
kind: MyCustomResource
```

---

## Common Patterns

### Core API (v1)
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
spec:
  containers:
  - name: nginx
    image: nginx
---
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  selector:
    app: myapp
  ports:
  - port: 80
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-config
data:
  key: value
```

### Apps API (apps/v1)
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: nginx
        image: nginx
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: my-statefulset
spec:
  serviceName: "my-service"
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: nginx
        image: nginx
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: my-daemonset
spec:
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: nginx
        image: nginx
```

### Batch API (batch/v1)
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: my-job
spec:
  template:
    spec:
      containers:
      - name: busybox
        image: busybox
        command: ["echo", "Hello World"]
      restartPolicy: Never
---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: my-cronjob
spec:
  schedule: "*/5 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: busybox
            image: busybox
            command: ["echo", "Hello World"]
          restartPolicy: OnFailure
```

### Networking API
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-ingress
spec:
  rules:
  - host: example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-service
            port:
              number: 80
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: my-network-policy
spec:
  podSelector:
    matchLabels:
      app: myapp
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          role: frontend
```

### RBAC API
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
subjects:
- kind: User
  name: jane
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

---

## How to Find the Right API Version

### Method 1: kubectl explain
The fastest way to find the correct API version:

```bash
kubectl explain deployment
# Output: 
# VERSION: apps/v1
# KIND:    Deployment

kubectl explain pod
# Output:
# VERSION: v1
# KIND:    Pod

kubectl explain ingress
# Output:
# VERSION: networking.k8s.io/v1
# KIND:    Ingress
```

### Method 2: kubectl api-resources
List all available resources and their API versions:

```bash
kubectl api-resources | grep deployment
# Output: deployments   deploy   apps/v1   true   Deployment

kubectl api-resources | grep pod
# Output: pods   po   v1   true   Pod

kubectl api-resources | grep ingress
# Output: ingresses   ing   networking.k8s.io/v1   true   Ingress
```

### Method 3: kubectl api-versions
List all available API versions in your cluster:

```bash
kubectl api-versions
# Output:
# admissionregistration.k8s.io/v1
# apiextensions.k8s.io/v1
# apiregistration.k8s.io/v1
# apps/v1
# authentication.k8s.io/v1
# authorization.k8s.io/v1
# autoscaling/v1
# autoscaling/v2
# batch/v1
# certificates.k8s.io/v1
# coordination.k8s.io/v1
# discovery.k8s.io/v1
# events.k8s.io/v1
# networking.k8s.io/v1
# node.k8s.io/v1
# policy/v1
# rbac.authorization.k8s.io/v1
# scheduling.k8s.io/v1
# storage.k8s.io/v1
# v1
```

---

## Version Stability Levels

Kubernetes uses version suffixes to indicate stability:

| Suffix | Meaning | Example | Stability |
| :--- | :--- | :--- | :--- |
| **v1** | Stable | `apps/v1` | Production-ready, won't change |
| **v1beta1** | Beta | `batch/v1beta1` | Feature-complete, may change slightly |
| **v1alpha1** | Alpha | `autoscaling/v1alpha1` | Experimental, may change significantly |

**CKA Tip:** Always use **stable** (`v1`) versions in the exam unless specifically asked to use beta/alpha.

---

## Common Mistakes

### Mistake 1: Using the wrong API version
```yaml
# WRONG (old, deprecated)
apiVersion: extensions/v1beta1
kind: Deployment

# CORRECT (current, stable)
apiVersion: apps/v1
kind: Deployment
```

### Mistake 2: Forgetting the API group
```yaml
# WRONG (missing "apps/")
apiVersion: v1
kind: Deployment

# CORRECT
apiVersion: apps/v1
kind: Deployment
```

### Mistake 3: Using beta versions in production
```yaml
# RISKY (beta version may change)
apiVersion: batch/v1beta1
kind: CronJob

# BETTER (stable version)
apiVersion: batch/v1
kind: CronJob
```

---

## Summary

**Simple Rule:**
*   **Old, fundamental resources** → `v1` (no group)
*   **Everything else** → `<group>/v1` (with group)

**Why the split?**
Kubernetes needed to **grow** without **breaking** existing resources.

**How to remember:**
*   If it's a **basic building block** (Pod, Service, ConfigMap) → `v1`
*   If it's a **higher-level abstraction** (Deployment, Job, Ingress) → `<group>/v1`

**Pro Tip:** When in doubt, use `kubectl explain <resource>` to find the correct API version!
