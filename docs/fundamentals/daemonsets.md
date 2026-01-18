# Understanding DaemonSets in Kubernetes

## What are DaemonSets?

A **DaemonSet** is a Kubernetes controller that ensures a copy of a pod runs on all (or selected) nodes in your cluster.

### Key Concept: DaemonSet vs Pods

- **DaemonSet** = A Kubernetes controller/object that **creates and manages pods**
- **Pods** = The actual running containers created by the DaemonSet

!!! note "Important Distinction"
    The DaemonSet itself is NOT a pod - it's a controller that creates pods.

## The Hierarchy

```
DaemonSet (the controller)
    └─> Creates and manages
        └─> Pods (the actual workload)
            └─> Contains
                └─> Containers (e.g., Fluentd container running inside)
```

## DaemonSets and Namespaces

### How It Works

When you create a DaemonSet in a specific namespace:

1. The **DaemonSet object** lives in that namespace
2. The **pods** created by it are also in that same namespace
3. But those pods **run on ALL nodes** in the cluster (or selected nodes)

!!! tip "Key Understanding"
    **Namespaces** = Logical groupings for organizing Kubernetes objects  
    **Nodes** = Physical/virtual machines in your cluster
    
    DaemonSets ensure one pod runs on every **node** (physical), but the DaemonSet exists in a specific **namespace** (logical).

### Visual Example: Fluentd DaemonSet

```
Cluster with 3 nodes:

Node 1                  Node 2                  Node 3
├─ fluentd pod         ├─ fluentd pod         ├─ fluentd pod
│  (namespace: logging) │  (namespace: logging) │  (namespace: logging)
│                       │                       │
├─ app-a pod           ├─ app-b pod           ├─ app-c pod
│  (namespace: prod)    │  (namespace: prod)    │  (namespace: dev)
│                       │                       │
└─ database pod        └─ nginx pod           └─ redis pod
   (namespace: prod)       (namespace: staging)    (namespace: dev)
```

All Fluentd pods are in the `logging` namespace, but they run on every node to collect logs from pods in ALL namespaces.

## Example: Fluentd DaemonSet

### Creating a Fluentd DaemonSet

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd
  namespace: logging  # DaemonSet is in 'logging' namespace
spec:
  selector:
    matchLabels:
      name: fluentd
  template:  # This is the pod template
    metadata:
      labels:
        name: fluentd
    spec:
      containers:
      - name: fluentd
        image: fluent/fluentd:latest
        volumeMounts:
        - name: varlog
          mountPath: /var/log
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
```

### What Kubernetes Does

1. **Creates the DaemonSet object** (just a definition, not running anything yet)
2. **Looks at all nodes** in the cluster
3. **Creates one pod per node** using the template in the DaemonSet
4. **The pods actually run Fluentd**

## Viewing DaemonSets and Pods

### View the DaemonSet Controller

```bash
kubectl get daemonset -n logging
```

Output:
```
NAME      DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE
fluentd   3         3         3       3            3
```

The "3" means 3 nodes in the cluster, so 3 pods were created.

### View the Actual Pods

```bash
kubectl get pods -n logging -o wide
```

Output:
```
NAME            READY   STATUS    RESTARTS   AGE   NODE
fluentd-abc123  1/1     Running   0          5m    node1
fluentd-def456  1/1     Running   0          5m    node2
fluentd-ghi789  1/1     Running   0          5m    node3
```

## Self-Healing Behavior

DaemonSets automatically recreate pods if they're deleted:

```bash
# Delete one pod manually
kubectl delete pod fluentd-abc123 -n logging

# Check pods again - DaemonSet recreated it!
kubectl get pods -n logging

# Output:
NAME            READY   STATUS    RESTARTS   AGE   NODE
fluentd-xyz999  1/1     Running   0          5s    node1  # New pod!
fluentd-def456  1/1     Running   0          5m    node2
fluentd-ghi789  1/1     Running   0          5m    node3
```

## Node Selection

### Using nodeSelector

Control which nodes get DaemonSet pods:

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd
  namespace: logging
spec:
  selector:
    matchLabels:
      name: fluentd
  template:
    metadata:
      labels:
        name: fluentd
    spec:
      nodeSelector:
        logging: "true"  # Only nodes with this label
      containers:
      - name: fluentd
        image: fluent/fluentd:latest
```

Label specific nodes:

```bash
# Label nodes for Fluentd
kubectl label nodes node1 logging=true
kubectl label nodes node2 logging=true
# node3 has no label, so no Fluentd pod there
```

### Using Node Affinity

More advanced node selection:

```yaml
spec:
  template:
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: kubernetes.io/hostname
                operator: In
                values:
                - node1
                - node2
```

## Common DaemonSet Use Cases

All these follow the same pattern: DaemonSet in one namespace, pods on all nodes.

### Logging Agents
```yaml
# Fluentd, Filebeat, Logstash
namespace: logging
runs on: all nodes
purpose: collect logs from all pods
```

### Monitoring Agents
```yaml
# Prometheus Node Exporter, Datadog agent
namespace: monitoring
runs on: all nodes
purpose: collect metrics from all nodes/pods
```

### Networking
```yaml
# Calico, Weave, Cilium CNI plugins
namespace: kube-system
runs on: all nodes
purpose: provide networking for all pods
```

### Storage
```yaml
# Ceph, GlusterFS clients
namespace: storage
runs on: all nodes
purpose: provide storage access
```

## DaemonSets vs Other Controllers

| Controller | Creates | Purpose |
|------------|---------|---------|
| **DaemonSet** | Pods (one per node) | Ensure pod on every node |
| **Deployment** | ReplicaSet → Pods | Manage stateless apps |
| **StatefulSet** | Pods (with stable identity) | Manage stateful apps |
| **Job** | Pods (run to completion) | Run batch tasks |
| **CronJob** | Jobs → Pods | Run scheduled tasks |

## RBAC for Cross-Namespace Access

Fluentd needs cluster-wide permissions to read logs from all namespaces:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: fluentd
  namespace: logging
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole  # ClusterRole, not Role
metadata:
  name: fluentd
rules:
- apiGroups: [""]
  resources: ["pods", "namespaces"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding  # Binds across all namespaces
metadata:
  name: fluentd
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: fluentd
subjects:
- kind: ServiceAccount
  name: fluentd
  namespace: logging
```

## DaemonSets and ResourceQuotas

!!! warning "Important Consideration"
    DaemonSet pods DO count against namespace ResourceQuotas.

If you have:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: logging-quota
  namespace: logging
spec:
  hard:
    pods: "5"
    requests.cpu: "2"
    requests.memory: "4Gi"
```

And your cluster has 10 nodes, your Fluentd DaemonSet will try to create 10 pods but will **fail** because the quota only allows 5 pods.

**Solution:** Set appropriate quotas for namespaces with DaemonSets.

## Practical Workflow

### 1. Create the DaemonSet

```bash
kubectl apply -f fluentd-daemonset.yaml
```

### 2. Verify DaemonSet Created

```bash
kubectl get daemonset -n logging
```

### 3. Check Pods Were Created

```bash
kubectl get pods -n logging -o wide
```

### 4. View Logs from a Pod

```bash
kubectl logs fluentd-abc123 -n logging
```

### 5. Update the DaemonSet

```bash
# Edit the DaemonSet
kubectl edit daemonset fluentd -n logging

# Or apply updated YAML
kubectl apply -f fluentd-daemonset.yaml
```

### 6. Delete the DaemonSet

```bash
# This deletes the DaemonSet AND all its pods
kubectl delete daemonset fluentd -n logging
```

## Analogy: Factory Workers

Think of it like a factory:

- **DaemonSet** = The factory manager that says "I need one worker on every floor"
- **Pods** = The actual workers doing the job on each floor
- **Containers** = The tools the workers use (Fluentd software)
- **Nodes** = The floors in the factory building
- **Namespace** = The department that manages these workers

## Summary

!!! success "Key Takeaways"
    ✅ **DaemonSet** = Definition/controller (doesn't run workloads itself)  
    ✅ **Pods** = The actual running instances created by the DaemonSet  
    ✅ You **create** a DaemonSet, it **creates** pods  
    ✅ DaemonSet is in a specific namespace, but pods run on ALL nodes  
    ✅ If you delete the DaemonSet, all its pods are deleted  
    ✅ If a pod dies, the DaemonSet recreates it automatically  
    ✅ **Namespaces** = logical organization, **Nodes** = physical infrastructure

### Mental Model

- **Namespace** = where the DaemonSet and its pods "live" logically
- **Nodes** = where the pods actually run physically
- DaemonSets bridge the two by ensuring pods are on every node, regardless of namespace

---
---

# Appendix: Original Version (Quick Summary)

Below is the original, concise version of the DaemonSet documentation for quick reference.

## 1. The "Resident Agent" Analogy

Think of a DaemonSet like a **Landlord's Security Guard**. 
*   **Deployment**: Like a store chain. You want 10 stores total, and you don't care exactly which street they are on as long as there are 10.
*   **DaemonSet**: Like a security guard for an apartment building. Each building (Node) **must** have exactly one guard. If a new building is built, a new guard is hired automatically.

---

## 2. Common Use Cases (The "Infrastucture" Layer)

You rarely use DaemonSets for your own web apps. You use them for tools that help the cluster run:

1.  **Logging**: `fluentd` or `logstash` running on every node to collect logs.
2.  **Monitoring**: `prometheus-node-exporter` to gather hardware metrics from every node.
3.  **Networking**: `kube-proxy` and CNI plugins (like Calico or Flannel) must run on every node to enable communication.
4.  **Storage**: `ceph` or `glusterfs` to provide distributed storage across the nodes.

---

## 3. How Scheduling Works

In the past, the DaemonSet controller handled its own scheduling. Now, it uses the standard Kubernetes scheduler.

*   **Taints & Tolerations**: DaemonSets automatically handle standard node taints (like `node.kubernetes.io/unschedulable`) so they can run even on "Maintenance" nodes.
*   **Node Affinity**: You can use `nodeAffinity` within a DaemonSet to say "Run this on all nodes with a GPU" instead of *every* single node in the cluster.

---

## 4. Practical Example (The "Monitoring" Agent)

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: monitoring-agent
  namespace: kube-system
spec:
  selector:
    matchLabels:
      name: monitoring-agent
  template:
    metadata:
      labels:
        name: monitoring-agent
    spec:
      containers:
      - name: agent
        image: prometheus/node-exporter:latest
        resources:
          limits:
            memory: 200Mi
          requests:
            cpu: 100m
            memory: 200Mi
```

---

## 5. Deployment vs. DaemonSet: Quick Comparison

| Feature | Deployment / ReplicaSet | DaemonSet |
| :--- | :--- | :--- |
| **Pod Count** | Defined by `replicas: X` | Defined by the number of Nodes |
| **Placement** | Scheduler decides (spreads them out) | One per Node (guaranteed) |
| **New Node?** | Nothing changes | Automaticaly spawns a new Pod |
| **Use Case** | Web Apps, APIs, DBs | Logs, Monitoring, Networking |

---

## 6. Summary Cheat Sheet

| Question | Answer |
| :--- | :--- |
| **Can I scale a DaemonSet?** | No. There is no `replicas` field. It scales with the cluster. |
| **Can I run 2 pods per node?** | No. A DaemonSet is strictly 1-per-node (or 0 if filtered by labels). |
| **How to check them?** | `kubectl get ds` |

---

## 7. Commands to check
```bash
# List all DaemonSets
kubectl get ds -A

# See which pods belong to which node
kubectl get pods -o wide

# Describe for troubleshooting
kubectl describe ds monitoring-agent
```
