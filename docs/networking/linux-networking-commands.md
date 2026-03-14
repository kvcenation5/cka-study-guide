# Linux Networking Command Guide (`ip` tool)

The `ip` command (part of the `iproute2` suite) is the standard tool for managing network interfaces, addresses, and routing in modern Linux. It replaces the older `ifconfig` and `route` commands.

---

## 🛠️ 1. `ip link`: The Physical Layer (L2)

`ip link` is used to manage the network **interfaces** themselves. It doesn't care about IP addresses; it only cares if the "cable" is plugged in and what the hardware address is.

| Command | Description |
| :--- | :--- |
| **`ip link show`** | List all interfaces and their status (UP/DOWN, MAC, MTU). |
| **`ip link set eth0 up`** | Enable (bring up) an interface. |
| **`ip link set eth0 down`** | Disable (bring down) an interface. |
| **`ip link set eth0 mtu 1400`** | Change the Maximum Transmission Unit (useful for VPNs/Overlays). |

---

## 🖼️ 2. `ip addr`: The Protocol Layer (L3)

`ip addr` (or `ip a`) manages the **IP addresses** assigned to those interfaces. An interface can have multiple IP addresses simultaneously.

### Viewing Addresses
```bash
ip addr show     # Show all addresses for all interfaces
ip addr show eth0 # Show addresses for a specific interface
```

### Key Differences: `ip link` vs `ip addr`
*   **`ip link`**: Focuses on the **device** (Is it active? What is its hardware name?).
*   **`ip addr`**: Focuses on the **identity** (What is its IP? What is its subnet?).

---

## ➕ 3. `ip addr add`: Changing State

This is the command used to manually assign a new IP address to an interface.

### Syntax:
```bash
ip addr add <IP>/<Subnet> dev <Interface>
```

### Examples:
```bash
# Assign IP 192.168.1.50 with a 24-bit mask to eth0
ip addr add 192.168.1.50/24 dev eth0

# Remove an IP address
ip addr del 192.168.1.50/24 dev eth0
```

---

## 🗺️ 4. `ip route`: The Traffic Map

Once you have an interface and an IP, you need to know where to send data. `ip route` manages the **Routing Table**.

### Reading `ip route` Output
When you run `ip route`, each line tells a story:
`default via 192.168.1.1 dev eth0 proto dhcp metric 100`

*   **`default`**: This is the "Gateway of Last Resort."
*   **`via 192.168.1.1`**: Send the packet to this router.
*   **`dev eth0`**: Send it out through the `eth0` physical interface.
*   **`proto dhcp`**: This route was learned automatically via DHCP.

### `ip route add`: Adding Paths
Use this to tell Linux how to find subnets that aren't directly connected.

| Goal | Command |
| :--- | :--- |
| **Add Subnet Route** | `ip route add 10.244.1.0/24 via 192.168.1.11` |
| **Add Static Host** | `ip route add 8.8.8.8 via 192.168.1.1` |
| **Delete a Route** | `ip route del 10.244.1.0/24` |
| **Replace Default** | `ip route replace default via 192.168.1.254` |

---

## 📡 5. ARP (Address Resolution Protocol)

While `ip route` maps IP networks to other IP addresses, your network card ultimately needs a Physical Hardware Address (MAC) to send data over a local cable. This is what **ARP** does: it maps an IP address to a MAC address.

| Command / Tool | Description |
| :--- | :--- |
| **`arp`** | The legacy command to view the ARP cache/table. |
| **`ip neighbor`** (or **`ip n`**) | The modern `ip` equivalent to manage the ARP table. |

### How it works:
1. You say: "Ping 192.168.1.50".
2. Linux checks the routing table: "192.168.1.50 is on my local subnet!"
3. Linux checks the ARP table: "Do I know the MAC address for 192.168.1.50?"
4. If not, it broadcasts an ARP request.
5. The target responds: "I do! My MAC is DE:AD:BE:EF:00:00".
6. Linux saves this in the ARP table (`ip neighbor`) and sends the packet.

### Useful Commands:
```bash
ip neighbor show   # Show all known IP to MAC mappings
arp -a             # The older way to show the same thing
```

---

## 🧭 6. The Legacy `route` Command

Before the modern `ip` tool existed, `route` was the standard Linux command used to configure routing tables. You may still see it in older tutorials or environments.

*   **`route`**: Shows the routing table.
*   **`route -n`**: Shows the routing table in **numerical** format (doesn't try to translate IPs to hostnames via DNS, which is much faster). This is equivalent to `ip route show`.
*   **`route add default gw 192.168.1.1`**: The old way of setting a default gateway (Modern: `ip route add default via 192.168.1.1`).

> [!CAUTION]
> **Modern Practice**: The `route` command is considered deprecated. You should always use `ip route` when available, especially on the CKA exam!

---

## 🚩 7. CKA Exam Relevance

1.  **Troubleshooting Nodes**: If a node is `NotReady`, check `ip link` to see if the interface is `DOWN`.
2.  **CNI Verification**: CNIs like Flannel or Calico create virtual interfaces (e.g., `flannel.1`, `caliXXX`). Use `ip addr` to see if they received an IP.
3.  **Pod Connectivity**: If a pod can't talk to another node, check `ip route` to see if the CNI added the necessary routes for the Pod CIDR.

---

> [!TIP]
> **Shortcuts**: You don't have to type the full commands!
> - `ip a` = `ip addr`
> - `ip l` = `ip link`
> - `ip r` = `ip route`
