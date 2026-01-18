# ConfigMaps in Kubernetes

**ConfigMaps** allow you to separate configuration data from your application code, making your containerized applications more portable and easier to manage.

---

## 1. The "Settings File" Analogy

Think of a ConfigMap like a **settings.ini file** for your application:
*   **Without ConfigMap**: Configuration is hardcoded in the container image. To change a setting, you rebuild the image.
*   **With ConfigMap**: Configuration lives outside the container. You can change settings without rebuilding anything.

**Real-world example:**
```
Your web app needs a database URL:

❌ Bad (Hardcoded):
  app.py contains: DB_HOST = "mysql.prod.com"
  
✅ Good (ConfigMap):
  ConfigMap contains: DB_HOST=mysql.prod.com
  app.py reads from environment variable
```

---

## 2. What is a ConfigMap?

A **ConfigMap** is a Kubernetes object that stores **non-confidential** configuration data as **key-value pairs**.

### Key Characteristics:
*   **Non-namespaced data**: Available within a specific namespace
*   **Plain text**: Not encrypted (use Secrets for sensitive data)
*   **Multiple formats**: Simple strings, files, or even entire config files
*   **Decoupled**: Configuration lives separately from pod definitions

---

## 3. Why Use ConfigMaps?

### The "12-Factor App" Principle

**Problem**: You have the same application running in 3 environments:

| Environment | Database URL | Log Level | API Endpoint |
| :--- | :--- | :--- | :--- |
| **Dev** | `mysql.dev.local` | `DEBUG` | `api.dev.example.com` |
| **Staging** | `mysql.staging.local` | `INFO` | `api.staging.example.com` |
| **Production** | `mysql.prod.local` | `ERROR` | `api.example.com` |

**Without ConfigMaps:**
- You need **3 different container images** (one per environment)
- Any config change requires rebuilding and redeploying images

**With ConfigMaps:**
- **One container image** for all environments
- Different ConfigMaps per environment
- Change config without touching code or images

---

## 4. Creating ConfigMaps

### Method 1: From Literal Values (Key-Value Pairs)

```bash
kubectl create configmap app-config \
  --from-literal=DB_HOST=mysql.prod.com \
  --from-literal=DB_PORT=3306 \
  --from-literal=LOG_LEVEL=INFO
```

**What gets created:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  DB_HOST: mysql.prod.com
  DB_PORT: "3306"
  LOG_LEVEL: INFO
```

### Method 2: From a File

**Step 1: Create a properties file**
```bash
cat > app.properties <<EOF
database.host=mysql.prod.com
database.port=3306
log.level=INFO
cache.enabled=true
EOF
```

**Step 2: Create ConfigMap from file**
```bash
kubectl create configmap app-config --from-file=app.properties
```

**What gets created:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  app.properties: |
    database.host=mysql.prod.com
    database.port=3306
    log.level=INFO
    cache.enabled=true
```

### Method 3: From Multiple Files

```bash
kubectl create configmap nginx-config \
  --from-file=nginx.conf \
  --from-file=default.conf \
  --from-file=ssl-params.conf
```

### Method 4: From a Directory

```bash
# All files in the directory become separate keys
kubectl create configmap web-config --from-file=/path/to/config/dir/
```

### Method 5: From YAML Manifest (Declarative)

```yaml
# config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: production
data:
  # Simple key-value pairs
  DB_HOST: mysql.prod.com
  DB_PORT: "3306"
  LOG_LEVEL: INFO
  
  # Multi-line file content
  app.properties: |
    database.host=mysql.prod.com
    database.port=3306
    log.level=INFO
    cache.enabled=true
  
  # JSON config
  config.json: |
    {
      "server": {
        "port": 8080,
        "host": "0.0.0.0"
      }
    }
```

```bash
kubectl apply -f config.yaml
```

---

## 5. Using ConfigMaps in Pods

There are **3 main ways** to consume ConfigMap data in pods:

### Method 1: Environment Variables (Individual Keys)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-app
spec:
  containers:
  - name: app
    image: myapp:1.0
    env:
    - name: DATABASE_HOST        # Environment variable name
      valueFrom:
        configMapKeyRef:
          name: app-config       # ConfigMap name
          key: DB_HOST           # Key from ConfigMap
    - name: DATABASE_PORT
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: DB_PORT
```

**Inside the container:**
```bash
echo $DATABASE_HOST  # mysql.prod.com
echo $DATABASE_PORT  # 3306
```

### Method 2: Environment Variables (All Keys at Once)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-app
spec:
  containers:
  - name: app
    image: myapp:1.0
    envFrom:
    - configMapRef:
        name: app-config  # Imports ALL keys as env vars
```

**Inside the container:**
```bash
echo $DB_HOST    # mysql.prod.com
echo $DB_PORT    # 3306
echo $LOG_LEVEL  # INFO
```

### Method 3: Volume Mounts (Files)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
spec:
  containers:
  - name: nginx
    image: nginx:1.19
    volumeMounts:
    - name: config-volume
      mountPath: /etc/nginx/conf.d  # Where to mount
  volumes:
  - name: config-volume
    configMap:
      name: nginx-config  # ConfigMap to mount
```

**Inside the container:**
```bash
ls /etc/nginx/conf.d/
# nginx.conf
# default.conf
# ssl-params.conf

cat /etc/nginx/conf.d/nginx.conf
# <contents of the nginx.conf from ConfigMap>
```

### Method 4: Volume Mount (Specific Keys as Files)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-pod
spec:
  containers:
  - name: app
    image: myapp:1.0
    volumeMounts:
    - name: config
      mountPath: /config
  volumes:
  - name: config
    configMap:
      name: app-config
      items:
      - key: app.properties      # Key from ConfigMap
        path: application.properties  # Filename in container
```

**Inside the container:**
```bash
ls /config/
# application.properties

cat /config/application.properties
# database.host=mysql.prod.com
# database.port=3306
# ...
```

---

## 6. Real-World Example: Multi-Environment Application

### Scenario
You have a Node.js app that needs different configs for dev/staging/prod.

### Step 1: Create Environment-Specific ConfigMaps

**Dev:**
```bash
kubectl create configmap app-config \
  --from-literal=DB_HOST=mysql.dev.local \
  --from-literal=LOG_LEVEL=DEBUG \
  --from-literal=API_URL=http://api.dev.local \
  --namespace=dev
```

**Production:**
```bash
kubectl create configmap app-config \
  --from-literal=DB_HOST=mysql.prod.local \
  --from-literal=LOG_LEVEL=ERROR \
  --from-literal=API_URL=https://api.example.com \
  --namespace=prod
```

### Step 2: Same Deployment, Different Namespaces

```yaml
# deployment.yaml (same for all environments!)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nodejs-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nodejs
  template:
    metadata:
      labels:
        app: nodejs
    spec:
      containers:
      - name: app
        image: mycompany/nodejs-app:1.0  # Same image everywhere!
        envFrom:
        - configMapRef:
            name: app-config  # Same ConfigMap name
```

**Deploy:**
```bash
# Dev environment
kubectl apply -f deployment.yaml -n dev

# Production environment
kubectl apply -f deployment.yaml -n prod
```

**Result:** Same code, different configuration!

---

## 7. Updating ConfigMaps

### Important Behavior

**Environment Variables**: **NOT automatically updated**
```yaml
env:
  - name: DB_HOST
    valueFrom:
      configMapKeyRef:
        name: app-config
        key: DB_HOST
```
If you change the ConfigMap, the env var in running pods **stays the same**. You must **restart the pod**.

**Volume Mounts**: **Automatically updated** (with delay)
```yaml
volumeMounts:
  - name: config
    mountPath: /etc/config
```
If you change the ConfigMap, the files are updated in the pod **within ~60 seconds**. The app must **re-read** the files to pick up changes.

### How to Update a ConfigMap

```bash
# Method 1: Edit directly
kubectl edit configmap app-config

# Method 2: Replace from file
kubectl create configmap app-config --from-literal=DB_HOST=new-host --dry-run=client -o yaml | kubectl apply -f -

# Method 3: Patch
kubectl patch configmap app-config -p '{"data":{"DB_HOST":"new-host"}}'
```

### Forcing Pod Restart After ConfigMap Change

```bash
# Rollout restart (for Deployments)
kubectl rollout restart deployment nodejs-app

# Delete pods (for bare Pods)
kubectl delete pod web-app
```

---

## 8. Best Practices

### ✅ Do's

1. **Use for non-sensitive data only**
   ```yaml
   data:
     LOG_LEVEL: INFO        # ✅ Good
     API_ENDPOINT: api.com  # ✅ Good
   ```

2. **Keep ConfigMaps small** (< 1MB recommended)

3. **Use descriptive names**
   ```bash
   ✅ kubectl create cm app-config
   ✅ kubectl create cm nginx-server-config
   ❌ kubectl create cm config  # Too generic
   ```

4. **Version your ConfigMaps**
   ```yaml
   metadata:
     name: app-config-v2  # Versioned name
   ```

### ❌ Don'ts

1. **Don't store secrets in ConfigMaps**
   ```yaml
   data:
     DB_PASSWORD: supersecret  # ❌ Use Secrets instead!
   ```

2. **Don't create huge ConfigMaps**
   - Limit: 1MB per ConfigMap
   - Use external config stores for large data

3. **Don't assume instant updates**
   - Volume-mounted configs update with delay (~60s)
   - Environment variables never update automatically

---

## 9. kubectl Commands Reference

### Creating ConfigMaps

```bash
# From literal values
kubectl create cm app-config --from-literal=key1=value1 --from-literal=key2=value2

# From file
kubectl create cm app-config --from-file=config.properties

# From multiple files
kubectl create cm nginx-config --from-file=nginx.conf --from-file=ssl.conf

# From directory
kubectl create cm web-config --from-file=/path/to/configs/

# From YAML
kubectl apply -f configmap.yaml

# Dry-run (generate YAML)
kubectl create cm app-config --from-literal=key=value --dry-run=client -o yaml
```

### Viewing ConfigMaps

```bash
# List all ConfigMaps
kubectl get configmaps
kubectl get cm

# View specific ConfigMap
kubectl get cm app-config -o yaml

# View just the data
kubectl get cm app-config -o jsonpath='{.data}'

# Get a specific key
kubectl get cm app-config -o jsonpath='{.data.DB_HOST}'

# Describe (shows usage info)
kubectl describe cm app-config
```

### Editing ConfigMaps

```bash
# Edit interactively
kubectl edit cm app-config

# Replace from file
kubectl create cm app-config --from-file=new-config.txt --dry-run=client -o yaml | kubectl apply -f -

# Delete
kubectl delete cm app-config
```

### Checking Which Pods Use a ConfigMap

```bash
# Show all pods in namespace with volume mounts
kubectl get pods -o json | jq '.items[] | select(.spec.volumes[]?.configMap.name=="app-config") | .metadata.name'

# Describe pod to see configmap references
kubectl describe pod web-app | grep -A 5 configmap
```

---

## 10. ConfigMaps vs Secrets

| Feature | ConfigMap | Secret |
| :--- | :--- | :--- |
| **Purpose** | Non-sensitive config | Sensitive data (passwords, tokens) |
| **Encoding** | Plain text | Base64 encoded |
| **Visibility** | Easy to view | Slightly obfuscated |
| **Use for** | DB host, log levels, URLs | DB passwords, API keys, certificates |
| **Size limit** | 1MB | 1MB |

**Example:**
```yaml
# ConfigMap (non-sensitive)
data:
  DB_HOST: mysql.prod.com
  DB_PORT: "3306"
  
# Secret (sensitive)
data:
  DB_PASSWORD: c3VwZXJzZWNyZXQ=  # Base64 encoded
```

---

## 11. Troubleshooting

### Issue 1: Pod Can't Find ConfigMap

**Symptom:**
```
Error: configmaps "app-config" not found
```

**Check:**
```bash
# Verify ConfigMap exists in same namespace as pod
kubectl get cm -n <namespace>

# Check pod events
kubectl describe pod <pod-name>
```

### Issue 2: Environment Variable is Empty

**Symptom:**
```bash
echo $DB_HOST
# (empty)
```

**Possible causes:**
1. Key name mismatch
2. ConfigMap doesn't exist
3. Wrong namespace

**Debug:**
```bash
# Check the exact key names
kubectl get cm app-config -o yaml

# Exec into pod and check env
kubectl exec -it web-app -- env | grep DB_HOST
```

### Issue 3: ConfigMap Updated but Pod Still Shows Old Values

**For environment variables:**
```bash
# Env vars don't auto-update - restart pod
kubectl rollout restart deployment <name>
```

**For volume mounts:**
```bash
# Wait ~60 seconds for kubelet to sync
# Then check inside container
kubectl exec -it web-app -- cat /etc/config/app.properties
```

---

## 12. CKA Exam Tips

### Task: "Create a ConfigMap from literals"

```bash
kubectl create configmap webapp-config \
  --from-literal=APP_COLOR=blue \
  --from-literal=APP_MODE=prod
```

### Task: "Create a pod that uses ConfigMap as environment variables"

```bash
# Step 1: Generate pod YAML
kubectl run webapp --image=nginx --dry-run=client -o yaml > pod.yaml

# Step 2: Edit to add configmap
vim pod.yaml
```

Add:
```yaml
spec:
  containers:
  - name: webapp
    image: nginx
    envFrom:
    - configMapRef:
        name: webapp-config
```

```bash
# Step 3: Apply
kubectl apply -f pod.yaml
```

### Task: "Mount ConfigMap as a volume"

```bash
# Generate pod
kubectl run webapp --image=nginx --dry-run=client -o yaml > pod.yaml
```

Edit to add:
```yaml
spec:
  containers:
  - name: webapp
    image: nginx
    volumeMounts:
    - name: config-volume
      mountPath: /etc/config
  volumes:
  - name: config-volume
    configMap:
      name: webapp-config
```

---

## Summary

!!! success "Key Takeaways"
    ✅ ConfigMaps store **non-sensitive** configuration as key-value pairs  
    ✅ Decouple configuration from application code  
    ✅ Three consumption methods: **env vars**, **envFrom**, and **volume mounts**  
    ✅ Environment variables **don't auto-update** when ConfigMap changes  
    ✅ Volume-mounted files **do auto-update** (with ~60s delay)  
    ✅ Use **Secrets** for sensitive data, not ConfigMaps  
    ✅ Name ConfigMaps descriptively and consider versioning  
    ✅ Maximum size: **1MB** per ConfigMap  

### Quick Command Reference

```bash
# Create
kubectl create cm <name> --from-literal=key=value
kubectl create cm <name> --from-file=file.txt

# View
kubectl get cm
kubectl get cm <name> -o yaml

# Use in pod (env)
env:
  - name: VAR
    valueFrom:
      configMapKeyRef:
        name: <cm-name>
        key: <key>

# Use in pod (volume)
volumes:
  - name: config
    configMap:
      name: <cm-name>
```
