# YAML Guide for Kubernetes

Understanding YAML data structures is **critical** for the CKA exam. You will spend 50% of your time reading and editing YAML manifests.

This guide breaks down the data types you will encounter in every Kubernetes resource.

---

## YAML Data Types in Kubernetes

### 1. **Strings** (Simple Text Values)
These are plain text values. Quotes are optional in YAML (but allowed).

```yaml
apiVersion: v1                    # String
kind: Pod                         # String
name: hostnames-74fbbfdf9f-b7ftl  # String
namespace: default                # String
image: registry.k8s.io/serve_hostname  # String
```

**When to use quotes:**
*   If the value contains special characters: `name: "my-app:v1.0"`
*   If it looks like a number but should be a string: `version: "1.0"`

---

### 2. **Dictionaries/Maps** (Key-Value Pairs)
These are nested objects. Indicated by a colon `:` followed by indentation.

```yaml
metadata:              # This is a Dictionary
  name: my-pod         # String inside the dictionary
  labels:              # This is a Dictionary inside metadata
    app: hostnames     # String inside labels
    tier: frontend     # Another key-value pair
```

**How to spot them:** Look for a colon `:` followed by a newline and increased indentation.

**Common mistake:**
```yaml
# WRONG (missing indentation)
metadata:
name: my-pod

# CORRECT
metadata:
  name: my-pod
```

---

### 3. **Lists/Arrays** (Multiple Items)
These start with a dash `-`. Each item can be a string, number, or even a dictionary.

**Example 1: List of Dictionaries (Most Common)**
```yaml
containers:                    # This is a List
  - name: nginx                # First item (Dictionary)
    image: nginx:1.21
  - name: sidecar              # Second item (Dictionary)
    image: busybox
```

**Example 2: List of Strings**
```yaml
args:                          # List of strings
  - "--config=/etc/app.conf"
  - "--verbose"
```

**Example 3: Nested Lists**
```yaml
tolerations:                   # List of Dictionaries
  - effect: NoExecute          # First toleration
    key: node.kubernetes.io/not-ready
    tolerationSeconds: 300
  - effect: NoExecute          # Second toleration
    key: node.kubernetes.io/unreachable
    tolerationSeconds: 300
```

---

### 4. **Booleans** (True/False)
```yaml
readOnly: true                 # Boolean
blockOwnerDeletion: true       # Boolean
enableServiceLinks: false      # Boolean
```

**Valid values:** `true`, `false`, `True`, `False`, `TRUE`, `FALSE` (case-insensitive).

---

### 5. **Numbers** (Integers and Floats)
```yaml
priority: 0                    # Integer
terminationGracePeriodSeconds: 30  # Integer
restartCount: 1                # Integer
cpu: 0.5                       # Float (500 millicores)
```

---

### 6. **Null/Empty Values**
```yaml
lastProbeTime: null            # Explicitly null
resources: {}                  # Empty dictionary
args: []                       # Empty list
```

**When you see `{}`:** It means "this field exists but has no data."
**When you see `null`:** It means "this field is intentionally empty."

---

## Real-World Example: Annotated Pod YAML

Let's break down a real Pod manifest with data type annotations:

```yaml
apiVersion: v1                 # String
kind: Pod                      # String
metadata:                      # Dictionary
  name: my-app                 # String
  namespace: default           # String
  labels:                      # Dictionary
    app: web                   # String
    tier: frontend             # String
spec:                          # Dictionary
  containers:                  # List (of Dictionaries)
  - name: nginx                # Dictionary item #1
    image: nginx:1.21          # String
    ports:                     # List (of Dictionaries)
    - containerPort: 80        # Dictionary item
      protocol: TCP            # String
    resources:                 # Dictionary
      requests:                # Dictionary
        memory: "64Mi"         # String (with quotes because of unit)
        cpu: "250m"            # String
      limits:                  # Dictionary
        memory: "128Mi"        # String
        cpu: "500m"            # String
    volumeMounts:              # List (of Dictionaries)
    - name: config-volume      # Dictionary item
      mountPath: /etc/config   # String
      readOnly: true           # Boolean
  restartPolicy: Always        # String
  volumes:                     # List (of Dictionaries)
  - name: config-volume        # Dictionary item
    configMap:                 # Dictionary
      name: app-config         # String
```

---

## Common Patterns for CKA

### Pattern 1: Adding a Container to a Pod
You are adding an item to the `containers` **list**.

```yaml
spec:
  containers:
  - name: main-app             # Existing container
    image: nginx
  - name: sidecar              # NEW container (note the dash!)
    image: busybox
    command: ["sh", "-c", "tail -f /var/log/app.log"]
```

### Pattern 2: Adding a Label
You are adding a key-value pair to the `labels` **dictionary**.

```yaml
metadata:
  labels:
    app: web                   # Existing label
    environment: production    # NEW label (no dash, just key: value)
```

### Pattern 3: Adding a Volume Mount
You are adding an item to the `volumeMounts` **list**.

```yaml
volumeMounts:
  - name: data                 # Existing mount
    mountPath: /data
  - name: logs                 # NEW mount
    mountPath: /var/log
```

---

## JSONPath Quick Reference

Understanding data types helps you write JSONPath queries (used in `kubectl get -o jsonpath`).

| Data Type | JSONPath Example | What it Returns |
| :--- | :--- | :--- |
| String | `.metadata.name` | `"my-pod"` |
| Dictionary | `.metadata.labels` | `{"app":"web","tier":"frontend"}` |
| List | `.spec.containers` | `[{...}, {...}]` (array of containers) |
| First item in list | `.spec.containers[0].name` | `"nginx"` |
| All names in list | `.spec.containers[*].name` | `["nginx", "sidecar"]` |

---

## Debugging YAML Errors

### Error 1: "mapping values are not allowed here"
**Cause:** Missing indentation or extra space.

```yaml
# WRONG
metadata:
name: my-pod

# CORRECT
metadata:
  name: my-pod
```

### Error 2: "expected a sequence"
**Cause:** You provided a dictionary where a list was expected.

```yaml
# WRONG
containers:
  name: nginx

# CORRECT
containers:
  - name: nginx
```

### Error 3: "duplicate key"
**Cause:** You defined the same key twice in a dictionary.

```yaml
# WRONG
metadata:
  name: pod-1
  name: pod-2

# CORRECT
metadata:
  name: pod-1
```

---

## Summary Cheat Sheet

| Type | Syntax | Example |
| :--- | :--- | :--- |
| **String** | `key: value` | `name: my-pod` |
| **Dictionary** | `key:` + indented keys | `metadata:` <br> `  name: pod` |
| **List** | `key:` + `- item` | `containers:` <br> `  - name: nginx` |
| **Boolean** | `key: true/false` | `readOnly: true` |
| **Number** | `key: 123` | `replicas: 3` |
| **Null** | `key: null` or `key:` | `lastProbeTime: null` |
| **Empty Dict** | `key: {}` | `resources: {}` |
| **Empty List** | `key: []` | `args: []` |

---

## Practice Exercise

Try to identify the data types in this snippet:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
        ports:
        - containerPort: 80
```

**Answers:**
*   `apiVersion`: String
*   `metadata`: Dictionary
*   `labels`: Dictionary
*   `replicas`: Number
*   `containers`: List
*   `ports`: List
*   `containerPort`: Number
