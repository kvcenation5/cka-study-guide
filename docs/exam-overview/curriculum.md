# CKA Exam Curriculum & Weightage (2025/2026)

The Certified Kubernetes Administrator (CKA) exam is performance-based and tests your ability to solve multiple tasks in a Kubernetes environment.

## Domain Weightage

| Domain | Weightage |
| :--- | :--- |
| **Troubleshooting** | 30% |
| **Cluster Architecture, Installation & Configuration** | 25% |
| **Services & Networking** | 20% |
| **Workloads & Scheduling** | 15% |
| **Storage** | 10% |

---

## Detailed Curriculum

### 1. Troubleshooting (30%)
*   **Troubleshoot clusters and nodes**: Identify and resolve issues with cluster nodes and infrastructure.
*   **Troubleshoot cluster components**: Diagnose problems with etcd, control plane components, and kubelet.
*   **Monitoring**: Monitor cluster and application resource usage.
*   **Logging**: Manage and evaluate container logs and output streams.
*   **Networking issues**: Troubleshoot services, DNS resolution (CoreDNS), and connectivity between pods/services.

### 2. Cluster Architecture, Installation & Configuration (25%)
*   **RBAC**: Manage Role-Based Access Control (Roles, ClusterRoles, Bindings).
*   **Installation**: Prepare infrastructure and install Kubernetes clusters using `kubeadm`.
*   **Lifecycle Management**: Manage cluster upgrades and maintenance.
*   **High Availability**: Implement and configure highly-available control planes.
*   **Tools**: Use **Helm** and **Kustomize** to install and manage cluster components.
*   **Extensions**: Understand extension interfaces (CNI, CSI, CRI).
*   **CRDs & Operators**: Manage Custom Resource Definitions and install/configure operators.

### 3. Services & Networking (20%)
*   **Host Networking**: Understand host networking configuration on cluster nodes.
*   **Pod Connectivity**: Understand and troubleshoot connectivity between Pods.
*   **Network Policies**: Define and enforce NetworkPolicies to secure traffic.
*   **Service Types**: Use ClusterIP, NodePort, and LoadBalancer types effectively.
*   **Gateway API**: Use the newer Gateway API for managing Ingress traffic.
*   **Ingress**: Configure Ingress controllers and Ingress resources.
*   **DNS**: Configure and troubleshoot CoreDNS.

### 4. Workloads & Scheduling (15%)
*   **Deployments**: Perform rolling updates and rollbacks.
*   **Secrets & ConfigMaps**: Use them to configure applications securely.
*   **Autoscaling**: Configure workload autoscaling (Horizontal Pod Autoscaler).
*   **Self-Healing**: Understand probes and replicas for robust deployments.
*   **Advanced Scheduling**: Configure Pod admission and scheduling using **PriorityClass**, Taints, Tolerations, and Node Affinity.
*   **StatefulSets**: Deploy and manage stateful applications.

### 5. Storage (10%)
*   **StorageClasses**: Implement StorageClasses and dynamic volume provisioning.
*   **Volume Configuration**: Configure volume types, access modes, and reclaim policies.
*   **PV & PVC**: Manage PersistentVolumes and PersistentVolumeClaims.
*   **Application Storage**: Configure applications with persistent storage.

---

## Key Updates for 2025
*   **Weightage Shift**: Troubleshooting (30%) and Cluster Architecture (25%) now make up the majority (55%) of the exam.
*   **New Tools**: **Helm**, **Kustomize**, and **Gateway API** are now part of the curriculum.
*   **Modern Scheduling**: **PriorityClass** is explicitly mentioned.
*   **Extensibility**: Focus on **CRDs** and **Operators**.
