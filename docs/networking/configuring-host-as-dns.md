# Configuring a Host as a DNS Server (CoreDNS)

In large environments with many hostnames and IP addresses, managing `/etc/hosts` files on every single machine becomes impossible. Instead, we configure all hosts to point to a central **DNS Server**. 

This guide demonstrates how to configure a dedicated Linux host to act as a DNS server using **CoreDNS**, the standard DNS server for Kubernetes.

---

## 📥 1. Installing CoreDNS (The Traditional Route)

While CoreDNS is often run as a Docker container, you can also run it directly as a binary on a Linux host.

First, download the pre-compiled binary from the official GitHub releases page and extract it:

```bash
# 1. Download the tarball
curl -LO https://github.com/coredns/coredns/releases/download/v1.12.4/coredns_1.12.4_linux_amd64.tgz

# 2. Extract the archive
tar -zxf coredns_1.12.4_linux_amd64.tgz

# This gives you a single executable file named `coredns`
```

If you simply run `./coredns`, the server will start. By default, it listens on **port 53** (the standard port for a DNS server).

---

## ⚙️ 2. Configuring IP to Hostname Mappings

A DNS server needs to know what names map to what IPs. CoreDNS is highly modular and uses **plugins** to fetch this data. There are many ways to configure this, but we will start with the simplest: using the server's own `/etc/hosts` file.

### Step 1: Populate the `/etc/hosts` file
Add your custom DNS entries to the DNS server's `/etc/hosts` file:
```text
192.168.1.10   web-server-prod
192.168.1.20   db-server-prod
```

### Step 2: Create the `Corefile`
CoreDNS loads its configuration from a file specifically named `Corefile`. Create this file in the same directory as the binary.

```text
# Listen on all incoming traffic on port 53
.:53 {
    # Plugin 1: Use /etc/hosts to resolve hostnames
    hosts /etc/hosts {
        reload 1m     # Reload the file every 1 minute if it changes
        fallthrough   # If a name isn't in /etc/hosts, pass it to the next plugin
    }
 
    # Plugin 2: Forward unmatched queries to the host's upstream resolver
    forward . /etc/resolv.conf {
       max_concurrent 1000
    }
    
    # Utilities
    cache 30          # Cache responses for 30 seconds
    log               # Log all queries
    errors            # Log errors
}
```

### Step 3: Run CoreDNS
When you run `./coredns`, it will read the `Corefile` and start serving the IPs and names you specified in `/etc/hosts`. If someone asks for `google.com` (which isn't in `/etc/hosts`), the `forward` plugin sends it to the internet to find the answer.

---

## 🔗 3. The Kubernetes Connection

CoreDNS is powerful because of its plugin system. While the `hosts` plugin is great for a standalone server, Kubernetes uses a specific `kubernetes` plugin. 

Instead of reading a static text file, the `kubernetes` plugin talks directly to the Kubernetes API to translate `Services` and `Pods` into IP addresses dynamically.

Read more about CoreDNS and Kubernetes integration here:
*   [Kubernetes DNS-Based Service Discovery Specification](https://github.com/kubernetes/dns/blob/master/docs/specification.md)
*   [CoreDNS Kubernetes Plugin Documentation](https://coredns.io/plugins/kubernetes/)
