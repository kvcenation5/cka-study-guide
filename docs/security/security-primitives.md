# Kubernetes Security Primitives

Kubernetes security is built on multiple layers of protection. Understanding how a request gets from a user (or service) to the API server and eventually to a resource is fundamental for the CKA exam.

## 1. The Request Lifecycle (The Three Pillars)

Every request to the Kubernetes API server goes through three major stages:

### A. Authentication (Who are you?)
Kubernetes does not have a built-in "User" database. It relies on internal **ServiceAccounts** or external methods for human users:
- **Files/Tokens:** Static Token File, Bootstrap Tokens.
- **Certificates:** Client Certificates (X.509).
- **External Providers:** LDAP, OIDC (Google, GitHub), Keystone.

> [!NOTE]
> If a request fails authentication, it returns a **401 Unauthorized** error.

### B. Authorization (What can you do?)
Once identified, Kubernetes checks if the user has permission to perform the specific action (verb) on the resource.
- **RBAC (Role-Based Access Control):** The most common method (used in CKA).
- **ABAC (Attribute-Based Access Control):** Policy-based, less common.
- **Node Authorization:** Specifically for Kubelets.
- **Webhook:** External authorization service.

> [!NOTE]
> If a request fails authorization, it returns a **403 Forbidden** error.

### C. Admission Control (Policy Enforcement)
Even if you are authorized, an Admission Controller can still block or modify your request based on cluster-wide policies.
- **Mutating Admission Controllers:** Modify the request (e.g., inject a sidecar).
- **Validating Admission Controllers:** Check the request against rules (e.g., check if the image comes from a trusted registry).

---

## 2. Communication Security (TLS)

By default, all communication between Kubernetes components is encrypted using **TLS**.
- **Control Plane components** (API Server, Scheduler, Controller Manager) use TLS to talk to each other.
- **Kubelet** uses TLS to talk to the API Server.
- **etcd** should be secured with its own set of certificates.

## 3. Pod Security Primitives

Beyond the API server, security applies to the workloads themselves:
- **Security Contexts:** Define user IDs, group IDs, and capabilities at the Pod or Container level.
- **Secrets:** Store sensitive data (though they are only Base64 encoded by default—not encrypted at rest unless configured).
- **Network Policies:** Control the flow of traffic between Pods (Layer 3/4 Firewall).

---

## 4. Host Level Security
- **Node Hardening:** Disabling unused services.
- **SSH Access:** Restricting access to the underlying nodes.
- **Kubelet Security:** Disabling anonymous access and ensuring only authorized API requests are processed.
