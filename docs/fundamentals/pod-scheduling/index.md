# Pod Scheduling in Kubernetes

Scheduling is the process of assigning a Pod to a specific Node in the cluster. This is primarily handled by the **kube-scheduler**.

---

## 🏗️ How the Kube-Scheduler Works

The scheduler follows a two-step process to decide where a pod should live:

1.  **Filtering (Predicates)**: The scheduler finds all nodes that meet the pod's requirements (e.g., enough CPU/Memory, matching `nodeSelector`).
2.  **Scoring (Priorities)**: The scheduler ranks the remaining nodes using a set of scoring rules (e.g., balance load across nodes, favor nodes with existing images) to find the "best" fit.

> [!NOTE]
> If no nodes pass the filtering stage, the pod remains in `Pending` state.

---

## 🛠️ Scheduling Methods

### 1. Manual Scheduling (`nodeName`)
The simplest way to manually schedule a pod is by adding the `nodeName` field to the pod specification. When this field is present, the **kube-scheduler** completely ignores the pod, and the kubelet on the specified node attempts to run it.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: manual-pod
spec:
  nodeName: worker-1  # Directly assign to this node
  containers:
  - name: nginx
    image: nginx
```

> [!IMPORTANT]
> **Immutability**: The `nodeName` field is immutable. You can only set it at the time of pod creation. If you try to add `nodeName` to an existing pod using `kubectl edit`, Kubernetes will reject the change. To move a pod, you must delete and recreate it.

---

### 2. Under the Hood: The Binding Object
When the scheduler assigns a pod to a node, it doesn't actually edit the Pod object. Instead, it creates a **Binding** object. 

A Binding object is a temporary resource that tells the API server: "Link Pod A to Node B."

#### Scenario: Scheduling without a Scheduler
If the `kube-scheduler` is down or missing, you can manually schedule a pod by mimicking what the scheduler does: creating a Binding object via the API.

1.  **Identify Unscheduled Pods**: Use `kubectl get pods` to find pods in the `Pending` state.
2.  **Create a Binding JSON**:
    ```json
    {
        "apiVersion": "v1",
        "kind": "Binding",
        "metadata": {
            "name": "manual-pod"
        },
        "target": {
            "apiVersion": "v1",
            "kind": "Node",
            "name": "worker-1"
        }
    }
    ```
3.  **Submit to the API**: Send a POST request to the pod's binding endpoint.
    ```bash
    curl -X POST -H "Content-Type: application/json" \
      --data @binding.json \
      http://localhost:8001/api/v1/namespaces/default/pods/manual-pod/binding
    ```

---

### 3. Node Selector
A simple way to constrain pods to nodes with specific labels.

```yaml
spec:
  nodeSelector:
    disk: ssd
```

### 3. Node Affinity
A more powerful and expressive way to handle scheduling logic.

- **Required (Hard Rule)**: `requiredDuringSchedulingIgnoredDuringExecution`
- **Preferred (Soft Rule)**: `preferredDuringSchedulingIgnoredDuringExecution`

```yaml
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: topology.kubernetes.io/zone
            operator: In
            values: ["us-east-1a"]
```

### 4. Taints & Tolerations (Repelling Pods)
Taints are applied to **Nodes** to repel pods. Tolerations are applied to **Pods** to allow them to "tolerate" the taint.

**[Read the detailed guide on Taints and Tolerations here →](taints-tolerations.md)**

```yaml
spec:
  tolerations:
  - key: "key"
    operator: "Equal"
    value: "value"
    effect: "NoSchedule"
```

---

## ⚖️ Resource-Based Scheduling

The scheduler heavily relies on **Requests** and **Limits** to manage node capacity.

- **Requests**: What the pod is *guaranteed* to get. The scheduler uses this to find a node with enough space.
- **Limits**: The maximum amount of resources a pod can consume.

```yaml
spec:
  containers:
  - name: app
    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "128Mi"
        cpu: "500m"
```

---

## 📋 Summary Table

| Method | Target | Logic | Use Case |
| :--- | :--- | :--- | :--- |
| **nodeName** | Pod | Direct Assignment | Testing / Edge cases |
| **nodeSelector** | Pod | Label Matching | Simple Hardware requirements (SSD) |
| **Node Affinity** | Pod | Expressive Rules | Multi-zone, complex logic |
| **Taints/Tolerations** | Node/Pod | Repelling/Allowing | Dedicated nodes, Control Plane isolation |
