# AuthN vs. AuthZ vs. TLS

Understanding the distinction between these three concepts is critical for the CKA exam. They form the "Three-Layer Defense" for any request entering the cluster.

---

## 1. TLS: The Secure Tunnel (Foundation)
Before any identification happens, the connection itself must be secure. TLS ensures that the data is encrypted and that the parties are who they say they are.

*   **Primary Goal:** Encryption & Identity Verification (at the transport level).
*   **When it happens:** At the moment of connection (Layer 4/7).

### Methods in Kubernetes:
1.  **Certificate Authority (CA):** The root of trust. The cluster usually has its own internal CA.
2.  **Server Certificates:** Used by the API server so clients know they aren't talking to an imposter.
3.  **Client Certificates:** Used by components (like `admin`, `kube-proxy`, `kubelet`) to prove their identity to the API server.
4.  **Mutual TLS (mTLS):** Both the server and the client verify each other's certificates (standard for internal K8s communication).

---

## 2. Authentication (AuthN): "Who are you?"
Once the secure tunnel is established, the API server needs to know your "Identity".

*   **Primary Goal:** Identity Verification.
*   **Success:** The user is logged in.
*   **Failure:** `401 Unauthorized`.

### Methods in Kubernetes:
| Method | Usage in CKA | Description |
| :--- | :--- | :--- |
| **X.509 Client Certs** | **High** | Files like `user.crt` and `user.key`. Common for admins. |
| **ServiceAccount Tokens** | **High** | JWT tokens mounted into Pods for automated access. |
| **Static Token File** | Low | A CSV file on the API server disk. (Requires restart to change). |
| **OIDC (Connect)** | Med | Integrating with external providers like Google, GitHub, or Okta. |
| **Webhook Token** | Med | Outsourcing authentication to an external service. |

---

## 3. Authorization (AuthZ): "What can you do?"
Now that we know *who* you are, do you have the *permission* to do what you're asking?

*   **Primary Goal:** Permission Enforcement.
*   **Success:** The action is performed.
*   **Failure:** `403 Forbidden`.

### Methods in Kubernetes:
1.  **RBAC (Role-Based Access Control):**
    *   **Roles / ClusterRoles:** Define *what* can be done (verbs: get, list, watch, create, delete).
    *   **RoleBindings / ClusterRoleBindings:** Link the user to the Role.
    *   *This is the main focus of the CKA exam.*
2.  **Node Authorization:** A specialized authorizer that limits Kubelets to only modifying their own Node and Pods on that Node.
3.  **ABAC (Attribute-Based Access Control):** Uses policies based on attributes. Hard to manage and requires API server restarts for changes.
4.  **Webhook:** Calls an external API to ask "Is this allowed?". Usually used by security tools (e.g., OPA Gatekeeper).
5.  **AlwaysDeny / AlwaysAllow:** Used for testing; usually not seen in production.

---

## At a Glance Comparison

| Feature | TLS | Authentication (AuthN) | Authorization (AuthZ) |
| :--- | :--- | :--- | :--- |
| **Question Asked** | "Is this connection safe?" | "Who are you?" | "Are you allowed to do this?" |
| **Error Code** | SSL/TLS Handshake Error | `401 Unauthorized` | `403 Forbidden` |
| **Example Tool** | OpenSSL / CFSSL | Certificates / Bearer Tokens | RBAC (Roles/Bindings) |
| **Dependency** | Happens First | Happens Second | Happens Third |

---
> [!IMPORTANT]
> In the CKA exam, if you get a **403 Forbidden**, your first thought should be **RBAC**. If you get an **SSL error** or **401**, check your **certificates** and **kubeconfig**.
