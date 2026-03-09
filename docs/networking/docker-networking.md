# Docker Networking: The Predecessor to CNI

Kubernetes networking evolved from patterns popularized by Docker. Understanding Docker's networking modes helps clarify why Kubernetes chose its specific Networking Model.

---

## 🏗️ 1. The Default: Bridge Mode (`docker0`)

When you install Docker, it creates a virtual bridge named `docker0`.

*   **Behavior**: Every container gets a private IP (e.g., `172.17.0.x`).
*   **Masquerading (NAT)**: When a container talks to the internet, Docker uses **IP Masquerade (NAT)** to change the source address to the Host's IP.
*   **Port Mapping**: Because the container's IP is private, you must "publish" ports to make them reachable from the outside.
    ```bash
    docker run -p 8080:80 nginx
    ```

---

## ⚡ 2. The Direct Option: Host Mode

In Host Mode, the container is **not** isolated. It shares the same network namespace as the host.

*   **Command**: `docker run --network host nginx`
*   **Pros**: High performance (no NAT overhead).
*   **Cons**: Port collisions. Two containers cannot both listen on port 80.

---

## 🛡️ 3. The Isolated Option: None Mode

The container has a loopback interface (`localhost`) but **no external network connectivity**. Useful for batch processing jobs that don't need network access.

---

## 🔗 4. How Docker differs from Kubernetes

| Feature | Docker (Default) | Kubernetes |
| :--- | :--- | :--- |
| **Connectivity** | Containers on different hosts cannot talk to each other without NAT/VPN. | **All Pods** can talk to all other Pods without NAT (Fundamental Rule). |
| **IP Per Pod** | Containers share IPs if in the same Compose file; otherwise, individual. | Every Pod gets its own **Cluster-Unique IP**. |
| **Discovery** | Uses internal DNS or file-based `links`. | Uses **CoreDNS** and **Services**. |

---

## 🚩 5. CKA Context: `crictl` and `cni0`

In a modern Kubernetes cluster, you might not even use Docker (using `containerd` instead).

*   **cni0**: In K8s, the bridge is usually named `cni0` (instead of `docker0`), managed by your network plugin.
*   **Inspection**: You can use `crictl inspect` to see the network settings of a container in a pod, similar to `docker inspect`.

---

> [!IMPORTANT]
> **Containerd vs Docker**: Docker is a full platform, while `containerd` is a lightweight runtime. Kubernetes now uses the **CRI (Container Runtime Interface)** to talk to runtimes, which then use the **CNI (Container Network Interface)** to handle the networking we just discussed.
