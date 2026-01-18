# How to Identify Kubernetes Components
**(Is it a DaemonSet, Deployment, or Service?)**

## 1. The "Magic" Command
The easiest way to see **everything** and its type is to run:

```bash
kubectl get all -n kube-system
```

Look at the **PREFIX** of the output lines:
- `pod/coredns-...` → **Pod** (Actual container running)
- `service/kube-dns` → **Service** (Network endpoint/IP)
- `daemonset.apps/kube-proxy` → **DaemonSet**
- `deployment.apps/coredns` → **Deployment**

---

## 2. Common System Components (Cheat Sheet)

### ✅ DaemonSets (Runs on EVERY Node)
*Agents that act as the "glue" for the cluster.*
- **`kube-proxy`**: Manages network rules on every node.
- **CNI Plugins** (e.g., `calico-node`, `flannel`, `aws-node`): provides Pod networking.
- **Log Collectors** (e.g., `fluentd`, `filebeat`): Scrapes logs from every node.

### ✅ Deployments (Runs ANYWHERE)
*Scalable applications that don't need to be on every single machine.*
- **`coredns`**: DNS Server (usually 2 replicas for redundancy).
- **`metrics-server`**: Aggregates CPU/Memory stats.
- **`kubernetes-dashboard`**: Valid Web UI.

### ✅ Static Pods (Control Plane Only)
*These run directly on the Master Node manifest files. They often don't have a Deployment or DaemonSet controlling them.*
- **`kube-apiserver`**: The Brain.
- **`etcd`**: The Database.
- **`kube-scheduler`**: The Decision Maker.
- **`kube-controller-manager`**: The Loop Master.

---

## 3. Heuristic / Rule of Thumb

| Question to Ask | It probably is a... |
| :--- | :--- |
| "Does this provide a steady IP address?" | **Service** |
| "Does this need to handle networking/logs on **hardware**?" | **DaemonSet** |
| "Is this a standard app (web server, dns)?" | **Deployment** |
| "Does this hold unique data (database)?" | **StatefulSet** |

---

## 4. Default Cluster Inventory (What to expect in a fresh cluster)

When you run `kubectl get all -n kube-system` on a brand new cluster (e.g., Kubeadm, Minikube, or EKS), here is the standard checklist of what you will see.

### 🧠 The Control Plane (The Brains)
*Usually run as Static Pods on the Master Node(s). You won't see Deployments for these in managed clouds (EKS/GKE).*

1.  **`etcd`** (Database)
    *   **What is it?** The single source of truth. Stores all YAMLs, secrets, and cluster state.
    *   **Type:** Static Pod.
2.  **`kube-apiserver`** (Front Door)
    *   **What is it?** The only component you talk to (via `kubectl`). It validates valid requests and updates `etcd`.
    *   **Type:** Static Pod.
3.  **`kube-controller-manager`** (Automation)
    *   **What is it?** A loop that fixes things. If a pod dies, this process notices and creates a new one.
    *   **Type:** Static Pod.
4.  **`kube-scheduler`** (Placement)
    *   **What is it?** Decides *which* node a new pod should go to (based on CPU, RAM, Taints).
    *   **Type:** Static Pod.

### 🔌 Networking (The Plumbing)
*These make sure Pod A can talk to Pod B.*

1.  **`coredns`** (Phonebook)
    *   **What is it?** Allows you to reach services by name (e.g., `db-service`) instead of IP (`10.96.0.1`).
    *   **Type:** **Deployment** (usually 2 replicas).
    *   **Service:** `kube-dns` (ClusterIP).
2.  **`kube-proxy`** (Traffic Cop)
    *   **What is it?** Maintains network rules (iptables/IPVS) on nodes to route traffic.
    *   **Type:** **DaemonSet** (Must run on every node).
3.  **CNI Plugin** (The Cables - e.g., Flannel, Calico, Weave, AWS-VPC-CNI)
    *   **What is it?** Assigns IP addresses to Pods. Without this, nodes are "NotReady".
    *   **Type:** **DaemonSet** (Must run on every node).

### 🛡️ Optional but Common
1.  **`metrics-server`** (Stats)
    *   **What is it?** Enables `kubectl top nodes` and Horizontal Pod Autoscaling.
    *   **Type:** Deployment.
