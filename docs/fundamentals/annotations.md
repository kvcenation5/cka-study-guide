# Annotations in Kubernetes

Annotations are used to attach **non-identifying metadata** to objects. Unlike Labels, Annotations are not used to select or group objects. Instead, they are used to store supplementary information that can be retrieved by tools, libraries, or administrative interfaces.

---

## 🧐 Annotations vs. Labels

| Feature | Labels (The "Tags") | Annotations (The "Notes") |
| :--- | :--- | :--- |
| **Selection** | Yes (via Selectors) | **No** |
| **Data Type** | Short, strictly formatted | Large, flexible (JSON, structured text) |
| **Max Size** | 63 characters | 256 KB |
| **Primary Use** | Filtering and Grouping | Supplementary info for tools/humans |

---

## 🛠️ Practical Examples

### 1. Ingress Configuration (Most Common CKA use)
Ingress controllers like Nginx use annotations to handle complex routing rules or SSL configuration that isn't part of the core Kubernetes API.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
spec:
  rules:
  - http:
      paths:
      - path: /testpath
        pathType: Prefix
        backend:
          service:
            name: test
            port:
              number: 80
```

### 2. Recording Deployment "Change Cause"
When you perform a rolling update, it's helpful to see *why* a change happened in the rollout history. You can use an annotation to record the reason.

```bash
kubectl annotate deployment/my-app kubernetes.io/change-cause="Updated image to v2.0 for security fix"
```

Then, when you check the history, the message will appear:
```bash
kubectl rollout history deployment/my-app
```

### 3. External Tooling & CI/CD
Annotations are perfect for storing information about the build process or the owner of the resource.

```yaml
metadata:
  annotations:
    build-id: "2024-01-15-v1.4.2"
    commit-hash: "af21d9b"
    on-call-contact: "@oncall-devs"
    description: "Legacy database sync service"
```

---

## ⌨️ CLI Management

Manage annotations directly from the terminal just like labels:

| Goal | Command |
| :--- | :--- |
| **Add/Update** | `kubectl annotate pod my-pod owner=marketing` |
| **Overwrite** | `kubectl annotate pod my-pod owner=sales --overwrite` |
| **Remove** | `kubectl annotate pod my-pod owner-` (Suffix with dash) |
| **Filter (Manual)** | `kubectl get pods -o jsonpath='{.items[?(@.metadata.annotations.owner=="marketing")].metadata.name}'` |

---

## ✅ CKA Exam Tips

1.  **Selection Trap**: Remember that `kubectl get pods -l key=value` only works for **Labels**. To find an annotation, you must use `describe` or `-o yaml/json` and search (grep).
2.  **Immutability**: Unlike `nodeName`, annotations can be changed on a running pod at any time without needing to recreate it.
3.  **Large Payloads**: If you need to store more than just a simple string (like a certificate or a configuration JSON), use an **Annotation**, not a label.
