# Security in Kubernetes (CKA)

The Security section of the CKA exam covers approximately **25%** of the exam weightage. This section focuses on securing the cluster, managing access, and ensuring network security.

## Core Topics

### 1. Cluster Hardening
- Restricting access to the API server
- Securing Kubelet
- Using Network Policies to isolate traffic
- Securing etcd

### 2. Identity and Access Management (IAM)
- **Role-Based Access Control (RBAC)**: Roles, ClusterRoles, RoleBindings, and ClusterRoleBindings.
- **Service Accounts**: Managing non-human identities.
- **Certificates**: Managing TLS certificates for cluster components and users.

### 3. Application Security
- **Security Contexts**: Defining privilege and access control for Pods and Containers.
- **Secrets**: Storing sensitive information like passwords, tokens, and keys.
- **Admission Controllers**: Using ImagePolicyWebhook or other pluggable controllers.

### 4. Network Security
- Implementing **Network Policies** for Pod communication.

---
> [!TIP]
> Focus heavily on RBAC and Network Policies, as they are frequently tested in practical scenarios.
