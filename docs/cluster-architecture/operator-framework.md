# Operator Framework

The **Operator Framework** is a set of open-source tools designed to simplify the development, management, and discovery of Kubernetes Operators. It helps turn human operational knowledge (backups, updates, scaling) into automated code.

---

## 🏗️ 1. Core Components

The framework is built on three pillars that handle the complete lifecycle of an operator.

### 🛠️ A. Operator SDK
The developer toolkit for building operators.
*   **Multiple Languages**: Build operators using **Go**, **Ansible**, or **Helm**.
*   **Scaffold**: Generates the project structure, Dockerfiles, and Kubernetes manifests automatically.
*   **Testing**: Includes a testing framework to validate your operator before deployment.

### 🔄 B. Operator Lifecycle Manager (OLM)
The control plane for managing operators in your cluster.
*   **Updates**: Automatically upgrades operators when a new version is published.
*   **Dependency Management**: Ensures that if your operator needs another operator (e.g., a Prometheus operator for monitoring), it is installed first.
*   **RBAC Control**: Manages the permissions of the operators to ensure they only have access to what they need.

### 🏪 C. OperatorHub.io
A community registry for discovering operators.
*   **Selection**: A web-based portal (and integrated into OpenShift) where you can find certified and community-contributed operators for databases, monitoring, security, etc.
*   **Standard Approval**: Operators on Hub.io go through a basic "Capability Level" check.

---

## 📊 2. Operator Capability Levels

The framework defines five levels of automation maturity for operators. Understanding these helps you choose the right operator for your needs.

| Level | Name | Description |
| :--- | :--- | :--- |
| **I** | Basic Install | Automates application provisioning and configuration. |
| **II** | Seamless Upgrades | Automates patches and minor version upgrades. |
| **III** | Full Lifecycle | Handles backup/restore, storage management, and disaster recovery. |
| **IV** | Deep Insights | Provides metrics, alerts, and performance analysis. |
| **V** | Auto Pilot | Fully autonomous: Scaling, auto-healing, and tuning based on metrics. |

---

## 🛠️ 3. Quickstart Workflow

Using the Operator SDK to create a Go-based operator:

1.  **Initialize**:
    ```bash
    operator-sdk init --domain mycompany.io --repo github.com/my-org/my-op
    ```
2.  **Create API**:
    ```bash
    operator-sdk create api --group web --version v1 --kind Website --resource --controller
    ```
3.  **Implement Logic**: Edit `internal/controller/website_controller.go` to define what happens when a `Website` resource is created.
4.  **Deploy**:
    ```bash
    make docker-build docker-push IMG=my-org/my-op:v1
    make deploy IMG=my-org/my-op:v1
    ```

---

## 🚩 4. CKA Exam Perspective

*   **Recognition**: You should know that the **Operator Framework** is the standard way to build professional operators.
*   **OLM Identification**: If you see resources in your cluster like `Subscription`, `InstallPlan`, or `ClusterServiceVersion (CSV)`, these belong to the **OLM**.
    *   `kubectl get csv -A`
*   **Tool Choice**: If an exam question asks "What tool would you use to build an operator from a Helm chart?", the answer is the **Operator SDK**.

---

> [!TIP]
> **Helm vs Ansible vs Go**:
> - Use **Helm** for simple application packaging.
> - Use **Ansible** if you already have Ansible playbooks for your apps.
> - Use **Go** for complex logic, high performance, and deep integration with the Kubernetes API.
