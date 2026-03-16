# Docker Networking: The Predecessor to CNI

Kubernetes networking evolved from patterns popularized by Docker. Understanding Docker's networking modes helps clarify why Kubernetes chose its specific Networking Model, and how things work under the hood.

Let's start by looking at a single Docker host (a server with Docker installed), which has a physical ethernet interface (`eth0`) connecting to the local network (e.g., `192.168.1.1`). When you run a container, you have different networking options to choose from.

---

## 🛡️ 1. The Isolated Option: `none` Network

The container is fully isolated and is **not attached to any network**.

*   **Behavior**: It only has a loopback interface (`localhost`). The container cannot reach the outside world, and no one from the outside world can reach the container.
*   **Use-case**: Batch processing jobs that don't need network access.
*   **Multiple Containers**: If you run multiple containers on the `none` network, they are completely isolated from each other.

---

## ⚡ 2. The Direct Option: `host` Network

In Host Mode, there is **no network isolation** between the host and the container. The container shares the host's networking namespace.

*   **Command**: `docker run --network host nginx`
*   **Pros**: High performance (no NAT overhead).
*   **Cons**: Port collisions. If you deploy a web application listening on port `80` in the container, it immediately binds to port `80` on the host. If you try to run a second container on port `80`, it will fail because two processes cannot listen on the same port at the same time.

---

## 🏗️ 3. The Default: `bridge` Network (`docker0`)

When Docker is installed, it automatically creates an internal private network called `bridge`. This is the network that containers attach to by default.

### Docker Bridge Architecture

```mermaid
graph TD
    subgraph "Docker Host (e.g. 192.168.1.50)"
        eth0[eth0 Physical Interface<br>192.168.1.50]
        iptables[iptables (NAT/Port Forwarding)<br>Ex: Port 8080 -> 80]
        docker0[docker0 Bridge<br>172.17.0.1/16]
        
        eth0 <--> iptables
        iptables <--> docker0
        
        subgraph "Container 1 Namespace"
            veth1[veth inside container<br>172.17.0.2:80]
        end
        
        subgraph "Container 2 Namespace"
            veth2[veth inside container<br>172.17.0.3]
        end
        
        docker0 <-->|veth link| veth1
        docker0 <-->|veth link| veth2
    end
    
    Internet((External User)) -->|Hits 192.168.1.50:8080| eth0

    classDef host fill:#fffde7,stroke:#fbc02d;
    classDef bridge fill:#e1f5fe,stroke:#0288d1;
    classDef container fill:#e8f5e9,stroke:#388e3c;
    classDef firewall fill:#ffebee,stroke:#d32f2f;
    
    class docker0 bridge;
    class veth1,veth2 container;
    class iptables firewall;
```

### How `docker0` Works (Under the Hood):
1.  **The Virtual Switch**: Docker creates a Linux Bridge interface on the host named `docker0`. (You can see this by running `ip link`). Internally, Docker uses a technique similar to `ip link add type bridge`.
2.  **The IP Subnet**: The `docker0` bridge is assigned an IP address, typically `172.17.0.1` (the gateway for the network `172.17.0.0/16`).
3.  **The Network Namespace**: Whenever a container is created, Docker creates a brand new **network namespace** for it. (You can view the namespace via `docker inspect <container>`).
4.  **The Virtual Cable (Veth Pair)**: Docker creates a virtual cable with two interfaces (a `veth` pair). 
     - One end goes inside the container's namespace and gets an IP (e.g., `172.17.0.3`).
     - The other end attaches to the `docker0` bridge on the host.
5.  **Interface Pair Numbers**: If you run `ip link`, you can identify these pairs by their numbers. They are created in odd/even pairs (e.g., link `9` on the host goes to link `10` in the container; `11` goes to `12`, etc.).

Now, all containers on the `docker0` bridge can communicate with each other inside the host!

---

## 🚪 4. Port Mapping (Port Publishing)

Since containers on the `bridge` network live in a private subnet (`172.17.0.x`), they are invisible to the outside world. External users (outside the Docker host) cannot ping or `curl` the container's private IP.

To allow external access, Docker uses **Port Mapping**.
```bash
docker run -p 8080:80 nginx
```
This tells Docker to map port `8080` on the Docker host to port `80` inside the container. External users can now hit `<Host-IP>:8080` to see the webpage.

### How Docker Forwards Traffic (iptables NAT):
We don't need to guess how Docker does this. Just like how we would manually forward traffic using the Linux firewall, Docker uses **iptables**.

1.  Docker creates an entry in the **NAT table** of `iptables`.
2.  It appends a rule to the `PREROUTING` chain (specifically within a chain called `DOCKER`).
3.  The rule says: *"Any traffic hitting the Host's IP on port `8080`, change the destination IP to `172.17.0.3` (container IP) and the destination port to `80`."*
4.  You can actually see these rules by running `iptables -t nat -L DOCKER`.

---

## 🔗 5. How Docker differs from Kubernetes

| Feature | Docker (Default) | Kubernetes |
| :--- | :--- | :--- |
| **Connectivity** | Containers on different hosts cannot talk to each other without NAT/VPN. | **All Pods** can talk to all other Pods without NAT (Fundamental Rule). |
| **IP Per Pod** | Containers share IPs if in the same Compose file; otherwise, individual. | Every Pod gets its own **Cluster-Unique IP**. |
| **Discovery** | Uses internal DNS or file-based `links`. | Uses **CoreDNS** and **Services**. |

---

## 🚩 6. CKA Context: `crictl` and `cni0`

In a modern Kubernetes cluster, you might not even use Docker (using `containerd` instead via the CRI - Container Runtime Interface).

*   **cni0**: In K8s, the bridge is usually named `cni0` (instead of `docker0`), managed by your Container Network Interface (CNI) plugin (like Flannel or Calico).
*   **Inspection**: You can use `crictl inspect` to see the network settings of a container in a pod, similar to `docker inspect`.
*   **The Next Layer**: Kubernetes replaces Docker's complex NAT-based port forwarding with something much cleaner—**Services** and `kube-proxy`!
