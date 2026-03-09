# Networking Foundations: Switching & Routing

Before diving into Kubernetes networking, it is essential to understand how data moves between computers in a standard Linux environment.

---

## 🔌 1. Switching: Connecting the Local Network

A **Switch** connects multiple devices within the same local network (LAN). 

### How it works:
*   **MAC Addresses**: Every network interface has a hardware address (MAC).
*   **Packet Delivery**: When Device A wants to talk to Device B on the *same* network, it sends a packet directly to Device B's MAC address.
*   **Linux Command**: To see your local network interfaces and IP addresses:
    ```bash
    ip addr show
    ```

---

## 🛣️ 2. Routing: Connecting Different Networks

A **Router** connects different networks together. If you want to talk to a device that is *not* on your local subnet, you must go through a router.

### The Routing Table
Linux uses a routing table to decide where to send packets.
*   **The Command**: 
    ```bash
    ip route show
    ```
*   **Direct Routes**: If the destination is in your local subnet (e.g., `192.168.1.0/24`), the packet goes straight out.
*   **Remote Routes**: If the destination is unknown, it follows a specific gateway rule.

---

## 🚪 3. The Default Gateway

The **Default Gateway** is the "emergency exit" of your network configuration. If the Linux kernel doesn't have a specific route for a destination (like `google.com`), it sends the packet to the Default Gateway.

### Finding the Gateway:
```bash
ip route show | grep default
# Output: default via 192.168.1.1 dev eth0
```

### Adding a Gateway Manually:
```bash
ip route add default via 192.168.1.1
```

---

## 📊 Summary: The Path of a Packet

1.  **Is it local?** (Check IP + Subnet Mask).
    -   Yes: Send to the Switch (MAC delivery).
2.  **Is there a specific route?** (Check Routing Table).
    -   Yes: Send to the Gateway specified for that network.
3.  **None of the above?**
    -   Send to the **Default Gateway**.

---

> [!TIP]
> **Why this matters for CKA**:
> Kubernetes nodes are often on different subnets. The `kube-proxy` and the CNI (like Calico) manipulate these Linux routing tables to ensure that a Pod on Node A can reach a Pod on Node B across the physical network.
