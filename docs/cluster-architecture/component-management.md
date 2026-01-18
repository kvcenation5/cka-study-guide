# Component Management: Static Pods vs. Systemd

Understanding how Kubernetes components are run is the **single most common** stumbling block for CKA students.

Kubernetes components are run in one of two ways:
1.  **Systemd Services** (Native Binary)
2.  **Static Pods** (Containerized)

## 1. The "Kubelet" Exception
The **Kubelet** is unique. It is the only component that is **ALWAYS** run as a binary (Systemd Service).

### Why? (The "Captain" Analogy)
Imagine a ship (the Node).
*   **The Containers (Static Pods)** are the cargo.
*   **The Kubelet** is the Captain.

**The Captain cannot be cargo.**
The Kubelet's job is to talk to the Container Runtime (Docker/Containerd) and say "Start this container." If the Kubelet *was* a container itself, who would start it? It's a chicken-and-egg problem.

Therefore, the Kubelet must always be installed on the Operating System `(apt-get install kubelet)` and managed by the OS init system `(systemctl start kubelet)`.

---

## 2. Static Pods (The "Mirror" Concept)

Once the Kubelet (Captain) is running, it can start other components (API Server, ETCD, Scheduler) as Containers.

### What is a Static Pod?
A Static Pod is a pod managed directly by the Kubelet on a specific node, **without** the API Server observing it initially.

*   **Normal Pod:** API Server -> Scheduler -> Kubelet -> Run Pod.
*   **Static Pod:** Kubelet -> Reads File -> Run Pod.

### How it works
1.  **Configuration:** The Kubelet config file (`/var/lib/kubelet/config.yaml`) has a setting: `staticPodPath: 
/etc/kubernetes/manifests`.
2.  **The Watch:** The Kubelet watches that folder constantly.
3.  **The Action:**
    *   If you put a file `etcd.yaml` there -> Kubelet starts the pod.
    *   If you delete the file -> Kubelet kills the pod.
4.  **The Mirror:** The Kubelet creates a "Mirror Pod" on the API Server so you can see it with `kubectl get pods`, but you **cannot edit it** via kubectl. It is read-only in the API.

!!! info "Deep Dive"
    For a complete guide on Static Pods (Creation, Use Cases, Master-Down scenarios), see the [Static Pods Fundamentals](../fundamentals/static-pods.md) guide.

---

## 3. Topologies Summary (CKA Cheat Sheet)

| Component | Run As | Location of Config | managed By |
| :--- | :--- | :--- | :--- |
| **Kubelet** | **Systemd Service** | `/var/lib/kubelet/config.yaml` | `systemctl` |
| **Etcd** | Static Pod | `/etc/kubernetes/manifests/etcd.yaml` | Kubelet (File edit) |
| **API Server** | Static Pod | `/etc/kubernetes/manifests/kube-apiserver.yaml` | Kubelet (File edit) |
| **Scheduler** | Static Pod | `/etc/kubernetes/manifests/kube-scheduler.yaml` | Kubelet (File edit) |
| **Controller Mgr** | Static Pod | `/etc/kubernetes/manifests/kube-controller-manager.yaml` | Kubelet (File edit) |
| **Kube-Proxy** | **DaemonSet** | ConfigMap/API | Kubernetes (API) |

## 4. The Kube-Proxy Exception (DaemonSet)
You might notice `kube-proxy` is missing from the Static Pod folder.

**It is NOT a Static Pod.**
*   **Why?** Static Pods are for the "Brain" (Control Plane) that creates the cluster. `kube-proxy` is a worker Process that runs on *every* node (even workers).
*   **How it runs:** It is run as a **DaemonSet**.
    *   This means the **Scheduler** schedules it.
    *   You manage it via `kubectl edit daemonset kube-proxy -n kube-system`.
    *   It reads its configuration from a **ConfigMap** (not a local file).

**Why this matters:**
If you try to find `/etc/kubernetes/manifests/kube-proxy.yaml`, it won't be there. You must use `kubectl` to configure it.
