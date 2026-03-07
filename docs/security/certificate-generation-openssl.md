# Manual Certificate Management (The Production Way)

This guide provides a comprehensive, step-by-step workflow for setting up all Kubernetes certificates from scratch using **OpenSSL**. This reflects how a new infrastructure team would set up a cluster manually (the "Hard Way").

---

## 🏛️ 1. The Core Infrastructure: Root CA
The **Root CA** consists of two files: `ca.key` (the private master key) and `ca.crt` (the public trust certificate). **All certificates in this guide are signed by this CA key.**

### Step-by-Step Generation:
1.  **Generate Private Key**: The "Admin Key" of the cluster's trust.
    ```bash
    openssl genrsa -out ca.key 2048
    ```
2.  **Generate CSR**:
    ```bash
    openssl req -new -key ca.key -subj "/CN=Kubernetes CA" -out ca.csr
    ```
3.  **Self-Sign**: Creates the `ca.crt` that every component needs to verify others.
    ```bash
    openssl x509 -req -in ca.csr -signkey ca.key -out ca.crt
    ```

---

## 🔁 2. The Standard Workflow for Components
For every component listed below (Admin, Scheduler, etc.), we follow the exact same **3-Step Loop**:
1.  **Create Private Key**: `openssl genrsa -out <name>.key 2048`
2.  **Create CSR**: `openssl req -new -key <name>.key -subj "/CN=<...>/O=<...>" -out <name>.csr`
3.  **Sign with Root CA**: `openssl x509 -req -in <name>.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out <name>.crt`

---

## 👤 3. Step-by-Step Component Setup

### A. Admin User (The Cluster Admin)
*   **Purpose**: Full control via `kubectl`.
*   **Naming**: `CN=kube-admin`, `O=system:masters`.
```bash
openssl genrsa -out admin.key 2048
openssl req -new -key admin.key -subj "/CN=kube-admin/O=system:masters" -out admin.csr
openssl x509 -req -in admin.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out admin.crt
```

### B. Kube-Controller-Manager
*   **Purpose**: Manage cluster state (Nodes, ReplicaSets).
*   **Naming**: `CN=system:kube-controller-manager`.
```bash
openssl genrsa -out controller-manager.key 2048
openssl req -new -key controller-manager.key -subj "/CN=system:kube-controller-manager" -out controller-manager.csr
openssl x509 -req -in controller-manager.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out controller-manager.crt
```

### C. Kube-Scheduler
*   **Purpose**: Decisions on where to place Pods.
*   **Naming**: `CN=system:kube-scheduler`.
```bash
openssl genrsa -out scheduler.key 2048
openssl req -new -key scheduler.key -subj "/CN=system:kube-scheduler" -out scheduler.csr
openssl x509 -req -in scheduler.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out scheduler.crt
```

### D. Etcd Server (The Database)
*   **Purpose**: Store cluster data.
*   **Naming**: `CN=etcd-server`.
```bash
openssl genrsa -out etcd.key 2048
openssl req -new -key etcd.key -subj "/CN=etcd-server" -out etcd.csr
openssl x509 -req -in etcd.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out etcd.crt
```

### E. Kubelet (Worker Nodes)
*   **Purpose**: Node identity to communicate with API server.
*   **Naming**: `CN=system:node:<node-name>`, `O=system:nodes`.
```bash
openssl genrsa -out node01.key 2048
openssl req -new -key node01.key -subj "/CN=system:node:node01/O=system:nodes" -out node01.csr
openssl x509 -req -in node01.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out node01.crt
```

### F. Kube-Proxy
*   **Purpose**: Network rule management on nodes.
*   **Naming**: `CN=system:kube-proxy`.
```bash
openssl genrsa -out kube-proxy.key 2048
openssl req -new -key kube-proxy.key -subj "/CN=system:kube-proxy" -out kube-proxy.csr
openssl x509 -req -in kube-proxy.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out kube-proxy.crt
```

### G. Kube-API Server (Complex Setup)
The API server needs a **Server Certificate** with multiple SANs (Subject Alternative Names).

1.  **Create Config (`openssl.cnf`)**:
    ```ini
    [alt_names]
    DNS.1 = kubernetes
    DNS.2 = kubernetes.default
    DNS.3 = kubernetes.default.svc
    IP.1 = 10.96.0.1  # Cluster Service IP
    IP.2 = 192.168.1.10 # Master Host IP
    ```
2.  **Generate & Sign**:
    ```bash
    openssl genrsa -out apiserver.key 2048
    openssl req -new -key apiserver.key -subj "/CN=kube-apiserver" -config openssl.cnf -out apiserver.csr
    openssl x509 -req -in apiserver.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out apiserver.crt -extensions v3_req -extfile openssl.cnf
    ```

---

## 🔗 4. How the Connections Work (mTLS)

In Kubernetes, we use **Mutual TLS (mTLS)**. This means both the server and the client must present certificates signed by the **same CA**.

### Client vs. Server Matrix
| Role | Component | Needs Server Cert? | Needs Client Cert? |
| :--- | :--- | :---: | :---: |
| **Server** | API Server | ✅ (Faces everyone) | ✅ (Calls Etcd/Kubelet) |
| **Server** | Etcd | ✅ (Faces API Server) | ❌ |
| **Server** | Kubelet | ✅ (Faces API Server) | ✅ (Calls API Server) |
| **Client** | Admin (You) | ❌ | ✅ |
| **Client** | Scheduler | ❌ | ✅ |
| **Client** | Controller | ❌ | ✅ |
| **Client** | Kube-Proxy | ❌ | ✅ |

---

## 🔍 5. Verification & Troubleshooting

### How to verify a certificate?
Use `openssl` to see the internal details (CN, Dates, Expiry):
```bash
openssl x509 -in <filename>.crt -text -noout
```

### How to check if a cert matches a key?
If they don't match, the component won't start. Compare the modulus hash:
```bash
openssl x509 -noout -modulus -in server.crt | openssl md5
openssl rsa -noout -modulus -in server.key | openssl md5
# The hashes MUST match!
```

### Troubleshooting: "Unauthorized" or "Bad Certificate"
1.  **Check the CN**: Does it start with `system:`? If not, the RBAC rules won't recognize it.
2.  **Check the Group (O)**: Is the Admin cert in `system:masters`? Are the Nodes in `system:nodes`?
3.  **Check the CA**: Did you sign the `.crt` using the same `ca.key` that is configured in the API Server's `--client-ca-file` flag?

---

> [!IMPORTANT]
> **Which is the "Admin Key"?**
> When people talk about the "Admin Key", they usually mean the **`ca.key`**. If you lose this, you can no longer sign new certificates or rotate existing ones. Keep it secure and offline if possible!
