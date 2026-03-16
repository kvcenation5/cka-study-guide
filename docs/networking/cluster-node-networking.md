# Cluster Node Networking Prerequisites

Before installing Kubernetes, whether you are using physical servers, virtual machines, or cloud instances, the underlying nodes must meet specific networking requirements.

A Kubernetes cluster consists of **Master** (Control Plane) and **Worker** nodes. Here are the fundamental network configurations required for them to function correctly.

---

## 🖥️ 1. Basic Node Requirements

Every node in your cluster (Master and Worker) must meet these conditions:

1.  **Network Interface**: Each node must have at least one active network interface connected to the network.
2.  **IP Address**: Each interface must have a valid IP address configured.
3.  **Unique Hostname**: Every node must have a unique hostname. Kubernetes uses the hostname to identify nodes.
4.  **Unique MAC Address**: Every node must have a distinct MAC address. 
    *   *Warning*: If you create VMs by cloning an existing template, ensure the virtualization platform generates a new MAC address and you change the hostname for each clone!

---

## 🔓 2. Required Open Ports

Kubernetes components communicate heavily over the network. If these ports are blocked by a firewall (like `iptables`, `firewalld`, or cloud Network Security Groups in AWS/Azure/GCP), your cluster will fail.

### Control Plane (Master) Nodes
The Control Plane composes several specific components, each listening on a precise port:

*   **`kube-apiserver`**: Listens on **`6443`**. Used by worker nodes, external users (`kubectl`), and all other control plane components to access the cluster.
*   **`etcd` server**: Listens on **`2379`** for client API requests. If you have multiple master nodes, it also uses **`2380`** to sync data between the etcd peers.
*   **`kubelet`**: Listens on **`10250`**. (Remember, the kubelet runs on master nodes too!).
*   **`kube-scheduler`**: Requires **`10259`** to be open.
*   **`kube-controller-manager`**: Requires **`10257`** to be open.

| Protocol | Direction | Port Range | Purpose | Used By |
| :--- | :--- | :--- | :--- | :--- |
| TCP | Inbound | **6443** | Kubernetes API server | All components, `kubectl`, external users |
| TCP | Inbound | **2379 - 2380** | etcd server client API | `kube-apiserver`, etcd peers |
| TCP | Inbound | **10250** | Kubelet API | Self, Control Plane |
| TCP | Inbound | **10259** | kube-scheduler | Self |
| TCP | Inbound | **10257** | kube-controller-manager | Self |

### Worker Nodes
Worker nodes have fewer components but are responsible for exposing your applications:

*   **`kubelet`**: Listens on **`10250`**. The API server communicates with the worker node's kubelet via this port.
*   **NodePort Services**: Requires the massive **`30000 - 32767`** port range. This is how the worker nodes expose applications to the outside world.

| Protocol | Direction | Port Range | Purpose | Used By |
| :--- | :--- | :--- | :--- | :--- |
| TCP | Inbound | **10250** | Kubelet API | Self, Control Plane |
| TCP | Inbound | **30000 - 32767** | NodePort Services | External load balancers, clients |

---

## 🚩 3. Node Verification & Troubleshooting Commands

In the CKA exam or in the real world, you will frequently be asked to verify a node's configuration or troubleshoot why it isn't communicating. **Keep these commands handy:**

### 📡 Verify Network Interfaces & IP Addresses
Ensure the node is attached to the network and has a valid IP configured:
```bash
ip addr show
# Or the common shorthand:
ip a
```

### 🏷️ Verify Unique MAC Addresses
Especially important if your nodes are VMs that were cloned from a template:
```bash
ip link show
# Or check the eth0 hardware address directly:
cat /sys/class/net/eth0/address
```

### 📛 Verify Unique Hostnames
Check the current identity of the node:
```bash
hostname
# Or view the underlying configuration file:
cat /etc/hostname
```

### 🚪 Verify Listening Ports
If your nodes are failing to communicate, verify that the required ports from Section 2 are actually actively listening on the host. This command will also show you *which* process (like `kube-apiserver` or `kubelet`) is holding that port:
```bash
# Using netstat
netstat -nltp

# Or the modern equivalent, ss (socket statistics)
ss -nltp
```

> [!TIP]
> **Firewalls vs Crashes**: If a port is *not* listening when you run `netstat`, the underlying service has probably crashed (check `systemctl status kubelet`, for example). If the port *is* listening locally but another node can't reach it, a firewall is likely blocking the traffic (check `iptables -L`).
