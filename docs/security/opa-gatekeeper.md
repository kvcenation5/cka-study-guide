# OPA: Open Policy Agent & Gatekeeper

**Open Policy Agent (OPA)** is an open-source, general-purpose policy engine that enables unified, context-aware policy enforcement across your entire stack. In Kubernetes, it is usually implemented via **OPA Gatekeeper**.

---

## 🏗️ 1. Why OPA? (The "Beyond RBAC" Need)

RBAC only answers "Who can do What." It cannot answer "How" or "Where."
*   **RBAC**: "Can Bob create a Deployment?" (Yes/No)
*   **OPA**: "Can Bob create a Deployment **without a CPU limit**?" or "Can Bob use a **non-approved image registry**?"

OPA provides **Policy-as-Code** to enforce business rules that RBAC cannot handle.

---

## ⚙️ 2. How it works: OPA Gatekeeper

Gatekeeper is the Kubernetes-native implementation of OPA. It works as an **Admission Controller** (specifically a Validating Webhook).

### The Workflow:
1.  A user runs `kubectl apply`.
2.  The **API Server** sends the request to the **Gatekeeper Webhook**.
3.  Gatekeeper checks the request against your **Policies** (written in a language called **Rego**).
4.  Gatekeeper sends an **Allow** or **Deny** response back to the API Server.

---

## 🔌 2. Understanding the Webhook Integration

Gatekeeper integrates into Kubernetes using the **Admission Webhook** mechanism. This is a "call-back" system where the API Server pauses a request to ask an external service for permission.

### A. The Webhook Configuration
Kubernetes uses a special object called a `ValidatingWebhookConfiguration` to know where the OPA server is. It contains:
*   **Service Details**: The namespace and service name of the Gatekeeper pod.
*   **Rules**: Which operations (CREATE, UPDATE) and resources (Pods, Ingress) should trigger the webhook.
*   **Failure Policy**: What happens if the OPA pod is down?
    *   `Ignore`: (Fail Open) Let the request through anyway.
    *   `Fail`: (Fail Closed) Reject the request. **(Standard for security)**.

### B. The Request/Response Cycle (`AdmissionReview`)
1.  **Request**: The API Server sends a JSON object called an `AdmissionReview` to the OPA service. It contains the **entire YAML** of the resource being created.
2.  **Processing**: OPA parses the YAML and runs its Rego logic against it.
3.  **Response**: OPA sends back an `AdmissionResponse` containing:
    *   `allowed`: `true` or `false`.
    *   `status`: (Optional) A human-readable message explaining why it was denied (e.g., "Missing owner label").

---

## 📄 3. The Two Parts of a Gatekeeper Policy

To enforce a rule in Gatekeeper, you need two custom resources:

### 1. ConstraintTemplate
This defines **the logic** of the rule (the Rego code) and any parameters it accepts.
*   *Analogy*: This is the "Blueprint" or the "Function Definition".

### 2. Constraint
This is the **instance** of the rule that applies it to specific resources.
*   *Analogy*: This is the "Active Rule" that says "Apply the blueprint to all Namespaces."

---

## 🛠️ 4. Common OPA Use Cases

| Case | Description |
| :--- | :--- |
| **Registry Validation** | "Only allow images from `my-company.jfrog.io`." |
| **Label Enforcement** | "Every Pod must have an `owner` and `cost-center` label." |
| **Resource Limits** | "Reject any Pod that doesn't define CPU/Memory limits." |
| **Ingress Safety** | "Prevent two different teams from using the same Ingress hostname." |

---

## 🔄 5. Comparison: RBAC vs. OPA

| Feature | RBAC | OPA (Gatekeeper) |
| :--- | :--- | :--- |
| **Focus** | User Identity & Actions | Resource Content & Rules |
| **Language** | Kubernetes YAML | **Rego** (Declarative Logic) |
| **Implementation** | Built-in Authorizer | Admission Webhook |
| **Scope** | Verbs (get, create) | Attributes (labels, image, limits) |

---

## 🧪 6. CKA Exam Perspective

Gatekeeper is usually a **CKS (Security Specialist)** topic rather than CKA. However, for the CKA, you should know:
1.  It exists as a **Validating Admission Webhook**.
2.  It is the standard way to enforce "business logic" on your YAML files.
3.  It can be identified in the API server manifest via the `--admission-control-config-file` or simply by seeing a `ValidatingWebhookConfiguration` object in the cluster.

---

> [!TIP]
> **Learning Tip**: If you see a cluster with a lot of "Denied" messages that aren't RBAC related (e.g., "Image registry not allowed"), look for Gatekeeper by running `kubectl get pods -n gatekeeper-system`.
