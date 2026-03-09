# DNS: From Linux to CoreDNS

DNS (Domain Name System) is the phonebook of the internet. In Kubernetes, DNS is the backbone of "Service Discovery"—how your front-end pod finds your back-end pod without knowing its IP.

---

## 🐧 1. DNS Configuration in Linux

Every Linux system (including Kubernetes Nodes and Pods) uses a specific file to identify where to send DNS queries.

### `/etc/resolv.conf`
This is the primary configuration file.
```text
nameserver 8.8.8.8
search my-company.com svc.cluster.local
options ndots:5
```
*   **nameserver**: The IP address of the DNS server to query.
*   **search**: A list of domains to append to "naked" hostnames (e.g., if you ping `db`, Linux tries `db.my-company.com` first).

### `/etc/hosts`
The static "local phonebook." Linux checks this file *before* querying a DNS server.
```text
127.0.0.1   localhost
10.0.0.51   node-01
```

---

## 🧬 2. Intro to CoreDNS

**CoreDNS** is the official cluster-wide DNS server for Kubernetes (standard since v1.13).

### How it works in K8s:
1.  **The Service**: CoreDNS runs as a Deployment in the `kube-system` namespace, usually fronted by a service named `kube-dns`.
2.  **Pod Configuration**: When a Pod starts, the Kubelet automatically injects the IP of the `kube-dns` service into the Pod's `/etc/resolv.conf`.
3.  **Discovery**: When you create a Service named `web-service`, CoreDNS automatically creates a record: `web-service.default.svc.cluster.local`.

### The Corefile
CoreDNS is configured via a ConfigMap named `coredns` in `kube-system`. It uses a domain-specific language called the **Corefile**.
```text
.:53 {
    errors
    health
    kubernetes cluster.local in-addr.arpa ip6.arpa {
       pods insecure
       fallthrough in-addr.arpa ip6.arpa
    }
    forward . /etc/resolv.conf
    cache 30
}
```
*   **kubernetes**: Plugs into the K8s API to learn about new Services/Pods.
*   **forward**: If the hostname isn't a K8s service (e.g., `google.com`), it forwards the query to the node's upstream DNS.

---

## 🚩 3. CKA Troubleshooting DNS

*   **Check the Pod**: Is `/etc/resolv.conf` correct inside your pod?
    `kubectl exec <pod> -- cat /etc/resolv.conf`
*   **Check CoreDNS Logs**: Is CoreDNS failing to talk to the API?
    `kubectl logs -n kube-system -l k8s-app=kube-dns`
*   **Check the Service**: Does the `kube-dns` service have an IP?
    `kubectl get svc -n kube-system`

---

> [!IMPORTANT]
> **ndots:5**: This common K8s setting means that any hostname with fewer than 5 dots (like `my-app.prod`) will be treated as relative and have the search domains appended. This can sometimes cause latency if not understood properly.
