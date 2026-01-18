# Multiple Schedulers in Kubernetes

Kubernetes allows you to run **multiple schedulers** simultaneously. This means you can have the default scheduler plus one or more custom schedulers, and different pods can choose which scheduler to use.

---

## 1. The "Restaurant Hosts" Analogy

Think of schedulers like different **hosts** at a restaurant:
*   **Default Scheduler**: The main host who seats most customers using standard rules.
*   **VIP Scheduler**: A special host who only seats VIP guests using custom criteria.
*   **Express Scheduler**: Another host who seats customers with special "quick service" needs.

Each pod can choose which "host" (scheduler) will seat it (place it on a node).

---

## 2. Why Use Multiple Schedulers?

### Common Use Cases

| Scenario | Why Custom Scheduler? |
| :--- | :--- |
| **GPU Workloads** | You need complex GPU affinity logic that the default scheduler doesn't handle well. |
| **Machine Learning** | Custom placement based on model size, training phases, or data locality. |
| **High-Performance Computing** | Specialized scheduling for tightly-coupled parallel jobs. |
| **Multi-Tenancy** | Different scheduling policies for different teams/tenants. |
| **Legacy Applications** | Applications that need specific node selection logic. |

---

## 3. How It Works

### The Default Scheduler

Every Kubernetes cluster starts with one scheduler:
*   **Name**: `default-scheduler`
*   **Runs as**: A static pod in the `kube-system` namespace
*   **Manifest**: `/etc/kubernetes/manifests/kube-scheduler.yaml` (on master node)

### Adding a Custom Scheduler

You can deploy additional schedulers as:
1.  **Deployment** (Recommended): Regular deployment in any namespace
2.  **Static Pod**: Another static pod on the master node
3.  **External Process**: Running outside the cluster

---

## 4. Deploying a Custom Scheduler

### Step 1: Create the Custom Scheduler Deployment

```yaml
# custom-scheduler.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-scheduler
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: my-scheduler-as-kube-scheduler
subjects:
- kind: ServiceAccount
  name: my-scheduler
  namespace: kube-system
roleRef:
  kind: ClusterRole
  name: system:kube-scheduler
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-scheduler
  namespace: kube-system
spec:
  replicas: 1
  selector:
    matchLabels:
      component: my-scheduler
  template:
    metadata:
      labels:
        component: my-scheduler
    spec:
      serviceAccountName: my-scheduler
      containers:
      - name: my-scheduler
        image: registry.k8s.io/kube-scheduler:v1.28.0
        command:
        - kube-scheduler
        - --authentication-kubeconfig=/etc/kubernetes/scheduler.conf
        - --authorization-kubeconfig=/etc/kubernetes/scheduler.conf
        - --kubeconfig=/etc/kubernetes/scheduler.conf
        - --leader-elect=false
        - --scheduler-name=my-custom-scheduler
        volumeMounts:
        - name: config
          mountPath: /etc/kubernetes
          readOnly: true
      volumes:
      - name: config
        hostPath:
          path: /etc/kubernetes
```

!!! warning "Critical Flags"
    - **`--scheduler-name=my-custom-scheduler`**: This is the unique name pods will use to select this scheduler.
    - **`--leader-elect=false`**: Disables leader election (only needed for HA setups with multiple replicas).

### Step 2: Apply the Deployment

```bash
kubectl apply -f custom-scheduler.yaml
```

### Step 3: Verify It's Running

```bash
# Check deployment
kubectl get deploy -n kube-system my-scheduler

# Check the pod logs
kubectl logs -n kube-system -l component=my-scheduler
```

---

## 5. Using a Custom Scheduler in Pods

### The `schedulerName` Field

To tell a pod to use a specific scheduler, add the `schedulerName` field in the pod spec.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: gpu-workload
spec:
  schedulerName: my-custom-scheduler  # <--- Use custom scheduler
  containers:
  - name: gpu-app
    image: nvidia/cuda:11.0-base
```

### Default Behavior

If you **don't** specify `schedulerName`, the pod uses the **default scheduler**:
```yaml
spec:
  schedulerName: default-scheduler  # This is implicit
```

---

## 6. Checking Which Scheduler Scheduled a Pod

### Method 1: Check the Pod YAML

```bash
kubectl get pod <pod-name> -o yaml | grep schedulerName
```

**Output:**
```yaml
schedulerName: my-custom-scheduler
```

### Method 2: Custom Columns View

```bash
kubectl get pods -o custom-columns="NAME:.metadata.name,SCHEDULER:.spec.schedulerName"
```

**Output:**
```
NAME              SCHEDULER
nginx-default     default-scheduler
gpu-workload      my-custom-scheduler
web-app           default-scheduler
```

### Method 3: Check Events

```bash
kubectl describe pod <pod-name> | grep -i scheduled
```

**Output:**
```
Successfully assigned default/gpu-workload to node01 by my-custom-scheduler
```

---

## 7. Real-World Example: GPU Scheduler

### Scenario
You have a cluster with:
*   **3 nodes**: 1 has GPUs, 2 are CPU-only
*   **Default scheduler**: Doesn't understand GPU requirements well
*   **Custom GPU scheduler**: Has logic to prefer GPU nodes

### Step 1: Deploy Custom Scheduler
```bash
kubectl apply -f gpu-scheduler.yaml
```

### Step 2: Deploy GPU Workload
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: ml-training
spec:
  schedulerName: gpu-scheduler  # Uses custom logic
  containers:
  - name: trainer
    image: tensorflow/tensorflow:latest-gpu
    resources:
      limits:
        nvidia.com/gpu: 1
```

### Step 3: Verify Placement
```bash
kubectl get pod ml-training -o wide
```

**Output:**
```
NAME          READY   STATUS    SCHEDULER         NODE
ml-training   1/1     Running   gpu-scheduler     gpu-node1
```

---

## 8. Multiple Schedulers in the Same Cluster

You can have **as many schedulers as you want** running simultaneously:

```
Cluster State:
┌──────────────────────────────┐
│ kube-system namespace        │
│                              │
│ 1. default-scheduler (Pod)  │───▶ Most pods
│ 2. gpu-scheduler (Deploy)   │───▶ ML workloads
│ 3. batch-scheduler (Deploy) │───▶ Batch jobs
└──────────────────────────────┘
```

Each pod independently chooses which one to use via `schedulerName`.

---

## 9. Common Issues and Troubleshooting

### Issue 1: Pod Stuck in Pending

**Symptom:**
```bash
kubectl get pod my-pod
# NAME     READY   STATUS    RESTARTS   AGE
# my-pod   0/1     Pending   0          5m
```

**Possible Causes:**
1.  **Typo in schedulerName**: The scheduler doesn't exist.
2.  **Scheduler is down**: The custom scheduler pod crashed.
3.  **RBAC issues**: Scheduler doesn't have permissions.

**Check:**
```bash
# Verify scheduler is running
kubectl get pods -n kube-system -l component=my-scheduler

# Check pod events
kubectl describe pod my-pod
```

**Look for:**
```
Warning  FailedScheduling  default-scheduler  0/3 nodes are available: 
         No scheduler found with name: my-custom-scheduler
```

### Issue 2: Wrong Scheduler Name

**Problem:**
```yaml
spec:
  schedulerName: my-costom-scheduler  # Typo: "costom" instead of "custom"
```

**Solution:**
```bash
# Delete and recreate (pods are immutable for schedulerName)
kubectl delete pod my-pod
```

```yaml
spec:
  schedulerName: my-custom-scheduler  # Fixed
```

### Issue 3: Scheduler Pod Not Scheduling Pods

**Check scheduler logs:**
```bash
kubectl logs -n kube-system -l component=my-scheduler
```

**Common log errors:**
```
Failed to get leases.coordination.k8s.io "my-scheduler" is forbidden
```

**Solution**: Fix RBAC permissions (see deployment YAML above).

---

## 10. CKA Exam Tips

### Task: "Create a pod that uses a custom scheduler"

**Workflow:**

```bash
# Step 1: Generate pod YAML
kubectl run nginx --image=nginx --dry-run=client -o yaml > pod.yaml

# Step 2: Edit to add schedulerName
vim pod.yaml
```

Add under `spec:`:
```yaml
  schedulerName: my-custom-scheduler
```

```bash
# Step 3: Apply
kubectl apply -f pod.yaml
```

### Task: "Identify which scheduler scheduled a pod"

```bash
kubectl get pod <name> -o jsonpath='{.spec.schedulerName}'
```

### Task: "Check if a custom scheduler is running"

```bash
kubectl get pods -n kube-system -l component=<scheduler-name>
```

---

## 11. Key Differences: Scheduler vs PriorityClass

Students often confuse these concepts:

| Concept | Purpose | Field |
| :--- | :--- | :--- |
| **Scheduler** | **WHO** makes the scheduling decision | `schedulerName: my-scheduler` |
| **PriorityClass** | **HOW IMPORTANT** the pod is | `priorityClassName: high-priority` |

**You can combine both:**
```yaml
spec:
  schedulerName: gpu-scheduler      # Custom logic
  priorityClassName: critical-tier  # High importance
```

---

## 12. Quick Reference Commands

```bash
# List all pods and their schedulers
kubectl get pods -A -o custom-columns="NAME:.metadata.name,SCHEDULER:.spec.schedulerName"

# Check which scheduler scheduled a specific pod
kubectl get pod <name> -o jsonpath='{.spec.schedulerName}'

# Verify custom scheduler is running
kubectl get deploy -n kube-system <scheduler-name>

# Check scheduler pod logs
kubectl logs -n kube-system -l component=<scheduler-name>

# Describe pod to see scheduling events
kubectl describe pod <name> | grep -A 5 Events
```

---

## Summary

!!! success "Key Takeaways"
    ✅ Kubernetes supports **multiple schedulers** running simultaneously  
    ✅ Pods select a scheduler via `spec.schedulerName`  
    ✅ Default scheduler name is `default-scheduler`  
    ✅ Custom schedulers need **RBAC permissions**  
    ✅ Each scheduler must have a **unique name**  
    ✅ If `schedulerName` is wrong or scheduler is down, pod stays **Pending**  
    ✅ Use `kubectl get pod <name> -o yaml | grep schedulerName` to check which scheduler was used  

### When to Use Multiple Schedulers

- ✅ **Specialized workloads** (GPU, HPC, ML)
- ✅ **Multi-tenancy** with different policies per tenant
- ✅ **Legacy apps** with unique placement needs
- ❌ **NOT for basic priority** (use PriorityClasses instead)
- ❌ **NOT for node selection** (use nodeSelector/affinity instead)
