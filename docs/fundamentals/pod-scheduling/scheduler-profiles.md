# Scheduler Profiles in Kubernetes

**Scheduler Profiles** allow you to configure different scheduling behaviors within a **single scheduler instance**, rather than deploying multiple separate schedulers.

---

## 1. The "Restaurant with Multiple Sections" Analogy

Think of scheduler profiles like a **restaurant with different sections**:

**Without Profiles (Multiple Schedulers):**
```
Restaurant A: Fine dining (slow, careful seating)
Restaurant B: Fast food (quick seating)
Restaurant C: VIP section (special rules)

Each has a separate manager (scheduler process).
```

**With Profiles (Single Scheduler):**
```
One Restaurant, One Manager, Three Sections:
  - Section 1: Fine dining rules
  - Section 2: Fast food rules  
  - Section 3: VIP rules

Same manager handles all sections with different rule books.
```

---

## 2. What are Scheduler Profiles?

A **Scheduler Profile** is a named configuration within the Kubernetes scheduler that defines which **plugins** to enable and how they should behave during the scheduling process.

### Key Concepts:
*   **One scheduler binary** can have multiple profiles
*   Each profile has a **unique name**
*   Pods select a profile via `spec.schedulerName`
*   Profiles share the same process but use different **plugin configurations**

---

## 3. Why Use Scheduler Profiles?

### Problem with Multiple Schedulers

**Resource Overhead:**
```
3 Custom Schedulers = 3 Separate Processes
  - my-scheduler-1:  ~100MB RAM
  - my-scheduler-2:  ~100MB RAM
  - my-scheduler-3:  ~100MB RAM
  Total: ~300MB RAM
```

**With Profiles:**
```
1 Scheduler with 3 Profiles = 1 Process
  - default-scheduler (3 profiles): ~120MB RAM
  Total: ~120MB RAM ✅ Much more efficient!
```

### Benefits

| Benefit | Explanation |
| :--- | :--- |
| **Resource Efficient** | Single process vs multiple scheduler pods |
| **Easier Management** | One deployment to configure and monitor |
| **Shared Cache** | All profiles share the same cluster state cache |
| **Simpler RBAC** | One ServiceAccount instead of many |

---

## 4. The Scheduling Framework (Plugins)

The Kubernetes scheduler uses a **plugin architecture** with different extension points:

### Scheduling Cycle

```
Pod → Queue Sort → PreFilter → Filter → PostFilter → PreScore → Score → Reserve → Permit → Bind
         ↓           ↓          ↓         ↓           ↓        ↓       ↓        ↓       ↓
      [Plugins]  [Plugins]  [Plugins]  [Plugins]   [Plugins][Plugins][Plugins][Plugins][Plugins]
```

### Built-in Plugins

| Plugin | Extension Point | What It Does |
| :--- | :--- | :--- |
| **NodeResourcesFit** | Filter | Checks if node has enough CPU/RAM |
| **NodeResourcesBalancedAllocation** | Score | Prefers nodes with balanced resource usage |
| **ImageLocality** | Score | Prefers nodes that already have the container image |
| **TaintToleration** | Filter | Enforces taint/toleration rules |
| **NodeAffinity** | Filter | Enforces node affinity rules |
| **PodTopologySpread** | PreFilter, Filter | Spreads pods across topology domains |
| **VolumeBinding** | PreFilter, Filter | Checks volume availability |
| **InterPodAffinity** | PreFilter, Filter, Score | Pod-to-pod affinity/anti-affinity |

---

## 5. Built-in Scheduler Profiles

Kubernetes 1.23+ comes with **two default profiles**:

### Profile 1: `default-scheduler` (Balanced)

**Purpose:** General-purpose scheduling for most workloads

**Enabled Plugins:**
- NodeResourcesFit (CPU/RAM check)
- NodeResourcesBalancedAllocation (spread load evenly)
- ImageLocality (prefer nodes with cached images)
- TaintToleration
- NodeAffinity
- PodTopologySpread
- InterPodAffinity

**Use for:** 99% of your workloads

### Profile 2: `bin-packing-scheduler` (Experimental)

**Purpose:** Pack pods densely to minimize the number of nodes used

**Difference:** Uses **NodeResourcesMostAllocated** instead of **BalancedAllocation**

**Effect:**
- Tries to fill up nodes completely before moving to next node
- Good for cost optimization (fewer nodes)
- Bad for high availability (all eggs in few baskets)

---

## 6. Configuring Scheduler Profiles

### KubeSchedulerConfiguration

Profiles are configured via the `KubeSchedulerConfiguration` file.

**Example: Adding a custom profile**

```yaml
# scheduler-config.yaml
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
profiles:
  # Profile 1: Default balanced scheduling
  - schedulerName: default-scheduler
    plugins:
      score:
        enabled:
        - name: NodeResourcesBalancedAllocation
          weight: 1
        - name: ImageLocality
          weight: 1
  
  # Profile 2: GPU-optimized scheduling
  - schedulerName: gpu-scheduler
    plugins:
      filter:
        enabled:
        - name: NodeResourcesFit
        - name: TaintToleration
      score:
        enabled:
        - name: NodeResourcesFit
          weight: 10  # Strongly prefer nodes with resources
        disabled:
        - name: ImageLocality  # Don't care about image locality
  
  # Profile 3: High-density bin packing
  - schedulerName: bin-packing
    plugins:
      score:
        enabled:
        - name: NodeResourcesMostAllocated
          weight: 1
        disabled:
        - name: NodeResourcesBalancedAllocation
```

### Applying the Configuration

**Step 1: Create the ConfigMap**
```bash
kubectl create configmap scheduler-config \
  --from-file=scheduler-config.yaml \
  -n kube-system
```

**Step 2: Update the scheduler manifest**

Edit `/etc/kubernetes/manifests/kube-scheduler.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: kube-scheduler
  namespace: kube-system
spec:
  containers:
  - name: kube-scheduler
    image: registry.k8s.io/kube-scheduler:v1.28.0
    command:
    - kube-scheduler
    - --config=/etc/kubernetes/scheduler-config.yaml  # <--- Add this
    volumeMounts:
    - name: scheduler-config
      mountPath: /etc/kubernetes/scheduler-config.yaml
      readOnly: true
  volumes:
  - name: scheduler-config
    configMap:
      name: scheduler-config
```

**Step 3: Wait for scheduler to restart**

The kubelet will automatically restart the scheduler pod with the new config.

---

## 7. Using Scheduler Profiles in Pods

### Select a Profile

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: gpu-workload
spec:
  schedulerName: gpu-scheduler  # <--- Same as profile name
  containers:
  - name: trainer
    image: tensorflow/tensorflow:latest-gpu
```

### Default Profile

If you don't specify `schedulerName`, it uses the first profile (usually `default-scheduler`):

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-app
spec:
  # schedulerName: default-scheduler  # Implicit
  containers:
  - name: nginx
    image: nginx
```

---

## 8. Real-World Example: Multi-Tenant Cluster

### Scenario

You have one cluster serving three teams:
1. **ML Team**: Needs GPU-aware scheduling
2. **Web Team**: Needs balanced scheduling
3. **Batch Team**: Wants dense packing to save costs

### Solution: Three Profiles

```yaml
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
profiles:
  # Default for Web Team
  - schedulerName: default-scheduler
    plugins:
      score:
        enabled:
        - name: NodeResourcesBalancedAllocation
  
  # GPU-optimized for ML Team
  - schedulerName: ml-scheduler
    plugins:
      score:
        enabled:
        - name: NodeResourcesFit
          weight: 10
        - name: NodeAffinity
          weight: 5
  
  # Bin-packing for Batch Team
  - schedulerName: batch-scheduler
    plugins:
      score:
        enabled:
        - name: NodeResourcesMostAllocated
          weight: 1
```

### Team Usage

**ML Team:**
```yaml
spec:
  schedulerName: ml-scheduler
  containers:
  - name: training
    image: pytorch/pytorch
    resources:
      limits:
        nvidia.com/gpu: 2
```

**Web Team:**
```yaml
spec:
  # Uses default-scheduler (implicit)
  containers:
  - name: web
    image: nginx
```

**Batch Team:**
```yaml
spec:
  schedulerName: batch-scheduler
  containers:
  - name: job
    image: busybox
```

---

## 9. Scheduler Profiles vs Multiple Schedulers

| Aspect | Scheduler Profiles | Multiple Schedulers |
| :--- | :--- | :--- |
| **Processes** | 1 scheduler, N profiles | N separate scheduler processes |
| **Memory** | ~120MB total | ~100MB × N |
| **Configuration** | One config file | N config files |
| **RBAC** | One ServiceAccount | N ServiceAccounts |
| **Cluster Cache** | Shared | Separate caches |
| **Complexity** | Lower | Higher |
| **Isolation** | Shared process | Separate processes |
| **Use Case** | Different plugin configs | Completely different scheduling logic |

### When to Use Which?

**Use Scheduler Profiles when:**
- ✅ You need different plugin configurations
- ✅ You want resource efficiency
- ✅ You're running on Kubernetes 1.23+

**Use Multiple Schedulers when:**
- ✅ You need completely custom scheduling algorithms
- ✅ You're using third-party schedulers (e.g., Volcano, Kube-batch)
- ✅ You need strong process isolation

---

## 10. Checking Active Profiles

### View Scheduler Configuration

```bash
# Get the scheduler pod
kubectl get pod -n kube-system -l component=kube-scheduler

# Check logs for loaded profiles
kubectl logs -n kube-system kube-scheduler-<node-name> | grep -i profile
```

**Output:**
```
Registered scheduling profiles: default-scheduler, gpu-scheduler, batch-scheduler
```

### Check Which Profile Scheduled a Pod

```bash
kubectl get pod <pod-name> -o jsonpath='{.spec.schedulerName}'
```

**Custom columns view:**
```bash
kubectl get pods -A -o custom-columns=\
"NAME:.metadata.name,\
NAMESPACE:.metadata.namespace,\
SCHEDULER:.spec.schedulerName,\
NODE:.spec.nodeName"
```

---

## 11. Common Pitfalls

### Issue 1: Profile Name Typo

**Problem:**
```yaml
spec:
  schedulerName: gpu-schedular  # Typo: "schedular" instead of "scheduler"
```

**Result:** Pod stays `Pending` forever

**Check:**
```bash
kubectl describe pod <name>
# Events:
#   Warning  FailedScheduling  No scheduler named "gpu-schedular" found
```

### Issue 2: Scheduler Not Restarted After Config Change

**Problem:** Updated `scheduler-config.yaml` but scheduler didn't reload

**Solution:**
```bash
# For static pod, edit the manifest to force restart
# Or delete the scheduler pod
kubectl delete pod -n kube-system kube-scheduler-<node-name>
```

### Issue 3: Conflicting Plugin Configs

**Problem:**
```yaml
plugins:
  score:
    enabled:
    - name: NodeResourcesBalancedAllocation
    - name: NodeResourcesMostAllocated  # Conflicts with above!
```

**Solution:** Use one OR the other, not both

---

## 12. CKA Exam Relevance

### Exam Tasks

**Task: "Configure a scheduler with two profiles"**

Not commonly tested directly, but you should know:
1. Profiles live in `KubeSchedulerConfiguration`
2. Pods select profiles via `schedulerName`
3. How to check which profile scheduled a pod

**More Common: "Create a pod using a specific scheduler"**

```bash
# Step 1: Generate pod
kubectl run app --image=nginx --dry-run=client -o yaml > pod.yaml

# Step 2: Edit to add schedulerName
vim pod.yaml
```

Add:
```yaml
spec:
  schedulerName: my-scheduler
```

```bash
# Step 3: Apply
kubectl apply -f pod.yaml
```

---

## 13. Quick Reference

### Pod Selection

```yaml
spec:
  schedulerName: <profile-name>
```

### Check Profile

```bash
# Which scheduler/profile was used?
kubectl get pod <name> -o jsonpath='{.spec.schedulerName}'

# View scheduler logs
kubectl logs -n kube-system kube-scheduler-<node>
```

### Common Profile Names

| Profile | Purpose |
| :--- | :--- |
| `default-scheduler` | Standard balanced scheduling |
| `bin-packing` | Dense node packing |
| Custom names | Your configured profiles |

---

## Summary

!!! success "Key Takeaways"
    ✅ Scheduler Profiles = **Multiple scheduling behaviors in ONE scheduler process**  
    ✅ More efficient than running multiple separate schedulers  
    ✅ Configured via **KubeSchedulerConfiguration**  
    ✅ Pods select a profile using `spec.schedulerName`  
    ✅ Each profile can enable/disable different **plugins**  
    ✅ Built-in profiles: `default-scheduler` (balanced), `bin-packing` (dense)  
    ✅ Use profiles for **different plugin configs**, use multiple schedulers for **custom algorithms**  
    ✅ Profiles share the same cluster state cache (efficiency!)  

### When to Use Scheduler Profiles

- ✅ Need different scoring/filtering logic
- ✅ Want resource efficiency (one process)
- ✅ Running Kubernetes 1.23+
- ✅ Multi-tenant scenarios with different scheduling needs
- ❌ Don't use if you need completely custom scheduling logic (use multiple schedulers instead)
