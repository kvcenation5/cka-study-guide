# Kube-Proxy Deep Dive

**Kube-Proxy** is the network "plumber" of your Kubernetes cluster. It runs on every single node and ensures that "Services" (like ClusterIP) actually work.

Without Kube-Proxy, `Service` IPs (e.g., `10.96.0.10`) would just be dead IP addresses that route nowhere.

---

## 1. How it Runs (The Architecture)

### Kubeadm / Standard Clusters
In 99% of modern clusters (and the CKA exam), Kube-Proxy runs as a **DaemonSet**.

*   **Type:** DaemonSet (Ensures exactly one pod runs on every node).
*   **Namespace:** `kube-system`
*   **Process:** It talks to the API server to watch for new Services and Endpoints.

To see it:
```bash
kubectl get daemonset -n kube-system kube-proxy
```

### "The Hard Way" / Legacy
In manual binary installations, `kube-proxy` is installed as a Systemd Service (binary) directly on the worker node OS, just like the Kubelet.

---

## 2. Configuration (Where is the config file?)

This is where Kube-Proxy differs from Static Pods.

*   **Static Pods (Scheduler/API):** Config is a **local file** on the node (`/etc/kubernetes/...`).
*   **Kube-Proxy:** Config is a **ConfigMap** inside Kubernetes.

### Finding the Config
You cannot just SSH into a node and edit a file to change Kube-Proxy settings. You must edit the ConfigMap object.

```bash
# View the config
kubectl -n kube-system get cm kube-proxy -o yaml

# Edit the config (e.g., to change mode from iptables to ipvs)
kubectl -n kube-system edit cm kube-proxy
```

**CRITICAL STEP:** After editing the ConfigMap, the Pods **will not update automatically**. You must restart the DaemonSet pods to pick up the changes:

```bash
kubectl -n kube-system rollout restart daemonset kube-proxy
```

---

## 3. Operations: What does it actually do?

Kube-Proxy watches the API Server for **Services** and **Endpoints**. When you create a Service, Kube-Proxy wakes up and writes network rules on the Node's kernel.

### The Modes (Implementing the Magic)

1.  **IPTables Mode (Default):**
    *   Kube-Proxy writes standard Linux `iptables` rules.
    *   Traffic to the Service IP is intercepted by the kernel and DNAT'ed (Forwarded) to a random Pod IP.
    *   **Pros:** Universal, mature.
    *   **Cons:** Slow at massive scale (5,000+ services).

2.  **IPVS Mode (High Performance):**
    *   Uses the Linux Kernel's IP Virtual Server (L4 Load Balancer).
    *   Uses hash tables instead of linear lists.
    *   **Pros:** Much faster for large clusters.
    *   **Cons:** Requires extra kernel modules to be loaded on the OS.

---

## 4. Cheat Sheet Summary

| Feature | Details |
| :--- | :--- |
| **Run As** | DaemonSet (Namespace: `kube-system`) |
| **Managed By** | Kubernetes Deployment Controller (DaemonSet controller) |
| **Configuration** | `ConfigMap: kube-proxy` |
| **Logs** | `kubectl logs -n kube-system -l k8s-app=kube-proxy` |
| **Core Job** | Translates Service VIPs -> Pod IPs using iptables/ipvs |
