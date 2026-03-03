# TLS Certificates in Kubernetes

TLS (Transport Layer Security) is the foundation of security in Kubernetes. Every component communicates over HTTPS, and most use **Mutual TLS (mTLS)** to verify each other's identity.

---

## 🏗️ 1. The Hierarchy of Trust
Kubernetes typically uses multiple "Trust Domains" (CAs):
1.  **Cluster CA:** Signs certs for API Server, Kubelets, and Scheduler.
2.  **Etcd CA:** Signs certs specifically for Etcd communication.
3.  **Front Proxy CA:** Signs certs for the Aggregation Layer (API extensions).

---

## 📂 2. Certificate Locations (Kubeadm)
On a control plane node installed with `kubeadm`, all certificates are stored in:
`/etc/kubernetes/pki/`

| Component | Path | Description |
| :--- | :--- | :--- |
| **CA Root** | `ca.crt`, `ca.key` | The primary root certificate. |
| **API Server** | `apiserver.crt`, `apiserver.key` | Used by the API server to identify itself. |
| **Etcd** | `etcd/ca.crt`, `etcd/healthcheck-client.crt` | Etcd-specific security. |
| **Kubeconfig** | `/etc/kubernetes/admin.conf` | Contains the `client-certificate-data`. |

---

## 🔍 3. Inspecting Certificates (CKA Must-Know)
Use `openssl` to check if a certificate is valid and see its "Subject" or "Expiry".

### Check Expiration:
```bash
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -text -noout | grep Not
```

### Check Common Name (CN):
```bash
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -text -noout | grep Subject:
```

### Using Kubeadm (Easier):
```bash
kubeadm certs check-expiration
```

---

## 📝 4. Creating a New User (CSR Workflow)
In the CKA exam, you might be asked to grant a new user access.

### Step 1: Generate Private Key & CSR
```bash
openssl genrsa -out john.key 2048
openssl req -new -key john.key -subj "/CN=john/O=developers" -out john.csr
```

### Step 2: Create a Kubernetes CSR Object
```yaml
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: john-developer
spec:
  request: <BASE64_ENCODED_CSR_HERE>
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - client auth
```
*(Use `cat john.csr | base64 | tr -d '\n'` to get the request data)*

### Step 3: Approve the Request
```bash
kubectl get csr
kubectl certificate approve john-developer
```

### Step 4: Extract the Certificate
```bash
kubectl get csr john-developer -o jsonpath='{.status.certificate}' | base64 -d > john.crt
```

---

## 🔧 5. Troubleshooting Scenarios

### Scenario: "Unable to connect to the server: x509: certificate has expired"
1.  Run `kubeadm certs check-expiration`.
2.  If expired, run `kubeadm certs renew all`.
3.  Restart control plane components (API server, Scheduler, Controller Manager).

### Scenario: "Broken Kubelet"
Kubelets often use **Client Certificate Rotation**. If a kubelet can't join, check if there's a pending CSR:
```bash
kubectl get csr
# Look for 'node-csr-...' and approve if necessary
```

---

> [!TIP]
> **Exam Strategy**: Don't memorize the CSR YAML perfectly. Use `kubectl explain csr.spec` or search for "CSR" in the official K8s documentation during the exam!
