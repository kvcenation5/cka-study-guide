# Pod Priority and Preemption

In a crowded Kubernetes cluster, not all Pods are equal. **PriorityClasses** allow you to tell the scheduler which Pods are the most important, ensuring they get scheduled even if the cluster is full.

---

## 1. The "VIP Seating" Analogy

Think of your cluster as a popular restaurant:
*   **Standard Pods**: Customers who show up and wait for a table.
*   **Priority Pods**: Customers with a VIP reservation.

If a VIP customer shows up and there are no tables, the manager (Scheduler) might ask a "Regular" customer to leave (Preemption) to make room for the VIP.

---

## 2. PriorityClass Object

A **PriorityClass** is a cluster-wide (non-namespaced) object that maps a name to a numeric value.

### Example YAML:
```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority-apps
value: 1000000
globalDefault: false
description: "This priority class should be used for critical service pods."
```

*   **`value`**: Higher numbers mean higher priority.
*   **`globalDefault`**: If set to `true`, any pod without a priority class will automatically get this one. (Only one PriorityClass can be the global default).

---

## 3. How to use it in a Pod

Once the PriorityClass is created, you simply reference its name in the Pod spec.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: critical-app
spec:
  containers:
  - name: nginx
    image: nginx
  priorityClassName: high-priority-apps    # <--- Reference here
```

---

## 4. Preemption (Survival of the Fittest)

When a Pod with high priority is in the `Pending` state, the scheduler tries to find a node for it. If no nodes have enough resources, the scheduler looks for lower-priority pods to **evict**.

### The Preemption Process:
1.  **High-priority Pod** enters the queue.
2.  **Scheduler** finds no nodes with enough CPU/RAM.
3.  **Scheduler** identifies a node where removing one or more lower-priority pods would create enough space.
4.  **Lower-priority Pods** are gracefully terminated.
5.  **High-priority Pod** is scheduled on that node.

### `preemptionPolicy`: To Kill or Not to Kill?

By default, high priority means the pod can **evict** others. However, you can change this behavior using the `preemptionPolicy` field:

1.  **`PreemptLowerPriority` (Default)**: If this pod is pending, the scheduler will kill lower-priority pods to make room.
2.  **`Never` (Non-Preempting)**: This pod will still be placed at the "front of the line" in the scheduling queue, but it **will not** kill any existing pods. It will wait until space naturally becomes available.

**Real-world use case for `Never`**: Batch jobs that are "nice to have" but shouldn't disrupt the live website. They get scheduled as soon as there's a gap, but they never kick anyone out.

```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: batch-workload-non-preempting
value: 500000
preemptionPolicy: Never    # <--- Won't evict other pods
globalDefault: false
```

### How `value` and `preemptionPolicy` Work Together

Think of this like a **Social Ladder**:
*   **`value` = Rank** (High number > Low number). It defines **who** is more important.
*   **`preemptionPolicy` = Permission**. It defines **how** that importance is enforced.

#### Scenario: The Node is Full
A new Pod with `value: 1000` arrives. The node is currently occupied by a Pod with `value: 500`.

| If the new Pod (1000) has... | Action it can take |
| :--- | :--- |
| **`PreemptLowerPriority`** | **The Comparison**: 1000 > 500. **The Policy**: Allowed to evict. **Result**: The 500-pod is killed, and the 1000-pod takes its place. |
| **`Never`** | **The Comparison**: 1000 > 500. **The Policy**: Refused permission. **Result**: The 1000-pod stays `Pending` until space opens up naturally. |

!!! warning "The Golden Rule of Preemption"
    A pod can **NEVER** preempt/kill a pod with an **equal or higher** priority value. You can only kick out those "below" you on the ladder.

---

## 5. The Priority Value Spectrum (Highest to Lowest)

Priority values are **32-bit integers**. The range is technically large, but Kubernetes reserves specific "neighborhoods" for different tiers of importance.

| Priority Tier | Value Range | Typical Use Case |
| :--- | :--- | :--- |
| **System Critical** | **2,000,000,001 to 2,147,483,647** | **Reserved.** Used for internal K8s components. |
| **System Node Critical**| **2,000,001,000** | Built-in: CNI, kube-proxy. |
| **System Cluster Critical**| **2,000,000,000** | Built-in: CoreDNS, API Server. |
| **User Critical** | **1,000,000 to 1,000,000,000** | Your most important PROD apps (Databases, Gateways). |
| **Standard Apps** | **1,000 to 999,999** | Regular web servers, APIs. |
| **Default Priority** | **0** | The baseline for every pod if no class is defined. |
| **Best Effort / Batch** | **Negative Numbers** | Low-priority background jobs, analytics, or research. |

### The "Danger Zone" (> 1 Billion)
You should **not** create your own priority classes with values greater than 1 billion unless you strictly want to compete with the Kubernetes system components. If your app evicts `kube-proxy`, your node's networking will break!

### Logic for Choosing Numbers:
*   **Production vs staging**: Give Prod a higher range (e.g., 10,000+) and Staging a lower range (e.g., 5,000).
*   **Leave Gaps**: Don't use 1, 2, 3. Use 1000, 2000, 3000. This allows you to "squeeze" a new level in between later without having to update all your YAML files.

## 6. Pro Tip: Group by Tiers, not Pod-by-Pod

A common mistake is trying to give every single application pod its own unique priority number (e.g., `1001`, `1002`, `1003`). 

**Why you shouldn't do this:**
1.  **Complexity**: You would have to manage hundreds of `PriorityClass` objects.
2.  **No "Squeeze" Room**: If you use `1001` and `1002`, you can't insert a new priority level between them later. 
3.  **Grouping is Better**: In real production environments, we group pods into **Tiers**.

### Recommended Tiering Strategy:
| Category | Value | Example |
| :--- | :--- | :--- |
| **System** | 2,000,000,000 | K8s Components (Reserved) |
| **Tenant Critical** | 1,000,000 | Shared Ingress, Core DBs |
| **App Critical** | 100,000 | Customer-facing APIs |
| **Standard** | 10,000 | Regular Microservices |
| **Default** | 0 | (The global baseline) |
| **Best Effort** | -100 | Background workers, logs |

---

## 7. Built-in PriorityClasses

Kubernetes comes with two critical priority classes by default. They are at the absolute top of the hierarchy.

| Name | Value | Purpose |
| :--- | :--- | :--- |
| **`system-node-critical`** | 2000001000 | For pods that MUST run on nodes (like CNI plugins). |
| **`system-cluster-critical`** | 2000000000 | For essential cluster pods (like CoreDNS, API Server). |

---

## 7. Real-World Use Cases

How do companies actually use these values?

| Scenario | Tier | Rationale |
| :--- | :--- | :--- |
| **Ingress Controllers** | **Cluster-Wide Critical** | If Nginx-Ingress or Traefik dies, the *entire* cluster's external traffic stops. These should have very high priority. |
| **Payment Gateways** | **Business Critical** | In an e-commerce cluster, if the "Search" pod and "Payment" pod are fighting for space, you WANT the Payment pod to win so you don't lose money. |
| **Dev/Test Environment**| **Default (0)** | Regular experimental pods that aren't vital for uptime. |
| **ML Training Jobs** | **Negative / Best Effort** | Machine learning training can take days. It is "compressible"—it's better to pause a learning job than to crash the live website. |

---

## 8. Full Implementation Example

Here is a holistic example of how you would set up a "Platinum" tier for your most important production database.

```yaml
# 1. Create the PriorityClass
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: platinum-tier
value: 1000000
globalDefault: false
description: "Used for mission-critical production databases."
---
# 2. Create the Pod referencing it
apiVersion: v1
kind: Pod
metadata:
  name: prod-db
  labels:
    env: prod
spec:
  priorityClassName: platinum-tier
  containers:
  - name: postgres
    image: postgres:14
    resources:
      requests:
        memory: "2Gi"
        cpu: "1"
```

---

## 9. Practical Scenario: Managing 4 Different Apps

If you have 4 different applications, you should categorize them by their "Impact of Failure" rather than just giving them sequential numbers.

### The Apps:
1.  **Payment API**: Mission Critical (Losing money if it's down).
2.  **Frontend Web**: High Priority (Users see an error page if it's down).
3.  **Analytics Service**: Medium Priority (Business data is delayed, but users are fine).
4.  **Log Archiver**: Low Priority (Housekeeping, can run whenever).

### Step 1: Define the Tiers (PriorityClasses)
We create **3 reusable tiers** instead of 4 unique numbers. The Log Archiver will just use the default (0).

```yaml
# cluster-tiers.yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: critical-tier
value: 1000000
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-tier
value: 500000
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: standard-tier
value: 100000
```

### Step 2: Assign to App Pods

| App | Assigned PriorityClass | Why? |
| :--- | :--- | :--- |
| **Payment API** | `priorityClassName: critical-tier` | It will evict *anything* else to stay alive. |
| **Frontend Web** | `priorityClassName: high-tier` | Will evict standard apps, but won't touch Payments. |
| **Analytics** | `priorityClassName: standard-tier` | Will run if there's room, but will get killed for Frontend/Payments. |
| **Log Archiver** | *(None)* | Uses default priority (0). It is the first to be killed. |

---

## 10. Summary Cheat Sheet

| Situation | Behavior |
| :--- | :--- |
| **Higher Value** | Higher Priority (more important). |
| **Preemption** | The act of killing a low-priority pod to make room for a high-priority one. |
| **`preemptionPolicy`** | Can be `PreemptLowerPriority` (Default) or `Never` (Best-effort only). |
| **Namespace** | PriorityClasses are **Cluster-wide** (Global). |

---

## 11. kubectl Commands & Workflows

### Creating a PriorityClass

**There is NO shorthand `kubectl create priorityclass` with flags for value/globalDefault.**

You must write the YAML manually:

```bash
# Step 1: Create the YAML file
cat <<EOF > high-priority.yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority
value: 1000000
globalDefault: false
description: "For critical production workloads"
EOF

# Step 2: Apply it
kubectl apply -f high-priority.yaml
```

---

### Assigning PriorityClass to a Pod

**There is NO flag for `--priority-class-name` in `kubectl run`.**

You must use the **dry-run workflow**:

```bash
# Step 1: Generate the pod YAML
kubectl run low-prio-pod --image=nginx --dry-run=client -o yaml > pod.yaml

# Step 2: Edit the YAML to add priorityClassName
vim pod.yaml
# Add under spec:
#   priorityClassName: high-priority

# Step 3: Apply
kubectl apply -f pod.yaml
```

**Or use a one-liner with yq/sed:**
```bash
kubectl run low-prio-pod --image=nginx --dry-run=client -o yaml | \
  sed '/spec:/a\  priorityClassName: high-priority' | \
  kubectl apply -f -
```

---

### Inspecting PriorityClasses

```bash
# List all priority classes (shorthand: pc)
kubectl get priorityclass
kubectl get pc

# Describe a specific PriorityClass
kubectl describe pc high-priority

# View as YAML
kubectl get pc high-priority -o yaml

# See just the value
kubectl get pc high-priority -o jsonpath='{.value}'
```

**Output:**
```
NAME                      VALUE        GLOBAL-DEFAULT   AGE
high-priority             1000000      false            5m
system-cluster-critical   2000000000   false            30d
system-node-critical      2000001000   false            30d
```

---

### Inspecting Pods with Priority

**Check which pods are using priority classes:**

```bash
# Basic view - shows priority in YAML
kubectl get pod <pod-name> -o yaml | grep -A 2 priority

# Custom columns - Clean table view
kubectl get pods -o custom-columns="NAME:.metadata.name,PRIORITY:.spec.priorityClassName"
```

**Output:**
```
NAME              PRIORITY
nginx-critical    high-priority
web-app           <none>
db-backup         low-priority
```

**Check the numeric priority value:**
```bash
kubectl get pod <pod-name> -o jsonpath='{.spec.priority}'
```

**See all priority-related fields:**
```bash
kubectl get pod <pod-name> -o jsonpath='{.spec.priorityClassName}{" -> "}{.spec.priority}{"\n"}'
```

**Output:**
```
high-priority -> 1000000
```

---

### Filtering Pods by Priority

**Find all pods with a specific PriorityClass:**
```bash
kubectl get pods -A -o json | \
  jq -r '.items[] | select(.spec.priorityClassName=="high-priority") | .metadata.name'
```

**Find all pods without any priority:**
```bash
kubectl get pods -A -o json | \
  jq -r '.items[] | select(.spec.priorityClassName==null) | .metadata.name'
```

---

### Advanced Inspection

**See priorities across all namespaces:**
```bash
kubectl get pods -A -o custom-columns=\
"NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
PRIORITY_CLASS:.spec.priorityClassName,\
PRIORITY_VALUE:.spec.priority,\
NODE:.spec.nodeName"
```

**Check preemption policy of a PriorityClass:**
```bash
kubectl get pc high-priority -o jsonpath='{.preemptionPolicy}'
```

**List pods sorted by priority (requires jq):**
```bash
kubectl get pods -A -o json | \
  jq -r '.items | sort_by(.spec.priority // 0) | reverse | 
  .[] | "\(.spec.priority // 0)\t\(.metadata.name)"'
```

---

### Troubleshooting Commands

**Check if a pending pod is waiting due to preemption:**
```bash
kubectl describe pod <pod-name> | grep -A 10 Events
```

Look for messages like:
```
Normal   Preempted   Pod preempted to make room for higher priority pod
```

**Check scheduler logs for preemption events:**
```bash
kubectl logs -n kube-system -l component=kube-scheduler | grep -i preempt
```

---

### Quick Reference Table

| Task | Command |
|------|---------|
| **List all PriorityClasses** | `kubectl get pc` |
| **Create PriorityClass** | Must use YAML file (no imperative command) |
| **Delete PriorityClass** | `kubectl delete pc <name>` |
| **Check pod's priority class** | `kubectl get pod <name> -o jsonpath='{.spec.priorityClassName}'` |
| **Check pod's numeric priority** | `kubectl get pod <name> -o jsonpath='{.spec.priority}'` |
| **Custom columns view** | `kubectl get pods -o custom-columns="NAME:.metadata.name,PRIORITY:.spec.priorityClassName"` |
| **Check preemption policy** | `kubectl get pc <name> -o jsonpath='{.preemptionPolicy}'` |
