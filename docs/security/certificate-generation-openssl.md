# Manual Certificate Management (The Production Way)

This guide provides a comprehensive, step-by-step workflow for setting up all Kubernetes certificates from scratch using **OpenSSL**. This reflects how a new infrastructure team would set up a cluster manually (the "Hard Way").

---

## 🏗️ 1. The Core Infrastructure: Root CA
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

### 🌎 Distribution: Where does `ca.crt` go?
The `ca.crt` is the **same file** for everyone. It must be copied to every component so they can trust each other.

| Location | Path (Kubeadm) | Who uses it? |
| :--- | :--- | :--- |
| **Control Plane** | `/etc/kubernetes/pki/ca.crt` | API Server, Controller Manager, Scheduler |
| **Worker Nodes** | `/etc/kubernetes/pki/ca.crt` | Kubelet (to verify the API Server) |
| **User (You)** | `~/.kube/config` | Included in your `certificate-authority-data` |

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

### E. Kubelet (Worker Nodes - Per Node Identity)
Unlike other components, Kubelets **cannot** share the same certificate. Every node in your cluster must have its own unique set of files named after the node itself.

*   **Naming Rule**: Filename should be `node01.crt`, `node02.crt`, etc.
*   **CN (Common Name)**: Must be `system:node:<node-name>`.
*   **O (Organization)**: Must be `system:nodes`.

```bash
# 1. Create unique key for node01
openssl genrsa -out node01.key 2048

# 2. CSR with specific CN for node01
openssl req -new -key node01.key -subj "/CN=system:node:node01/O=system:nodes" -out node01.csr

# 3. Sign for node01
openssl x509 -req -in node01.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out node01.crt
```

> [!IMPORTANT]
> **Repeat this for every node!** If you have 3 nodes, you must repeat these steps 3 times, changing `node01` to `node02`, etc., in every command. Each node needs its own unique identity to join the cluster.

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

### How to Decode & Verify a Certificate?
Use `openssl` to peek inside the `.crt` file. This is the **number one skill** for debugging TLS issues in the CKA exam.

```bash
openssl x509 -in <filename>.crt -text -noout
```

**What to look for in the output?**
1.  **Subject**: Check the **CN** (Common Name). 
    -   Does it have the right prefix? (e.g., `system:node:name`)
    -   Does it have the right Group? (e.g., `O=system:masters`)
2.  **Issuer**: This MUST match your **Kubernetes CA**. If it says something else, the certificate was signed by the wrong key.
3.  **Validity**: Check the `Not Before` and `Not After` dates. If the current date is outside this range, the cluster will fail with "Certificate Expired" errors.
4.  **X509v3 Subject Alternative Name**: For the API Server, ensure it lists the IP addresses and DNS names you expect.

### How to check if a cert matches a key?
If they don't match, the component won't start. Compare the modulus hash:
```bash
openssl x509 -noout -modulus -in server.crt | openssl md5
openssl rsa -noout -modulus -in server.key | openssl md5
# The hashes MUST match exactly!
```

### Troubleshooting Checklist
1.  **Prefixes**: Ensure `system:node:` or `system:kube-scheduler` etc. are correct.
2.  **Groups (O)**: Ensure `system:masters` for admin and `system:nodes` for kubelets.

#### 🚨 Common Error: Etcd Handshake Failure
**Error**: `authentication handshake failed: x509: certificate signed by unknown authority`
**Context**: Look for the **Service Port** in the log (e.g., `Addr: "127.0.0.1:2379"`).

**How to identify the component?**
The "Generic" error becomes specific once you identify the port:

| Evidence (Port) | Component | Port Role |
| :--- | :--- | :--- |
| **2379** | **Etcd** | Server port for database requests. |
| **2380** | **Etcd** | Peer port for Etcd-to-Etcd sync. |
| **10250** | **Kubelet** | API port on worker nodes (logs/exec). |
| **10259** | **Scheduler** | Secure port for the Scheduler. |
| **10257** | **Controller** | Secure port for the Controller-Manager. |

**Cause**: The `--etcd-cafile` (or similar) is pointing to the wrong CA.
**Fix**: Match the CA flag to the CA used to sign that specific component's certificates.

---

---

> [!IMPORTANT]
> **Which is the "Admin Key"?**
> When people talk about the "Admin Key", they usually mean the **`ca.key`**. If you lose this, you can no longer sign new certificates or rotate existing ones. Keep it secure and offline if possible!

---

## 🚩 6. API Server Flags: Which CA goes where?

When configuring the `kube-apiserver` static pod, you will see multiple CA flags. This is a common source of confusion in the CKA exam.

### `.pem` vs `.crt`?
In Kubernetes, these are **the same**. They are both PEM-encoded Base64 files.

| Flag | Purpose | Usually points to... |
| :--- | :--- | :--- |
| **`--client-ca-file`** | Verifies **Clients** (You, Scheduler, Nodes) | `/etc/kubernetes/pki/ca.crt` |
| **`--etcd-ca-file`** | Verifies the **Etcd Server's identity** | `/etc/kubernetes/pki/etcd/ca.crt` |
| **`--kubelet-client-certificate`** | Used by API Server to **prove its identity** to Kubelets | `/etc/kubernetes/pki/apiserver-kubelet-client.crt` |

---

## 🛠️ 7. Component Configuration: Using the Certs

Once you have generated the certificates, you must tell the Kubernetes services where to find them.

### A. Kubelet Configuration (`/var/lib/kubelet/config.yaml`)
```yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  x509:
    clientCAFile: "/etc/kubernetes/pki/ca.crt"
tlsCertFile: "/var/lib/kubelet/pki/node01.crt"
tlsPrivateKeyFile: "/var/lib/kubelet/pki/node01.key"
```

### B. Kube-APIServer Connection to Etcd
```bash
kube-apiserver \
  --client-ca-file=/etc/kubernetes/pki/ca.crt \
  --etcd-cafile=/etc/kubernetes/pki/etcd/ca.crt \
  --etcd-certfile=/etc/kubernetes/pki/apiserver-etcd-client.crt \
  --etcd-keyfile=/etc/kubernetes/pki/apiserver-etcd-client.key \
  --etcd-servers=https://127.0.0.1:2379 \
  --tls-cert-file=/etc/kubernetes/pki/apiserver.crt \
  --tls-private-key-file=/etc/kubernetes/pki/apiserver.key
```

---

## 🔎 8. Real World Example: Minikube APIServer

Notice how the flags point to specific certificates for each task:

```yaml
spec:
  containers:
  - command:
    - kube-apiserver
    - --client-ca-file=/var/lib/minikube/certs/ca.crt # Cluster CA
    - --etcd-cafile=/var/lib/minikube/certs/etcd/ca.crt # Dedicated Etcd CA
    - --etcd-certfile=/var/lib/minikube/certs/apiserver-etcd-client.crt
    - --etcd-keyfile=/var/lib/minikube/certs/apiserver-etcd-client.key
    - --kubelet-client-certificate=/var/lib/minikube/certs/apiserver-kubelet-client.crt
    - --kubelet-client-key=/var/lib/minikube/certs/apiserver-kubelet-client.key
    - --tls-cert-file=/var/lib/minikube/certs/apiserver.crt # APIServer Identity
    - --tls-private-key-file=/var/lib/minikube/certs/apiserver.key
```

---

> [!TIP]
> **CKA Strategy**: If you are asked to fix a broken cluster where the API Server is down, check the **Static Pod manifest** at `/etc/kubernetes/manifests/kube-apiserver.yaml`. Often, a certificate path is mistyped!

---

## 📚 External References

- [Mumshad Mannambeth: Kubernetes The Hard Way - Tools](https://github.com/mmumshad/kubernetes-the-hard-way/tree/master/tools)

