# Node Affinity

Node Affinity is a more advanced and flexible version of `nodeSelector`. It allows you to use complex logic and soft requirements to control where your Pods land.

## 1. Why use Node Affinity?
Unlike Node Selector, Node Affinity supports:
*   **Logical Operators**: `In`, `NotIn`, `Exists`, `DoesNotExist`, `Gt` (Greater than), `Lt` (Less than).
*   **Soft Rules**: You can tell Kubernetes "I would *prefer* this node, but if it's full, run it somewhere else."

---

## 2. The Two Types of Affinity

Kubernetes uses long, descriptive names for these rules. Think of them as **"Hard"** vs. **"Soft"**.

### A. RequiredDuringSchedulingIgnoredDuringExecution ("The Hard Rule")
*   **Scheduling**: The scheduler **must** find a node that matches the rule. If not, the Pod stays **Pending**.
*   **Execution**: If the node labels change while the Pod is already running, the Pod is **NOT** evicted (it stays running).

**Example YAML:**
```yaml
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: topology.kubernetes.io/zone
            operator: In
            values:
            - us-east-1a
            - us-east-1b
```

### B. PreferredDuringSchedulingIgnoredDuringExecution ("The Soft Rule")
*   **Scheduling**: The scheduler will try to find a matching node. If none are available, it will schedule the Pod on any available node.
*   **Weight**: You assign a weight (1-100). The scheduler adds up weights for each node to decide the "best" winner.

**Example YAML:**
```yaml
spec:
  affinity:
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 1
        preference:
          matchExpressions:
          - key: another-node-label-key
            operator: In
            values:
            - another-node-label-value
```

---

## 3. Operators Cheat Sheet

| Operator | Usage |
| :--- | :--- |
| **In** | Label value must be in this list. |
| **NotIn** | Label value must NOT be in this list. |
| **Exists** | The key must exist on the node (value doesn't matter). |
| **DoesNotExist** | The key must NOT exist on the node. |
| **Gt / Lt** | Greater than / Less than (for numeric values). |

---

## 4. The Exam Workflow (Dry-Run + Edit)

**CRITICAL TIP**: `kubectl` does **not** have a flag for `nodeAffinity`. To use it in the exam:

1.  **Generate the template**:
    ```bash
    kubectl create deployment blue --image=nginx --dry-run=client -o yaml > blue.yaml
    ```
2.  **Add the affinity block**: Open the file and insert the affinity section inside `spec.template.spec`.
3.  **Apply**:
    ```bash
    kubectl apply -f blue.yaml
    ```

---

## 5. The "DuringExecution" Clarification

You might notice the suffix `IgnoredDuringExecution` in the standard affinity names. 

### IgnoredDuringExecution (Current Standard)
*   **Meaning**: Rules are only checked during the **scheduling phase** (when the Pod is first being created).
*   **Behavior**: If a node's labels change while the Pod is already running (making the affinity rule technically "invalid"), the Pod **continues to run** unaffected.

### RequiredDuringExecution (Planned/Future)
*   **Meaning**: Rules would be checked continuously throughout the Pod's lifecycle.
*   **Behavior**: If a node's labels change and no longer match the Pod's requirements, the Pod would be **evicted (terminated)** immediately.
*   **Status**: This is **NOT yet implemented** in Kubernetes but is reserved in the API for future functionality.

---

## 5. Comparison Table

| Feature | Node Selector | Node Affinity |
| :--- | :--- | :--- |
| **Logic** | Simple (Equal) | Complex (In, NotIn, etc.) |
| **Strictness** | Always Required | Required OR Preferred |
| **Use Case** | Simple constraints | Production-grade scheduling |

**Note for CKA Exam:** You will likely be asked to use **Required** affinity to move a Pod to a specific zone or node with a specific label. Always use `dry-run` to generate the base YAML and then carefully paste the `affinity` block.
