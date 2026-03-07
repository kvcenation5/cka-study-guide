# Kubernetes Certificate API Management

In a production cluster, you don't always want to manually run OpenSSL commands on the Master node to sign certificates. Kubernetes provides a built-in **Certificate API** to automate and audit the certificate request and signing process.

---

## 🏗️ 1. Core Concepts

### What is a Root Certificate?
The **Root Certificate** (e.g., `ca.crt`) is the "Trust Anchor" of your entire cluster. 
*   It is the only certificate that is **self-signed**.
*   Every other certificate in the cluster is "derived" from this one.
*   If a client trusts the Root Certificate, it will automatically trust any certificate signed by it.

### What is a CA Server?
A **CA (Certificate Authority) Server** is simply a machine or service that holds the Root CA private key (`ca.key`) and runs software to sign incoming Certificate Signing Requests (CSRs). 
*   In Kubernetes, the **Master Node** effectively acts as the CA Server by default because it holds the `ca.key`.

### What is Base64?
Base64 is NOT encryption; it is **encoding**. It turns binary data (like a private key) into plain text that can be safely put into YAML files or environment variables.
*   **Kubectl Command**: `echo "mydata" | base64` (Encode)
*   **Kubectl Command**: `echo "bXlkYXRhCg==" | base64 --decode` (Decode)

---

## 🔄 2. The Certificate API Workflow

The API allows users to request certificates without needing direct access to the `ca.key` file.

| Step | Action | Responsibility |
| :--- | :--- | :--- |
| **1** | Generate a private key and a standard CSR file. | User/Developer |
| **2** | Create a Kubernetes `CertificateSigningRequest` (CSR) object. | User/Developer |
| **3** | List and review the pending CSR. | Cluster Admin |
| **4** | Approve the CSR. | Cluster Admin |
| **5** | Sign the certificate using the CA key. | **Kube-Controller-Manager** |
| **6** | Download the signed certificate from the API. | User/Developer |

---

## 🛠️ 3. Hands-on: Managing a CSR

### A. Create the standard CSR (OpenSSL)
```bash
# Generate key
openssl genrsa -out john.key 2048
# Generate CSR
openssl req -new -key john.key -subj "/CN=john" -out john.csr
```

### B. Submit to Kubernetes API
You must take the content of `john.csr`, encode it in **Base64**, and put it into the YAML.

```bash
cat john.csr | base64 | tr -d '\n'
```

**CSR YAML (`john-csr.yaml`):**
```yaml
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: john-developer
spec:
  request: <BASE64_CONTENT_HERE>
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - client auth
```

### C. Admin Commands (Review & Approve)
Admin sees a new request:
```bash
kubectl get csr
```

Admin reviews the details (CN, Groups):
```bash
kubectl describe csr john-developer
```

Admin Approves:
```bash
kubectl certificate approve john-developer
```

### D. Retrieve the Certificate
Once approved, the certificate is saved back into the CSR object.
```bash
kubectl get csr john-developer -o jsonpath='{.status.certificate}' | base64 --decode > john.crt
```

---

## ⚙️ 4. The Controller Manager's Role
The **Kube-Controller-Manager** is the "engine" behind this API. It runs two specific controllers:
1.  **CSR Approver**: Automatically approves certain system requests (like Kubelet node certificates).
2.  **CSR Signer**: Watches for approved CSR objects, takes the `ca.key` from the master disk, signs the request, and updates the object's `.status.certificate` field.

---

## 🔐 5. Security: Where to store certificates?

### Is it okay to place certificates on the Master Node?
**Yes**, by default, Kubernetes stores them in `/etc/kubernetes/pki/` on the master node. 
*   **Pros**: Easy management, Kube-Controller-Manager can reach them easily.
*   **Cons**: If the Master node is compromised, the attacker has the "Keys to the Kingdom" (`ca.key`).

### How to keep the CA file safe?
1.  **Restrict Access**: Use Linux permissions (`chmod 600`) so only `root` can read the `.key` files.
2.  **External CA**: In high-security environments, the `ca.key` is kept in a **HSM (Hardware Security Module)** or an offline "Air-gapped" server, and Kubernetes is configured to talk to an external CA API.

---

> [!TIP]
> **CKA Exam Shortcut**: You will almost certainly be asked to troubleshoot or approve a CSR. Remember: `kubectl get csr` -> `kubectl certificate approve <name>`.
