# Resource Requests and Limits

In Kubernetes, managing CPU and Memory is critical for cluster stability. Without these settings, a single "noisy neighbor" pod can crash your entire node.

---

## 1. Requests vs. Limits (The Bank Analogy)

| Term | What it is | Analogy |
| :--- | :--- | :--- |
| **Requests** | **Minimum Guaranteed.** The amount of resources the pod is guaranteed to have. | **Minimum Balance**: The bank promises you can always withdraw this much. |
| **Limits** | **Maximum Allowed.** The upper ceiling the pod is not allowed to cross. | **Credit Limit**: The absolute maximum the bank allows you to spend. |

---

## 2. CPU vs. Memory: The "Pressure" Difference

It is vital to understand that Kubernetes treats CPU and Memory very differently when a pod hits its limit.

### A. CPU (Compressible Resource)
*   **Behavior**: When a pod hits its CPU limit, Kubernetes **throttles** it.
*   **Result**: The app doesn't crash; it just runs **slower**. (Like a car hitting a speed governor).
*   **Unit**: Measured in "millicores" (e.g., `500m` = 0.5 CPU cores).

### B. Memory (Non-Compressible Resource)
*   **Behavior**: When a pod hits its Memory limit, Kubernetes **Terminates** it immediately.
*   **Result**: The Pod is **OOMKilled** (Out Of Memory). (Like a balloon popping).
*   **Unit**: Measured in bytes (e.g., `256Mi`, `1Gi`).

---

## 3. Detailed Behavior Comparison

| Resource Type | At **Request** level | At **Limit** level |
| :--- | :--- | :--- |
| **CPU** (Compressible) | **Minimum Guaranteed.** If the node has spare CPU, the pod can "burst" above this. | **Hard Ceiling.** App is throttled. It is NOT killed, but performance drops. |
| **Memory** (Non-Compressible) | **Reserved.** This amount is physically set aside. If a node is full, no new pods can request it. | **Kill Switch.** If the app tries to use even 1 byte more, it is killed (OOM) immediately. |

### Why the difference?
*   **CPU** is a "time" resource. You can just give a process fewer slices of time per second. It's like a person walking slower.
*   **Memory** is a "space" resource. If you run out of physical space, you can't just "slow down" the memory usage. It's like a room that's full—you can't fit another person in without someone leaving or the walls breaking.

---

## 4. The "Ideal Scenarios"

Setting these numbers is an art, but there are some "Golden Rules" used in production:

### The Ideal Memory Scenario (Requests = Limits)
For **Memory**, the ideal scenario is almost always to set **Requests equal to Limits**.
*   **Why?** Memory is a "hard" resource. If you tell K8s a pod *requests* 256Mi but might use 1Gi (*limit*), K8s might schedule it on a node that only has 300Mi free. When the pod starts growing toward its 1Gi limit, it will crash or cause the node to start killing other pods.
*   **Result**: You get the **Guaranteed** QoS class, which makes your pod the last one to be killed in an emergency.

### The Ideal CPU Scenario (Requests < Limits)
For **CPU**, it is often better to leave some "headroom" (Burstable QoS).
*   **Ideal Setting**: Set **Request** to your app's *average* usage and **Limit** to its *peak* burst usage.
*   **Why?** Since CPU only throttles (slows down) rather than kills, it's safer to overcommit slightly. This allows your app to "burst" during a startup or a traffic spike without wasting expensive CPU cycles when the app is idle.

### The "Goldilocks" Rule
*   **Too Low**: Pod crashes (OOM) or is too slow to respond (Throttling).
*   **Too High**: You are wasting money and "locking" resources that other pods could use, leading to fragmented nodes.
*   **Just Right**: Set requests to the **90th percentile** of your actual usage.

---

## 5. The "No CPU Limits" Strategy (Expert Tip)

Many advanced Kubernetes courses (and high-scale companies) recommend setting **Requests but NO Limits** for CPU.

### Why remove CPU Limits?
1.  **Avoid Artificial Throttling**: Even if a node is 90% idle, a CPU limit can artificially slow down your app. This wastes the "slack" (unused) resources of the cluster.
2.  **Slack Harvesting**: If your app has no limit, it can "harvest" any unused CPU cycles from the node to process tasks significantly faster.
3.  **K8s Fair Share**: Kubernetes is smart! If other pods need their CPU (because they have Requests), it will automatically squeeze your "limit-less" pod back down to its original **Request** amount. It won't let you steal from others.

**In summary:**
*   **Memory**: ALWAYS set limits (to prevent OOM).
*   **CPU**: Consider "No Limits" to maximize performance, as long as you have a solid **Request** to guarantee your fair share.

---

## 6. QoS Classes Explained

Kubernetes automatically assigns a **Quality of Service (QoS)** class to your pod based on how you set your requests and limits.

| QoS Class | How to get it | Priority |
| :--- | :--- | :--- |
| **Guaranteed** | Requests == Limits (for both CPU & RAM) | **Highest.** The node will fight to keep these alive. |
| **Burstable** | Requests < Limits | **Medium.** Pod can use extra resources if the node has them. |
| **BestEffort** | No Requests, No Limits | **Lowest.** First to be killed if the node runs out of memory. |

**Ideal Behavior:** For critical production databases or core services, always use **Guaranteed** (Requests = Limits). For web apps, use **Burstable**.

---

## 7. Real-Time Examples & Troubleshooting

### Example 1: The "Throttled" Web Server
*   **Setting**: `request: 100m`, `limit: 200m`.
*   **Scenario**: A sudden spike in traffic.
*   **Result**: The pod stays `Running`, but page load times slow down from 200ms to 2s.
*   **Fix**: Check `kubectl top pod` and increase the CPU limit.

### Example 2: The "Popping" Java App (OOMKilled)
*   **Setting**: `request: 512Mi`, `limit: 512Mi`.
*   **Scenario**: The Java Heap grows beyond 512Mi.
*   **Result**: Status changes to `CrashLoopBackOff`. `kubectl describe pod` shows `Reason: OOMKilled`.
*   **Fix**: Increase the memory limit or tune the app's memory usage.

---

## 8. Summary Cheat Sheet

| Situation | Action |
| :--- | :--- |
| **How does Scheduler decide?** | It uses **Requests**. If a node has 1Gi free, it can fit a pod requesting 512Mi. |
| **What if Limits > Node Capacity?** | This is called **Overcommitting**. It's fine until everyone tries to use their limits at the same time. |
| **Standard units?** | CPU: `m` (millicores), Memory: `Ei, Pi, Ti, Gi, Mi, Ki`. |

---

## 9. How to check usage
```bash
# Check node resources
kubectl top node

# Check pod resources
kubectl top pod

# Check if a pod was OOMKilled
kubectl describe pod <pod-name> | grep -A 5 "Last State"
```
