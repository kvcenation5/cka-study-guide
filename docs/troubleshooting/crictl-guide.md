# crictl: Container Runtime Interface CLI

`crictl` is a command-line interface for CRI-compatible container runtimes. For the CKA exam, it is a vital tool for troubleshooting nodes when `kubectl` is unavailable or when you need to inspect what is happening at the runtime level (containerd, CRI-O, etc.).

---

## 🧐 What is `crictl`?

While `kubectl` talks to the **API Server**, `crictl` talks directly to the **Container Runtime** (like `containerd`) on the node.

### Why use it in the CKA Exam?
1.  **Node Troubleshooting**: If a node is `NotReady` and you can't see pods via `kubectl`, you SSH into the node and use `crictl` to see if containers are actually running.
2.  **Static Pods**: Static pods (like the API Server or Etcd) are managed by the Kubelet, not the API Server. `crictl` is the best way to see their "real" status on the disk.
3.  **No Docker**: Modern Kubernetes clusters (v1.24+) have removed the "Dockershim". You can no longer use `docker ps` on many clusters. `crictl` is the standardized replacement.

---

## ⚙️ 1. Configuration (`/etc/crictl.yaml`)

Before using `crictl`, it must be pointed to the correct runtime socket. If it's not configured, commands will fail with "cannot connect to runtime".

**Check or create the config:**
```bash
cat /etc/crictl.yaml
```

**Standard Configuration (for containerd):**
```yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 2
debug: false
```

---

## 🛠️ 2. Common Troubleshooting Commands

`crictl` commands are very similar to Docker commands, making them easy to remember.

### Pod Operations
| Task | Command |
| :--- | :--- |
| **List all Pods** | `crictl pods` |
| **Inspect a Pod** | `crictl inspectp <pod-id>` |
| **Remove a Pod** | `crictl rmp <pod-id>` |

### Container Operations
| Task | Command |
| :--- | :--- |
| **List running containers** | `crictl ps` |
| **List all containers** | `crictl ps -a` |
| **View logs** | `crictl logs <container-id>` |
| **Exec into container** | `crictl exec -it <container-id> sh` |
| **Inspect container** | `crictl inspect <container-id>` |
| **Stop a container** | `crictl stop <container-id>` |

### Image Operations
| Task | Command |
| :--- | :--- |
| **List images** | `crictl images` |
| **Pull an image** | `crictl pull <image-name>` |
| **Remove an image** | `crictl rmi <image-id>` |

---

## 🔄 3. Comparison: Docker vs. crictl

| Feature | Docker CLI | crictl |
| :--- | :--- | :--- |
| **List Containers** | `docker ps` | `crictl ps` |
| **List Images** | `docker images` | `crictl images` |
| **Logs** | `docker logs` | `crictl logs` |
| **Exec** | `docker exec` | `crictl exec` |
| **Pod Awareness** | ❌ None | ✅ `crictl pods` |
| **Namespace** | Host Only | CRI Runtime Namespace |

---

## 🧪 4. CKA Debugging Scenario

**Scenario**: A student reports that the API Server static pod is crashing, but `kubectl` is completely unresponsive because the API is down.

**Steps to troubleshoot on the Master Node:**
1.  **SSH** into the master node.
2.  **List all containers** to find the API server:
    ```bash
    crictl ps -a | grep kube-apiserver
    ```
3.  **Get the logs** of the crashed container:
    ```bash
    crictl logs <container-id>
    ```
4.  **Identify the error** (e.g., "invalid certificate path" or "cannot connect to etcd").
5.  **Fix the manifest** at `/etc/kubernetes/manifests/kube-apiserver.yaml`.
6.  **Verify** the container restarts:
    ```bash
    watch crictl ps | grep kube-apiserver
    ```

---

> [!TIP]
> **Helper for the Exam**: If `crictl` is not configured on the exam server, they might expect you to use `crictl --runtime-endpoint unix:///run/containerd/containerd.sock ps`. Always check the `/etc/crictl.yaml` first!

---

## 📚 External References

- [Mumshad Mannambeth: Kubernetes The Hard Way - Tools](https://github.com/mmumshad/kubernetes-the-hard-way/tree/master/tools)

