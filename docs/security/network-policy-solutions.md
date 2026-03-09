# Network Policy Solutions (CNI Plugins)

Kubernetes defines the **NetworkPolicy API**, but it does not include a built-in controller to enforce it. To use Network Policies, you must install a **Network Solution** (CNI Plugin) that supports them.

---

## 🚀 1. Top CNI Solutions for Network Policy

| CNI Plugin | Standard NP Support | Extended Features (CRDs) | Technology |
| :--- | :---: | :--- | :--- |
| **Calico** | ✅ Full | Policy Ordering, Deny Rules, Global Policies | iptables / eBPF |
| **Cilium** | ✅ Full | L7 (HTTP/gRPC/Kafka) filtering, Identity-based security | eBPF |
| **Antrea** | ✅ Full | Tiered security, Cluster-wide policies | Open vSwitch |
| **Weave Net** | ✅ Full | Transparent Encryption | iptables / Overlay |
| **Flannel** | ❌ None | N/A (Needs Calico/Canal) | VXLAN / UDP |

---

## 🛠️ 2. Deep Dive: Popular Choices

### 🐯 Project Calico
The most widely used CNI for Network Policy.
*   **Performance**: High throughput with minimal overhead.
*   **Standard + More**: Implements standard K8s NetworkPolicies PLUS its own `GlobalNetworkPolicy` which can apply across the whole cluster, not just one namespace.
*   **Host Protection**: Can protect the worker node's host interfaces, not just pod-to-pod traffic.

### 🐝 Cilium
The high-performance choice leveraging **eBPF**.
*   **L7 Visibility**: Can filter traffic based on application data (e.g., "Allow GET requests to /public but deny POST to /admin").
*   **Efficiency**: Bypasses the complex Linux `iptables` rules, making it much faster for clusters with thousands of pods.
*   **FQDN Policies**: Allows you to define egress rules using domain names (e.g., `api.google.com`) instead of hardcoded IP addresses.

### 🕸️ Weave Net
Focuses on simplicity and internal security.
*   **Encryption**: Automatically encrypts all traffic between nodes.
*   **Simple Setup**: Very easy to install with a single manifest.
*   **Note**: Less flexible for complex L7 rules compared to Cilium.

---

## 🏗️ 3. Cloud Provider Support

If you are using a managed service (EKS, GKE, AKS), the default CNI might support Network Policies natively or require an addon.

| Cloud Service | Solution |
| :--- | :--- |
| **Amazon EKS** | Uses **AWS VPC CNI**. Supports Network Policy natively (in Newer versions) or via **Calico** addon. |
| **Google GKE** | Supports Network Policy via **Calico** or **GKE Dataplane V2** (Cilium-powered). |
| **Azure AKS** | Supports **Azure Network Policy** or **Calico**. |

---

## 🚩 4. CKA Exam Perspective: "Why isn't it working?"

In the CKA exam or real world, if you apply a Network Policy and it doesn't block anything:
1.  **Check the CNI**: Run `kubectl get pods -n kube-system` and look for the network plugin (e.g., `calico-node`, `cilium`, `weave-net`).
2.  **Flannel Trap**: If you only see `kube-flannel`, Network Policies will **never** work unless you also see `canal` or `calico` running alongside it.
3.  **Labels**: Ensure the Pods have the exact labels your policy is searching for.
4.  **Namespace**: Remember that `NetworkPolicy` is a **namespaced resource**. It must be in the same namespace as the pods it is trying to protect.

---

> [!IMPORTANT]
> **Canal**: If you see a cluster running "Canal", it is actually a hybrid of **Flannel** (for basic networking) and **Calico** (for enforcing Network Policies). This is a very common production setup.
