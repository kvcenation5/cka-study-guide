# Node Selector

Node Selector is the simplest form of node selection constraint in Kubernetes. It allows you to restrict a Pod to run only on nodes with specific labels.

## 1. How it works
For Node Selector to work, you must:
1.  **Label the Node**: Give your node a key-value pair.
2.  **Add nodeSelector to Pod**: Update the Pod spec to look for that exact label.

## 2. Practical Example

### Step 1: Label your node
```bash
kubectl label nodes node01 disktype=ssd
```

### Step 2: Create a Pod with the selector
**Exam Tip:** Since there is no `--node-selector` flag in `kubectl run`, you must generate the YAML first and then edit it.

```bash
# 1. Generate the base YAML
kubectl run nginx-ssd --image=nginx --dry-run=client -o yaml > pod.yaml

# 2. Add the nodeSelector block to pod.yaml
# (See YAML structure below)

# 3. Apply the file
kubectl apply -f pod.yaml
```

**YAML Structure:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-ssd
spec:
  nodeSelector:      # <--- Added section
    disktype: ssd
  containers:
  - name: nginx
    image: nginx
```

## 3. Limitations
Node Selector is very simple but has significant drawbacks:
*   **Exact Match Only**: You cannot say "SSD OR HDD" or "NOT GPU".
*   **Hard Requirement**: If no node matches the label, the Pod will stay in **Pending** forever. It has no "best effort" mode.
*   **Simple Logic**: You can only use one or more exact matches (AND logic).

---

## Summary Cheat Sheet
| Command | Action |
| :--- | :--- |
| `kubectl label node <node> key=value` | Add a label to a node |
| `kubectl label node <node> key-` | Remove a label from a node |
| `kubectl get nodes --show-labels` | See all labels on your nodes |

Since Node Selector is so limited, for more complex logic (Like "Try to put it on a high-cpu node, but if none are free, anywhere is fine"), you should use **Node Affinity**.
