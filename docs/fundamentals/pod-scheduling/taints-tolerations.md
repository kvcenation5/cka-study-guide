# Taints and Tolerations

Taints and Tolerations work together to ensure that Pods are not scheduled onto inappropriate Nodes. While **Node Affinity** attracts Pods to a certain set of Nodes, **Taints** allow a Node to repel a set of Pods.

> [!CAUTION]
> ### 🔑 The Golden Rule
> - **Taints** are set on **Nodes**.
> - **Tolerations** are set on **Pods**.

---

## 🎭 The Real-World Analogy

Think of a **Taint** as a **Lock** on a door (the Node) and a **Toleration** as the **Key** carried by the Pod.

1.  **The Taint (The Lock)**: You put a lock on a room that says *"Only authorized personnel"*. Anyone without a key is kept out.
2.  **The Toleration (The Key)**: A person (the Pod) has a special key. They can enter the locked room, but they don't *have* to. They can still choose to sleep in the common area (an untainted node).

> [!IMPORTANT]
> A Toleration **allows** a Pod to schedule on a Tainted node, but it does not **force** it there. To force a Pod to a specific node, you use Node Affinity.

---

## 🛠️ How to Taint a Node

A Taint consists of a **Key**, a **Value**, and an **Effect**.

```bash
kubectl taint nodes node1 dedicated=finance:NoSchedule
```

### The Three Effects
| Effect | Behavior |
| :--- | :--- |
| **NoSchedule** | New pods will not be scheduled unless they have a matching toleration. Existing pods remain. |
| **PreferNoSchedule** | The scheduler will *try* to avoid placing untolerated pods here, but it's not a hard requirement. |
| **NoExecute** | New pods are blocked, AND **existing pods** without a toleration are immediately evicted from the node. |

---

## 🩹 Adding a Toleration to a Pod

To allow a Pod to "pass through" the taint, you add a `tolerations` section to the Pod spec.

```yaml
spec:
  containers:
  - name: nginx
    image: nginx
  tolerations:
  - key: "dedicated"
    operator: "Equal"
    value: "finance"
    effect: "NoSchedule"
```

### Operators
- **Equal**: The key, value, and effect must match exactly.
- **Exists**: The key must exist (the value is ignored). Useful for matching any pod to a specific "maintenance" taint.

---

## 🌍 Real-Life Examples

### 1. The "Control Plane" Isolation
By default, Kubernetes taints the Control Plane nodes so that your application pods don't take up resources meant for the API server or ETCD. 
- **Taint**: `node-role.kubernetes.io/control-plane:NoSchedule`
- **Toleration**: Critical system pods (like CoreDNS or Kube-Proxy) have a toleration for this so they can run on the masters.

### 2. Dedicated Hardware (GPU Nodes)
If you have expensive GPU nodes, you don't want a simple "Hello World" app taking up space there.
- **Action**: Taint the GPU nodes with `hardware=gpu:NoSchedule`.
- **Result**: Only your Machine Learning pods (with the matching toleration) will land there.

### 3. Maintenance / Evacuation
You need to perform hardware maintenance on `worker-3`.
- **Action**: Apply a `NoExecute` taint.
- **Result**: All pods currently running on `worker-3` are kicked off and rescheduled elsewhere, clearing the path for your maintenance.

### 4. Edge Computing / Cloud Bursting
You have some local nodes and some expensive nodes in the cloud.
- **Taint**: `location=cloud:PreferNoSchedule`
- **Result**: Kubernetes will fill up your local nodes first and only use the cloud nodes when the local ones are full.

---

## ⌨️ Useful Commands

| Goal | Command |
| :--- | :--- |
| **Apply Taint** | `kubectl taint nodes node-name key=value:Effect` |
| **Remove Taint** | `kubectl taint nodes node-name key:Effect-` (Suffix with dash) |
| **Verify Taints** | `kubectl describe node node-name | grep Taints` |
