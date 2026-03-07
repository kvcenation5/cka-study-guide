# Authorization Mechanisms in Kubernetes

Authorization happens **after** authentication. Once the API Server knows "Who" you are, it must decide if you are allowed to perform the specific action (Verb) on the specific resource.

---

## 🏗️ 1. How the Authorization Chain Works
Kubernetes checks authorization using a "Chain of Authorizers."
*   The API Server checks each method in order.
*   If any method says **"Allow"**, the request is approved.
*   If a method doesn't have an opinion, it passes it to the next one.
*   If all methods finish and none said "Allow", the request is **Denied (403 Forbidden)**.

---

## 🛠️ 2. The Four Primary Mechanisms

### 1. RBAC (Role-Based Access Control)
This is the **Standard** for Kubernetes. It uses Roles and Bindings to match users to permissions.
*   **Pros**: Very granular, manageable via `kubectl`, no API server restarts needed.
*   **Usage**: 99% of production clusters.
*   **CKA Focus**: **High**. You must master this.

### 2. ABAC (Attribute-Based Access Control)
ABAC uses local files on the Master node to define policies.
*   **Logic**: "User X can do Y on Namespace Z."
*   **Cons**: Extremely difficult to manage at scale. You must SSH into the Master and **restart the API Server** every time you change a permission.
*   **Usage**: Rare.

### 3. Node Authorization
This is a specialized authorizer specifically for **Kubelets**.
*   **Purpose**: It ensures a compromised worker node cannot steal secrets from other nodes.
*   **Logic**: It only allows a Kubelet to access Pods, Secrets, and ConfigMaps that are actually scheduled on **that specific node**.
*   **Identified by**: Validated against the `system:node:<node-name>` CN in the Kubelet certificate.

### 4. Webhook Authorization
This sends an HTTP POST request to an external service to ask for a decision.
*   **Usage**: Used by admission controllers and policy engines like **Open Policy Agent (OPA)** or **Kyverno**.
*   **Pros**: Allows for complex, external logic (e.g., "Only allow deletes during business hours").

---

## ⚙️ 3. Configuring Authorizers

The list of active authorization mechanisms is defined by the `--authorization-mode` flag in the `kube-apiserver` manifest.

**Example: Default Kubeadm Setup**
```bash
--authorization-mode=Node,RBAC
```
*In this setup, the API Server first checks if the request is from a Node (using Node Authorizer), and if not, it checks the RBAC rules.*

---

## 🔍 4. Specialized Authorizers

### AlwaysAllow / AlwaysDeny
*   **AlwaysAllow**: bypasses all security. Disastrous for production, used only for local development/testing.
*   **AlwaysDeny**: rejects everything. Useful for testing the failure behavior of the chain.

---

## 📊 Summary Comparison

| Mechanism | Configuration Location | Dynamic? | Scope |
| :--- | :--- | :---: | :--- |
| **RBAC** | etcd (via YAML) | ✅ Yes | Namespace or Cluster |
| **ABAC** | Local Policy File | ❌ No | Policy-based |
| **Node** | Hardcoded logic | ✅ Yes | Kubelet-specific |
| **Webhook** | External Service | ✅ Yes | External Logic |

---

> [!TIP]
> **CKA Strategy**: If you are troubleshooting a `403 Forbidden` error and your RBAC looks perfect, check the API Server flags. If someone accidentally removed `RBAC` from the `--authorization-mode` flag, your Roles and Bindings will be completely ignored!
