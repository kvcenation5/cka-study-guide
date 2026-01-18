# LimitRange (Resource Guardrails)

A **LimitRange** is a policy that sets resource constraints (limits and requests) for all Pods or Containers in a specific **namespace**. 

Think of it as the **"Standard Operating Procedure"** for a namespace.

!!! failure "CRITICAL NOTE for CKA"
    **LimitRange does NOT affect existing Pods.** 
    If you create or update a LimitRange, any Pods already running in the namespace will continue with their old settings (or no settings) until they are deleted and recreated.

---

## 1. Why use LimitRange?

1.  **Defaults**: If a developer forgets to set `requests` or `limits`, Kubernetes will automatically inject the values you define in the LimitRange.
2.  **Enforcement**: It prevents a developer from requesting 100 Cores on a node that only has 8 (it will block the Pod creation immediately).
3.  **Stability**: It ensures no single container is too small (wasting management overhead) or too big (risking the node).

---

## 2. Key Components of a LimitRange

| Field | Purpose |
| :--- | :--- |
| **`default`** | The **Limit** automatically applied if the developer leaves it blank. |
| **`defaultRequest`** | The **Request** automatically applied if the developer leaves it blank. |
| **`min`** | The absolute **minimum** allowed value. Pods smaller than this will be rejected. |
| **`max`** | The absolute **maximum** allowed value. Pods bigger than this will be rejected. |

---

## 3. Practical Example (The "Safety Net")

If you apply this YAML to your `dev` namespace, every tiny Pod will suddenly have a "size."

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: cpu-min-max-demo-lr
spec:
  limits:
  - default:                # Default LIMIT
      cpu: 500m
      memory: 512Mi
    defaultRequest:         # Default REQUEST
      cpu: 200m
      memory: 256Mi
    max:                    # Upper Guardrail
      cpu: "4"
      memory: 2Gi
    min:                    # Lower Guardrail
      cpu: 100m
      memory: 64Mi
    type: Container
```

### What happens now?
*   **Case A**: A developer runs `kubectl run web --image=nginx`. 
    *   *Result*: Kubernetes automatically gives it 200m CPU Request and 500m CPU Limit.
*   **Case B**: A developer tries to request `cpu: 10` (10 cores).
    *   *Result*: **Rejected!** Error: `Forbidden: maximum cpu usage per Container is 4, but provided is 10`.

---

## 4. LimitRange vs. ResourceQuota

It is easy to confuse these two. Remember the distinction:

*   **LimitRange**: Controls the **Individual**. (e.g., "Any single person can drink max 2 sodas").
*   **ResourceQuota**: Controls the **Total**. (e.g., "This whole party can only have 50 sodas total").

---

## 5. Summary Cheat Sheet

| Question | Answer |
| :--- | :--- |
| **Does it affect running pods?** | **No.** It only checks at the "door" when a pod is being created. |
| **What if I change the LimitRange?** | Old pods keep their old values. New pods get the new ones. |
| **What happens if `min` > `request`?** | The Pod will be rejected. |

---

## 6. Commands to check
```bash
# See LimitRanges in the current namespace
kubectl get limitrange

# See the specific settings (Defaults and Guardrails)
kubectl describe limitrange <name>
```
