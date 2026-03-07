# Deep Dive: OPA in Kubernetes

While RBAC manages **identity** ("Who"), **Open Policy Agent (OPA)** manages **content** ("What is inside the YAML"). This guide explains the architecture, the Rego language, and how OPA is integrated into Kubernetes via Gatekeeper.

---

## 🏗️ 1. OPA vs. Gatekeeper: The distinction

It is common to confuse these two. Here is the breakdown:
*   **OPA (The Engine)**: A general-purpose policy engine. It's just a "calculator" that takes JSON as input and returns a decision based on its rules.
*   **Gatekeeper (The Controller)**: A Kubernetes-specific project that wraps OPA. It provides the "glue" (Admission Webhooks, Custom Resources) to make OPA work natively inside a cluster.

---

## 🔌 2. How the Webhook is used

The API Server uses the **Admission Webhook** phase to talk to OPA.

### The Lifecycle of a Request:
1.  **Request**: User runs `kubectl create pod`.
2.  **AuthN/AuthZ**: API Server verifies identity and RBAC.
3.  **Mutating Webhooks**: (Optional) Other tools might modify the Pod (e.g., adding a sidecar).
4.  **Validating Webhooks (The OPA Stage)**:
    *   The API Server sends the Pod's YAML (wrapped in an `AdmissionReview` JSON) to the Gatekeeper service.
    *   Gatekeeper queries its internal OPA engine.
5.  **Decision**: OPA returns `allowed: true` or `allowed: false` with a reason.
6.  **Persistence**: Only if OPA allows it, the Pod is saved to `etcd`.

---

## 📄 3. Policy-as-Code: The Rego Language

OPA uses **Rego**, a declarative language designed for querying complex JSON data. 

### Why Rego? 
In Kubernetes, you often need to iterate over lists (like containers in a pod). Rego makes this easy.

**Example Rego Logic**: "Deny if any container image does not start with `hooli.com/`."
```rego
package kubernetes.admission

deny[msg] {
  input.request.kind.kind == "Pod"
  image := input.request.object.spec.containers[_].image
  not startswith(image, "hooli.com/")
  msg := sprintf("Image '%v' is not from a trusted registry!", [image])
}
```

---

## 🛠️ 4. Implementing Policies in Kubernetes

Gatekeeper uses **Custom Resource Definitions (CRDs)** to manage these policies.

### Step A: The ConstraintTemplate
This defines the "Function" and the Rego logic. It tells Gatekeeper *how* to check for a violation.

```yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequiredlabels
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredLabels
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredlabels
        violation[{"msg": msg}] {
          not input.review.object.metadata.labels[label]
          msg := sprintf("You must provide the label: %v", [label])
        }
```

### Step B: The Constraint
This is the "Call" to the function. It tells Gatekeeper *where* to apply the rule and what parameters to use.

```yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: ns-must-have-owner
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Namespace"]
  parameters:
    labels: ["owner"]
```

---

## 📊 5. Use Case Comparison

| Traditional RBAC | OPA / Gatekeeper |
| :--- | :--- |
| Can I create a Service? | Can I create a Service of type **LoadBalancer**? |
| Can I delete a Pod? | Can I delete a Pod in the **kube-system** namespace? |
| Can I update an Ingress? | Can I update an Ingress to use a **duplicated hostname**? |
| Can I pull an image? | Can I pull an image **without a specific sha256 tag**? |

---

## 🧪 6. Why this matters for the CKA/CKS

*   **CKA**: You should know that OPA acts as a **Validating Admission Controller**. If you see a `ValidatingWebhookConfiguration` pointing to something named `gatekeeper`, that's why your YAML might be getting rejected even if your RBAC permissions are correct.
*   **CKS**: You will be required to write/debug actual Rego and ConstraintTemplates.

---

> [!TIP]
> **Audit Mode**: Gatekeeper can be set to `audit` mode. Instead of rejecting requests (which breaks things), it simply logs the violations so you can see who is breaking the rules before you turn on strict enforcement.
