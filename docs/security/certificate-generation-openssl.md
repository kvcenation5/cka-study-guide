# Certificate Generation with OpenSSL

In a production Kubernetes cluster, every component must communicate over a secure channel. This guide walks through the step-by-step process of generating certificates manually using **OpenSSL**, as described in the CKA curriculum.

---

## 🏗️ 1. The Root Certificate Authority (CA)
The CA is the root of trust for your entire cluster. Everything else is signed by this CA.

### Step 1: Generate Private Key
```bash
openssl genrsa -out ca.key 2048
```

### Step 2: Generate CSR (Certificate Signing Request)
The **Common Name (CN)** for the CA is usually `KUBERNETES-CA`.
```bash
openssl req -new -key ca.key -subj "/CN=KUBERNETES-CA" -out ca.csr
```

### Step 3: Self-Sign the CA
Since this is the root, it signs itself.
```bash
openssl x509 -req -in ca.csr -signkey ca.key -out ca.crt
```

---

## 👤 2. Admin User Certificate
The admin user needs administrative privileges. This is identified by the **Group (OU)** in the certificate.

### Step 1: Generate Key & CSR
*   **CN**: `admin` (or `kube-admin`)
*   **OU**: `system:masters` (This is the "magic" group that K8s recognizes for cluster-admin access).
```bash
openssl genrsa -out admin.key 2048
openssl req -new -key admin.key -subj "/CN=admin/O=system:masters" -out admin.csr
```

### Step 2: Sign with CA
```bash
openssl x509 -req -in admin.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out admin.crt
```

---

## ⚙️ 3. System Component Certificates
Components like the Scheduler and Controller Manager are "System" components and must be prefixed with `system:`.

| Component | Common Name (CN) |
| :--- | :--- |
| **Scheduler** | `system:kube-scheduler` |
| **Controller Manager** | `system:kube-controller-manager` |
| **Kube Proxy** | `system:kube-proxy` |

**Example for Scheduler:**
```bash
openssl genrsa -out scheduler.key 2048
openssl req -new -key scheduler.key -subj "/CN=system:kube-scheduler" -out scheduler.csr
openssl x509 -req -in scheduler.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out scheduler.crt
```

---

## 🖥️ 4. API Server Certificate (The "SAN" Case)
The API server goes by many names (IP address, `kubernetes`, `kubernetes.default.svc`, etc.). We must use **Subject Alternative Names (SAN)** to include all these names.

### Step 1: Create an OpenSSL Config File (`openssl.cnf`)
```ini
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = kubernetes
DNS.2 = kubernetes.default
DNS.3 = kubernetes.default.svc
DNS.4 = kubernetes.default.svc.cluster.local
IP.1 = 10.96.0.1
IP.2 = 192.168.1.10  # Master Node IP
```

### Step 2: Generate & Sign
```bash
openssl genrsa -out apiserver.key 2048
openssl req -new -key apiserver.key -subj "/CN=kube-apiserver" -config openssl.cnf -out apiserver.csr
openssl x509 -req -in apiserver.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out apiserver.crt -extensions v3_req -extfile openssl.cnf
```

---

## 📦 5. Kubelet Certificates
Each worker node needs two sets of certificates:
1.  **Server Certificate**: For the API server to talk to the Kubelet.
2.  **Client Certificate**: For the Kubelet to talk to the API server.

### Client Cert Format
*   **CN**: `system:node:<node-name>` (e.g., `system:node:node01`)
*   **OU**: `system:nodes`

```bash
openssl genrsa -out node01.key 2048
openssl req -new -key node01.key -subj "/CN=system:node:node01/O=system:nodes" -out node01.csr
openssl x509 -req -in node01.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out node01.crt
```

---

## 🏁 Summary Checklist
| Role | CN | OU | Note |
| :--- | :--- | :--- | :--- |
| **Admin** | `admin` | `system:masters` | Core Admin |
| **Scheduler** | `system:kube-scheduler` | N/A | System Component |
| **Controller** | `system:kube-controller-manager` | N/A | System Component |
| **Kubelet** | `system:node:<node_name>` | `system:nodes` | Node Identity |
| **API Server** | `kube-apiserver` | N/A | Needs SAN config |

---

> [!TIP]
> **Production vs. Exam**: In production, we often use `kubeadm` which handles this automatically (`kubeadm certs renew all`). However, understanding this manual flow is essential for troubleshooting broken clusters in the CKA exam!
