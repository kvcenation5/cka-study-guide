# Mutating Admission Controllers in Kubernetes

**Mutating Admission Controllers** are plugins that **intercept and modify** API requests before they are persisted to etcd. They can add, remove, or change fields in resource specifications.

---

## 1. The "Security Screening with Baggage Tagging" Analogy

Think of mutating admission controllers like **airport security that modifies your luggage**:

```
You arrive at airport with a bag
         ↓
Security Checkpoint (Authentication) ✅
         ↓
Boarding Pass Check (Authorization) ✅
         ↓
Mutating Security:
  - Adds a baggage tag with tracking number
  - Inserts a security inspection notice
  - Attaches a fragile sticker (if needed)
         ↓
Your bag is now "mutated" with additional items
         ↓
Validating Security:
  - Checks if bag meets weight limit
  - Verifies no prohibited items
         ↓
Bag is loaded onto plane (etcd)
```

**Your pod goes through the same process! It gets "tags" (labels, annotations, volumes) added automatically.**

---

## 2. What Are Mutating Admission Controllers?

Mutating admission controllers **intercept API requests** and **modify them** before validation and persistence.

### Key Characteristics

| Aspect | Description |
|--------|-------------|
| **When They Run** | After authentication/authorization, BEFORE validating admission |
| **What They Do** | Add, remove, or modify fields in the request |
| **Execution Order** | Sequential (one after another) |
| **Can Reject?** | Yes, if mutation fails |
| **Examples** | ServiceAccount injection, DefaultStorageClass assignment |

---

## 3. The Mutation Pipeline

```
┌─────────────────────────────────────────────────────────────────┐
│  CLIENT SUBMITS REQUEST                                         │
│  kubectl apply -f pod.yaml                                      │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  AUTHENTICATION ✅                                               │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  AUTHORIZATION ✅                                                │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  MUTATING ADMISSION CONTROLLERS (Sequential)                    │
│                                                                 │
│  Original Request:                                              │
│  ┌────────────────────────────────────────────┐                │
│  │ apiVersion: v1                             │                │
│  │ kind: Pod                                  │                │
│  │ metadata:                                  │                │
│  │   name: nginx                              │                │
│  │ spec:                                      │                │
│  │   containers:                              │                │
│  │   - name: nginx                            │                │
│  │     image: nginx                           │                │
│  └────────────────────────────────────────────┘                │
│                                                                 │
│  Controller 1: ServiceAccount                                   │
│  ┌────────────────────────────────────────────┐                │
│  │ ACTION: Add serviceAccountName             │                │
│  │ ACTION: Add volume for SA token            │                │
│  └────────────────────────────────────────────┘                │
│                     ↓                                           │
│  Modified Request:                                              │
│  ┌────────────────────────────────────────────┐                │
│  │ spec:                                      │                │
│  │   serviceAccountName: default  ← ADDED     │                │
│  │   volumes:                                 │                │
│  │   - name: sa-token             ← ADDED     │                │
│  └────────────────────────────────────────────┘                │
│                                                                 │
│  Controller 2: DefaultTolerationSeconds                         │
│  ┌────────────────────────────────────────────┐                │
│  │ ACTION: Add default tolerations            │                │
│  └────────────────────────────────────────────┘                │
│                     ↓                                           │
│  Modified Request:                                              │
│  ┌────────────────────────────────────────────┐                │
│  │ spec:                                      │                │
│  │   tolerations:                 ← ADDED     │                │
│  │   - key: node.kubernetes.io/not-ready      │                │
│  │     operator: Exists                       │                │
│  │     effect: NoExecute                      │                │
│  │     tolerationSeconds: 300                 │                │
│  └────────────────────────────────────────────┘                │
│                                                                 │
│  Controller 3: MutatingWebhook                                  │
│  ┌────────────────────────────────────────────┐                │
│  │ ACTION: Call external webhook              │                │
│  │ ACTION: Add sidecar container              │                │
│  └────────────────────────────────────────────┘                │
│                     ↓                                           │
│  Final Mutated Request:                                         │
│  ┌────────────────────────────────────────────┐                │
│  │ spec:                                      │                │
│  │   serviceAccountName: default              │                │
│  │   containers:                              │                │
│  │   - name: nginx                            │                │
│  │     image: nginx                           │                │
│  │   - name: istio-proxy      ← ADDED         │                │
│  │     image: istio/proxyv2                   │                │
│  │   volumes: [...]                           │                │
│  │   tolerations: [...]                       │                │
│  └────────────────────────────────────────────┘                │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  VALIDATING ADMISSION CONTROLLERS                               │
│  (Validate the mutated request)                                 │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  PERSIST TO ETCD ✅                                              │
└─────────────────────────────────────────────────────────────────┘
```

---

## 4. Built-in Mutating Admission Controllers

### ServiceAccount (Most Common)

**Purpose:** Automatically injects ServiceAccount credentials into pods.

**What it adds:**
- `spec.serviceAccountName: default` (if not specified)
- Volume mount for ServiceAccount token
- Projected volume with token, CA cert, and namespace

**Before:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  containers:
  - name: nginx
    image: nginx
```

**After ServiceAccount mutation:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  serviceAccountName: default                    # ← ADDED
  automountServiceAccountToken: true             # ← ADDED
  containers:
  - name: nginx
    image: nginx
    volumeMounts:                                # ← ADDED
    - name: kube-api-access-xxxxx
      mountPath: /var/run/secrets/kubernetes.io/serviceaccount
      readOnly: true
  volumes:                                       # ← ADDED
  - name: kube-api-access-xxxxx
    projected:
      sources:
      - serviceAccountToken:
          path: token
          expirationSeconds: 3607
      - configMap:
          name: kube-root-ca.crt
          items:
          - key: ca.crt
            path: ca.crt
      - downwardAPI:
          items:
          - path: namespace
            fieldRef:
              fieldPath: metadata.namespace
```

---

### DefaultStorageClass

**Purpose:** Assigns the default StorageClass to PVCs that don't specify one.

**Before:**
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: myclaim
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1Gi
  # No storageClassName specified
```

**After DefaultStorageClass mutation:**
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: myclaim
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: gp2             # ← ADDED (default storage class)
  resources:
    requests:
      storage: 1Gi
```

---

### DefaultTolerationSeconds

**Purpose:** Adds default tolerations for `node.kubernetes.io/not-ready` and `node.kubernetes.io/unreachable` taints.

**Before:**
```yaml
spec:
  containers:
  - name: app
    image: myapp
```

**After DefaultTolerationSeconds mutation:**
```yaml
spec:
  tolerations:                                   # ← ADDED
  - key: node.kubernetes.io/not-ready
    operator: Exists
    effect: NoExecute
    tolerationSeconds: 300
  - key: node.kubernetes.io/unreachable
    operator: Exists
    effect: NoExecute
    tolerationSeconds: 300
  containers:
  - name: app
    image: myapp
```

**Why?** Gives pods 5 minutes (300 seconds) to be evicted when a node becomes not-ready.

---

### PodPreset (Deprecated)

**Purpose:** Inject environment variables, volumes, and other config into pods matching a label selector.

**Status:** ❌ Removed in Kubernetes 1.20+ (use MutatingWebhooks instead)

---

## 5. Custom Mutating Admission Webhooks

For custom mutation logic, use **MutatingAdmissionWebhook**.

### How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│  1. User creates a Pod                                          │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  2. API Server calls MutatingWebhook                            │
│     POST /mutate HTTP/1.1                                       │
│     {                                                           │
│       "request": {                                              │
│         "object": { /* Pod YAML */ }                            │
│       }                                                         │
│     }                                                           │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  3. Your Webhook Service processes request                      │
│     - Analyzes the pod spec                                     │
│     - Decides what to add/modify                                │
│     - Creates a JSON Patch                                      │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  4. Webhook returns AdmissionReview response                    │
│     {                                                           │
│       "response": {                                             │
│         "allowed": true,                                        │
│         "patchType": "JSONPatch",                               │
│         "patch": "base64-encoded-json-patch"                    │
│       }                                                         │
│     }                                                           │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  5. API Server applies the patch                                │
│     Original Pod + JSON Patch = Mutated Pod                     │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  6. Continue to Validating Admission                            │
└─────────────────────────────────────────────────────────────────┘
```

### Example: Sidecar Injector Webhook

**MutatingWebhookConfiguration:**

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: MutatingWebhookConfiguration
metadata:
  name: sidecar-injector
webhooks:
- name: sidecar.example.com
  clientConfig:
    service:
      name: sidecar-injector
      namespace: default
      path: /mutate
    caBundle: LS0tLS1CRUdJTi... # Base64 encoded CA cert
  rules:
  - operations: ["CREATE"]
    apiGroups: [""]
    apiVersions: ["v1"]
    resources: ["pods"]
  admissionReviewVersions: ["v1"]
  sideEffects: None
  failurePolicy: Fail  # Reject if webhook fails
```

**Webhook Service Logic (Pseudocode):**

```python
@app.route('/mutate', methods=['POST'])
def mutate():
    request = flask.request.json
    pod = request['request']['object']
    
    # Check if pod needs sidecar
    if pod.get('metadata', {}).get('annotations', {}).get('inject-sidecar') == 'true':
        # Create JSON Patch to add sidecar container
        patch = [
            {
                "op": "add",
                "path": "/spec/containers/-",
                "value": {
                    "name": "sidecar",
                    "image": "sidecar:v1",
                    "ports": [{"containerPort": 8080}]
                }
            }
        ]
        
        response = {
            "response": {
                "uid": request['request']['uid'],
                "allowed": True,
                "patchType": "JSONPatch",
                "patch": base64.b64encode(json.dumps(patch).encode()).decode()
            }
        }
    else:
        # No mutation needed
        response = {
            "response": {
                "uid": request['request']['uid'],
                "allowed": True
            }
        }
    
    return json.dumps(response)
```

---

## 6. Real-World Use Cases

### Use Case 1: Istio Service Mesh Sidecar Injection

**Problem:** Every pod in the service mesh needs an Envoy proxy sidecar.

**Solution:** Mutating webhook automatically injects the `istio-proxy` container.

**Before:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp
  labels:
    app: myapp
spec:
  containers:
  - name: myapp
    image: myapp:latest
```

**After Istio mutation:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp
  labels:
    app: myapp
  annotations:
    sidecar.istio.io/status: '{"version":"..."}'  # ← ADDED
spec:
  initContainers:                                 # ← ADDED
  - name: istio-init
    image: istio/proxyv2
  containers:
  - name: myapp
    image: myapp:latest
  - name: istio-proxy                             # ← ADDED
    image: istio/proxyv2
    ports:
    - containerPort: 15001
```

---

### Use Case 2: Vault Agent Injector

**Problem:** Applications need secrets from HashiCorp Vault.

**Solution:** Mutating webhook injects Vault agent as init container and sidecar.

**Annotation:**
```yaml
metadata:
  annotations:
    vault.hashicorp.com/agent-inject: "true"
    vault.hashicorp.com/role: "myapp"
    vault.hashicorp.com/agent-inject-secret-db: "database/creds/myapp"
```

**Mutation adds:**
- Init container to fetch secrets
- Shared volume for secrets
- Sidecar to rotate secrets

---

### Use Case 3: Image Policy Enforcement

**Problem:** Ensure all images come from approved registries.

**Solution:** Mutating webhook prepends registry URL.

**Before:**
```yaml
spec:
  containers:
  - name: app
    image: nginx:latest
```

**After mutation:**
```yaml
spec:
  containers:
  - name: app
    image: myregistry.company.com/nginx:latest  # ← MODIFIED
```

---

### Use Case 4: Resource Limit Injection

**Problem:** Developers forget to set resource limits.

**Solution:** Mutating webhook adds default limits.

**Before:**
```yaml
spec:
  containers:
  - name: app
    image: myapp
```

**After mutation:**
```yaml
spec:
  containers:
  - name: app
    image: myapp
    resources:                           # ← ADDED
      requests:
        memory: "128Mi"
        cpu: "100m"
      limits:
        memory: "256Mi"
        cpu: "200m"
```

---

## 7. JSON Patch Operations

Mutating webhooks use **RFC 6902 JSON Patch** format.

### Supported Operations

| Operation | Description | Example |
|-----------|-------------|---------|
| **add** | Add a new field | Add a label |
| **remove** | Remove a field | Remove an annotation |
| **replace** | Replace a field value | Change image tag |
| **move** | Move a field | Reorganize structure |
| **copy** | Copy a field | Duplicate a value |
| **test** | Test a value | Conditional patching |

### Example Patches

**Add a Label:**
```json
[
  {
    "op": "add",
    "path": "/metadata/labels/team",
    "value": "backend"
  }
]
```

**Add a Sidecar Container:**
```json
[
  {
    "op": "add",
    "path": "/spec/containers/-",
    "value": {
      "name": "sidecar",
      "image": "sidecar:v1"
    }
  }
]
```

**Replace Image:**
```json
[
  {
    "op": "replace",
    "path": "/spec/containers/0/image",
    "value": "myregistry.com/nginx:v2"
  }
]
```

**Add Environment Variable:**
```json
[
  {
    "op": "add",
    "path": "/spec/containers/0/env/-",
    "value": {
      "name": "INJECTED_BY",
      "value": "webhook"
    }
  }
]
```

---

## 8. Debugging Mutating Webhooks

### Enable Audit Logging

```yaml
# /etc/kubernetes/manifests/kube-apiserver.yaml
- --audit-log-path=/var/log/kubernetes/audit.log
- --audit-policy-file=/etc/kubernetes/audit-policy.yaml
```

**Audit Policy:**
```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: RequestResponse
  verbs: ["create"]
  resources:
  - group: ""
    resources: ["pods"]
```

### Check Webhook Logs

```bash
# View webhook service logs
kubectl logs -n default deployment/sidecar-injector -f
```

### Test Webhook Manually

```bash
# Dry-run to see mutations
kubectl apply -f pod.yaml --dry-run=server -o yaml
```

### Common Issues

**Issue 1: Webhook Timeout**
```
Error: context deadline exceeded calling webhook
```

**Fix:** Check if webhook service is running and accessible.

**Issue 2: Invalid Patch**
```
Error: invalid JSON patch
```

**Fix:** Validate JSON patch format and paths.

**Issue 3: Certificate Issues**
```
Error: x509: certificate signed by unknown authority
```

**Fix:** Ensure CA bundle in MutatingWebhookConfiguration matches webhook cert.

---

## 9. Best Practices

### DO's ✅

| Practice | Why |
|----------|-----|
| **Set failurePolicy: Fail** | Prevent unmodified resources if webhook is down |
| **Use namespaceSelector** | Target specific namespaces |
| **Set timeoutSeconds** | Prevent hanging (default: 10s) |
| **Validate patches** | Ensure valid JSON patch format |
| **Log all mutations** | Audit trail for debugging |
| **Version your webhooks** | Use versioned admission review |

### DON'Ts ❌

| Practice | Why |
|----------|-----|
| **Don't mutate kube-system** | Can break cluster |
| **Don't have side effects** | Webhooks should be idempotent |
| **Don't make external calls** | Webhook timeout issues |
| **Don't modify UID/name** | Immutable fields |
| **Don't chain too many** | Performance impact |

---

## 10. CKA Exam Relevance

### What You Need to Know

**For the CKA exam:**
1. ✅ Understand that mutating controllers **modify** requests
2. ✅ Know they run **before** validating controllers
3. ✅ Recognize common mutations (ServiceAccount injection)
4. ✅ Know how to enable/disable mutating controllers
5. 🟡 Basic understanding of webhooks (concept level)

**Less likely to be tested:**
- ❌ Writing webhook code
- ❌ JSON patch syntax details
- ❌ Certificate management for webhooks

### Exam Scenarios

**Scenario: "Why does my pod have extra containers?"**

**Answer:** Check for mutating webhooks:
```bash
kubectl get mutatingwebhookconfigurations
kubectl describe mutatingwebhookconfiguration <name>
```

**Scenario: "How to disable ServiceAccount injection?"**

**Answer:** 
```yaml
spec:
  automountServiceAccountToken: false
```

---

## Summary

!!! success "Key Takeaways"
    ✅ Mutating controllers **modify** API requests before persistence  
    ✅ They run **sequentially** after authentication/authorization  
    ✅ Common mutations: **ServiceAccount injection**, **DefaultStorageClass**, **tolerations**  
    ✅ Custom mutations use **MutatingAdmissionWebhook**  
    ✅ Webhooks return **JSON Patch** to modify resources  
    ✅ Real-world uses: **Istio sidecar**, **Vault agent**, **image policy**  
    ✅ Always runs **before** validating admission controllers  
    ✅ Can **reject** requests if mutation fails  

### Quick Commands

```bash
# List mutating webhooks
kubectl get mutatingwebhookconfigurations

# Describe a webhook
kubectl describe mutatingwebhookconfiguration <name>

# Test with dry-run (see mutations)
kubectl apply -f pod.yaml --dry-run=server -o yaml

# Check which mutating controllers are enabled
kubectl -n kube-system get pod kube-apiserver-<node> -o yaml | grep enable-admission-plugins
```

---

## Further Reading

- **[Dynamic Admission Control](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/)**  
  Official Kubernetes documentation on webhooks

- **[Admission Webhook Example](https://github.com/kubernetes/kubernetes/tree/master/test/images/agnhost/webhook)**  
  Reference implementation from Kubernetes project

- **[Istio Sidecar Injection](https://istio.io/latest/docs/setup/additional-setup/sidecar-injection/)**  
  Real-world example of mutating webhooks in production
