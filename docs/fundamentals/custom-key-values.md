# Custom Key-Value Pairs in Kubernetes

One of the most powerful features of Kubernetes is the ability to add **custom metadata** and **configuration data** to your resources. This guide covers all the places where you can add your own key-value pairs.

---

## 1. Labels (Organizing and Selecting Resources)

**Purpose:** Arbitrary key-value pairs used to organize, group, and select resources.

**Where:** `metadata.labels`

**Use Cases:**
*   Grouping resources by application, environment, team
*   Selecting pods with `kubectl get pods -l app=myapp`
*   Service selectors, ReplicaSet selectors

**Example:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
  labels:
    app: myapp
    environment: production
    team: backend
    version: "1.0"
    custom-key: custom-value
```

**Key Characteristics:**
*   Used for **identification** and **selection**
*   Can be queried with label selectors (`-l` flag)
*   Limited to 63 characters per key/value
*   Must follow DNS subdomain naming rules

**Common Label Patterns:**
```yaml
labels:
  app.kubernetes.io/name: myapp
  app.kubernetes.io/version: "1.0"
  app.kubernetes.io/component: frontend
  app.kubernetes.io/part-of: ecommerce
  app.kubernetes.io/managed-by: helm
```

---

## 2. Annotations (Non-Identifying Metadata)

**Purpose:** Arbitrary key-value pairs for storing **non-identifying** information like notes, documentation links, or tool-specific metadata.

**Where:** `metadata.annotations`

**Use Cases:**
*   Documentation and notes
*   Build/release information
*   Tool-specific configuration (Prometheus, Istio, etc.)
*   Change tracking

**Example:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
  annotations:
    description: "This is my production web server"
    documentation: "https://example.com/docs"
    slack-channel: "#devops"
    build-version: "abc123"
    last-updated-by: "john@example.com"
    prometheus.io/scrape: "true"
    prometheus.io/port: "9090"
```

**Key Characteristics:**
*   **NOT** used for selection (no `-l` queries)
*   Can store larger values (up to 256KB total per resource)
*   Often used by external tools (Ingress controllers, service meshes)

**Labels vs Annotations:**
| Feature | Labels | Annotations |
| :--- | :--- | :--- |
| **Purpose** | Identification & Selection | Documentation & Metadata |
| **Queryable** | Yes (`-l app=web`) | No |
| **Size Limit** | 63 chars per value | 256KB total |
| **Example** | `app: nginx` | `description: "Web server"` |

---

## 3. ConfigMap Data (Configuration Files)

**Purpose:** Store **non-sensitive** configuration data as key-value pairs.

**Where:** `data` or `binaryData` fields

**Use Cases:**
*   Application configuration files
*   Environment-specific settings
*   Scripts or templates

**Example:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  # Key-value pairs (strings)
  database_url: "postgres://db.example.com:5432/mydb"
  log_level: "info"
  
  # Multi-line configuration file
  config.yaml: |
    server:
      port: 8080
      host: 0.0.0.0
    database:
      max_connections: 100
  
  # Another file
  nginx.conf: |
    server {
      listen 80;
      server_name example.com;
    }
```

**Consuming ConfigMaps:**
```yaml
# As environment variables
env:
  - name: DATABASE_URL
    valueFrom:
      configMapKeyRef:
        name: app-config
        key: database_url

# As volume mount
volumes:
  - name: config
    configMap:
      name: app-config
```

---

## 4. Secret Data (Sensitive Information)

**Purpose:** Store **sensitive** data like passwords, tokens, SSH keys.

**Where:** `data` (base64-encoded) or `stringData` (plain text, auto-encoded)

**Use Cases:**
*   Database passwords
*   API tokens
*   TLS certificates

**Example:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
type: Opaque
stringData:
  # Plain text (Kubernetes will base64-encode automatically)
  username: admin
  password: super-secret-password
  api-token: "abc123xyz"
  
data:
  # Already base64-encoded
  ssh-key: LS0tLS1CRUdJTi...
```

**Consuming Secrets:**
```yaml
# As environment variables
env:
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: db-credentials
        key: password

# As volume mount
volumes:
  - name: secrets
    secret:
      secretName: db-credentials
```

**Important:** Secrets are **NOT encrypted** by default in etcd. Use encryption at rest for production.

---

## 5. Environment Variables (Container-Level)

**Purpose:** Pass custom configuration to containers as environment variables.

**Where:** `spec.containers[].env`

**Use Cases:**
*   Application-specific settings
*   Feature flags
*   Runtime configuration

**Example:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
spec:
  containers:
  - name: app
    image: myapp:1.0
    env:
      # Static values
      - name: MY_CUSTOM_VAR
        value: "anything"
      - name: ENVIRONMENT
        value: "production"
      - name: FEATURE_FLAG_NEW_UI
        value: "true"
      
      # From ConfigMap
      - name: DATABASE_URL
        valueFrom:
          configMapKeyRef:
            name: app-config
            key: database_url
      
      # From Secret
      - name: API_KEY
        valueFrom:
          secretKeyRef:
            name: api-secrets
            key: api-token
      
      # From Pod metadata (Downward API)
      - name: POD_NAME
        valueFrom:
          fieldRef:
            fieldPath: metadata.name
      - name: POD_NAMESPACE
        valueFrom:
          fieldRef:
            fieldPath: metadata.namespace
```

---

## 6. Downward API (Pod/Container Metadata)

**Purpose:** Expose Pod or Container metadata as environment variables or files.

**Available Fields:**
*   `metadata.name` - Pod name
*   `metadata.namespace` - Namespace
*   `metadata.labels['key']` - Specific label
*   `metadata.annotations['key']` - Specific annotation
*   `spec.nodeName` - Node name
*   `status.podIP` - Pod IP address

**Example:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
  labels:
    app: web
    version: "1.0"
spec:
  containers:
  - name: app
    image: myapp:1.0
    env:
      - name: MY_POD_NAME
        valueFrom:
          fieldRef:
            fieldPath: metadata.name
      - name: MY_POD_NAMESPACE
        valueFrom:
          fieldRef:
            fieldPath: metadata.namespace
      - name: MY_APP_VERSION
        valueFrom:
          fieldRef:
            fieldPath: metadata.labels['version']
```

---

## Summary Table

| Location | Purpose | Queryable | Size Limit | Example Use Case |
| :--- | :--- | :--- | :--- | :--- |
| **Labels** | Identification & Selection | Yes | 63 chars | `app: nginx`, `env: prod` |
| **Annotations** | Documentation & Metadata | No | 256KB | `description: "Web server"` |
| **ConfigMap** | Non-sensitive config | No | 1MB | `database_url: "..."` |
| **Secret** | Sensitive data | No | 1MB | `password: "..."` |
| **Env Vars** | Container config | No | N/A | `FEATURE_FLAG: "true"` |
| **Downward API** | Pod/Container metadata | No | N/A | `POD_NAME`, `POD_IP` |

---

## Best Practices

### 1. Use Labels for Selection
```yaml
# Good - Can select with kubectl get pods -l app=nginx
labels:
  app: nginx
  tier: frontend
```

### 2. Use Annotations for Documentation
```yaml
# Good - Human-readable notes
annotations:
  description: "Production web server for example.com"
  oncall: "team-platform@example.com"
```

### 3. Use ConfigMaps for Non-Sensitive Config
```yaml
# Good - Database host (not password)
data:
  database_host: "db.example.com"
  cache_ttl: "3600"
```

### 4. Use Secrets for Sensitive Data
```yaml
# Good - Passwords, tokens
stringData:
  db_password: "super-secret"
  api_token: "abc123"
```

### 5. Use Env Vars for Runtime Config
```yaml
# Good - Feature flags, runtime settings
env:
  - name: LOG_LEVEL
    value: "debug"
  - name: ENABLE_FEATURE_X
    value: "true"
```

---

## Common Patterns

### Pattern 1: Multi-Environment Setup
```yaml
# Development
labels:
  app: myapp
  environment: dev
env:
  - name: LOG_LEVEL
    value: "debug"

# Production
labels:
  app: myapp
  environment: prod
env:
  - name: LOG_LEVEL
    value: "error"
```

### Pattern 2: External Tool Integration
```yaml
# Prometheus scraping
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "9090"
  prometheus.io/path: "/metrics"

# Istio sidecar injection
annotations:
  sidecar.istio.io/inject: "true"
```

### Pattern 3: Blue-Green Deployment
```yaml
# Blue version
labels:
  app: myapp
  version: blue
  
# Green version
labels:
  app: myapp
  version: green
```
