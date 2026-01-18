# Types of Admission Controllers and Webhooks

Understanding the **types** of admission controllers and how they **interconnect** is crucial for mastering Kubernetes admission control.

---

## 1. The Complete Taxonomy

### High-Level Classification

```
┌─────────────────────────────────────────────────────────────────────┐
│                    ADMISSION CONTROLLERS                            │
│                                                                     │
│  ┌───────────────────────────┐   ┌───────────────────────────────┐ │
│  │  BUILT-IN                 │   │  DYNAMIC (WEBHOOKS)           │ │
│  │  (Compiled into apiserver)│   │  (External services)          │ │
│  └───────────────────────────┘   └───────────────────────────────┘ │
│              ↓                                  ↓                   │
│    ┌─────────────────┐                ┌─────────────────┐          │
│    │   MUTATING      │                │   MUTATING      │          │
│    │   - ServiceAcct │                │   - Webhooks    │          │
│    │   - DefaultSC   │                └─────────────────┘          │
│    └─────────────────┘                                              │
│              │                                                      │
│    ┌─────────────────┐                ┌─────────────────┐          │
│    │   VALIDATING    │                │   VALIDATING    │          │
│    │   - ResQuota    │                │   - Webhooks    │          │
│    │   - LimitRange  │                └─────────────────┘          │
│    └─────────────────┘                                              │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 2. Type 1: Built-in Admission Controllers

**Built-in admission controllers** are **compiled into** the kube-apiserver binary.

### Characteristics

| Aspect | Details |
|--------|---------|
| **Location** | Inside kube-apiserver binary |
| **Configuration** | `--enable-admission-plugins` flag |
| **Language** | Written in Go |
| **Performance** | Fast (in-process) |
| **Flexibility** | Limited (fixed logic) |
| **Examples** | ServiceAccount, ResourceQuota, NamespaceLifecycle |

### Sub-types

#### Type 1A: Built-in Mutating Controllers

**Purpose:** Modify requests before validation.

| Controller | What It Mutates |
|-----------|-----------------|
| **ServiceAccount** | Injects SA token volumes |
| **DefaultStorageClass** | Sets default StorageClass on PVCs |
| **DefaultTolerationSeconds** | Adds node taint tolerations |
| **PodSecurityDefaults** | Sets pod security labels |

**Example Flow:**
```
User submits Pod with no serviceAccountName
         ↓
ServiceAccount Controller (Built-in Mutating)
         ↓
Adds: serviceAccountName: default
Adds: volume mount for token
         ↓
Modified Pod → Sent to Validating Controllers
```

---

#### Type 1B: Built-in Validating Controllers

**Purpose:** Approve or reject requests.

| Controller | What It Validates |
|-----------|-------------------|
| **ResourceQuota** | Checks if within quota |
| **LimitRanger** | Checks if within limits |
| **NamespaceLifecycle** | Checks namespace existence |
| **PodSecurity** | Validates pod security standards |
| **NodeRestriction** | Validates kubelet permissions |

**Example Flow:**
```
Pod (already mutated) arrives
         ↓
ResourceQuota Controller (Built-in Validating)
         ↓
Check: Does this pod exceed namespace quota?
         ↓
YES → ❌ REJECT (Error to user)
NO  → ✅ APPROVE (Continue to next validator)
```

---

## 3. Type 2: Dynamic Admission Webhooks

**Dynamic admission webhooks** are **external HTTP services** that kube-apiserver calls.

### Characteristics

| Aspect | Details |
|--------|---------|
| **Location** | External service (pod, external server) |
| **Configuration** | `MutatingWebhookConfiguration` / `ValidatingWebhookConfiguration` |
| **Language** | Any (Python, Go, Node.js, etc.) |
| **Performance** | Slower (network call) |
| **Flexibility** | High (custom logic) |
| **Examples** | Istio sidecar injector, OPA Gatekeeper |

### Sub-types

#### Type 2A: MutatingAdmissionWebhook

**Purpose:** Call external service to mutate requests.

**How It Works:**
```
┌────────────────────────────────────────────────────────────┐
│  1. Pod creation request arrives                          │
└────────────────────────────────────────────────────────────┘
                       ↓
┌────────────────────────────────────────────────────────────┐
│  2. kube-apiserver calls MutatingWebhook                   │
│                                                            │
│     POST https://webhook-service.default.svc/mutate        │
│     {                                                      │
│       "request": {                                         │
│         "object": { /* Pod YAML */ }                       │
│       }                                                    │
│     }                                                      │
└────────────────────────────────────────────────────────────┘
                       ↓
┌────────────────────────────────────────────────────────────┐
│  3. Webhook service processes request                      │
│     - Runs custom logic (Go, Python, etc.)                 │
│     - Decides what to add/modify                           │
│     - Creates JSON Patch                                   │
└────────────────────────────────────────────────────────────┘
                       ↓
┌────────────────────────────────────────────────────────────┐
│  4. Webhook returns response                               │
│     {                                                      │
│       "response": {                                        │
│         "allowed": true,                                   │
│         "patchType": "JSONPatch",                          │
│         "patch": "W3sib3AiOiJhZGQi..."                     │
│       }                                                    │
│     }                                                      │
└────────────────────────────────────────────────────────────┘
                       ↓
┌────────────────────────────────────────────────────────────┐
│  5. kube-apiserver applies patch                           │
│     Original Pod + JSON Patch = Mutated Pod                │
└────────────────────────────────────────────────────────────┘
```

**Configuration:**
```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: MutatingWebhookConfiguration
metadata:
  name: example-mutating-webhook
webhooks:
- name: mutate.example.com
  clientConfig:
    service:
      name: webhook-service
      namespace: default
      path: /mutate
  rules:
  - operations: ["CREATE", "UPDATE"]
    apiGroups: [""]
    apiVersions: ["v1"]
    resources: ["pods"]
```

---

#### Type 2B: ValidatingAdmissionWebhook

**Purpose:** Call external service to validate requests.

**How It Works:**
```
┌────────────────────────────────────────────────────────────┐
│  1. Pod (already mutated) arrives for validation           │
└────────────────────────────────────────────────────────────┘
                       ↓
┌────────────────────────────────────────────────────────────┐
│  2. kube-apiserver calls ValidatingWebhook                 │
│                                                            │
│     POST https://validator.default.svc/validate            │
│     {                                                      │
│       "request": {                                         │
│         "object": { /* Mutated Pod YAML */ }               │
│       }                                                    │
│     }                                                      │
└────────────────────────────────────────────────────────────┘
                       ↓
┌────────────────────────────────────────────────────────────┐
│  3. Webhook service validates request                      │
│     - Checks custom policies                               │
│     - Validates against company rules                      │
│     - Returns ALLOW or DENY                                │
└────────────────────────────────────────────────────────────┘
                       ↓
┌────────────────────────────────────────────────────────────┐
│  4. Webhook returns response                               │
│     {                                                      │
│       "response": {                                        │
│         "allowed": false,                                  │
│         "status": {                                        │
│           "message": "Image not from approved registry"    │
│         }                                                  │
│       }                                                    │
│     }                                                      │
└────────────────────────────────────────────────────────────┘
                       ↓
┌────────────────────────────────────────────────────────────┐
│  5. kube-apiserver rejects or approves                     │
│     DENY → User gets error message                         │
│     ALLOW → Continue to next validator                     │
└────────────────────────────────────────────────────────────┘
```

**Configuration:**
```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  name: example-validating-webhook
webhooks:
- name: validate.example.com
  clientConfig:
    service:
      name: validator-service
      namespace: default
      path: /validate
  rules:
  - operations: ["CREATE", "UPDATE"]
    apiGroups: [""]
    apiVersions: ["v1"]
    resources: ["pods"]
```

---

## 4. How All Types Interconnect

### The Complete Admission Control Flow

```
┌──────────────────────────────────────────────────────────────────────────┐
│                      REQUEST ARRIVES AT API SERVER                       │
│                           kubectl apply -f pod.yaml                      │
└──────────────────────────────────────────────────────────────────────────┘
                                   ↓
┌──────────────────────────────────────────────────────────────────────────┐
│  AUTHENTICATION ✅                                                        │
└──────────────────────────────────────────────────────────────────────────┘
                                   ↓
┌──────────────────────────────────────────────────────────────────────────┐
│  AUTHORIZATION ✅                                                         │
└──────────────────────────────────────────────────────────────────────────┘
                                   ↓
┌──────────────────────────────────────────────────────────────────────────┐
│  PHASE 1: MUTATING ADMISSION (Sequential Execution)                      │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │ TYPE 1A: Built-in Mutating Controllers                            │ │
│  │                                                                    │ │
│  │ Controller 1: NamespaceLifecycle (check namespace exists)         │ │
│  │      ↓                                                             │ │
│  │ Controller 2: ServiceAccount (inject SA token)                    │ │
│  │      ↓                                                             │ │
│  │ Controller 3: DefaultStorageClass (set default SC)                │ │
│  │      ↓                                                             │ │
│  │ Controller 4: DefaultTolerationSeconds (add tolerations)          │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                   ↓                                      │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │ TYPE 2A: MutatingAdmissionWebhook                                 │ │
│  │                                                                    │ │
│  │ Webhook 1: Istio Sidecar Injector                                 │ │
│  │   POST https://istio-sidecar.istio-system.svc/inject              │ │
│  │   Response: Add istio-proxy container                             │ │
│  │      ↓                                                             │ │
│  │ Webhook 2: Vault Agent Injector                                   │ │
│  │   POST https://vault-agent.vault.svc/mutate                       │ │
│  │   Response: Add vault agent init container                        │ │
│  │      ↓                                                             │ │
│  │ Webhook 3: Image Policy Enforcer                                  │ │
│  │   POST https://image-policy.security.svc/mutate                   │ │
│  │   Response: Prepend registry URL to image                         │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  Result: Pod is now FULLY MUTATED                                        │
└──────────────────────────────────────────────────────────────────────────┘
                                   ↓
┌──────────────────────────────────────────────────────────────────────────┐
│  PHASE 2: VALIDATING ADMISSION (Parallel Execution)                     │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │ TYPE 1B: Built-in Validating Controllers                          │ │
│  │                                                                    │ │
│  │ Controller 1: LimitRanger           Controller 2: ResourceQuota   │ │
│  │ Check: Within limits? ✅             Check: Within quota? ✅       │ │
│  │                                                                    │ │
│  │ Controller 3: PodSecurity            Controller 4: NodeRestriction│ │
│  │ Check: Security policy? ✅           Check: Node perms? ✅         │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                   ↓                                      │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │ TYPE 2B: ValidatingAdmissionWebhook                               │ │
│  │                                                                    │ │
│  │ Webhook 1: OPA Gatekeeper          Webhook 2: Image Scanner       │ │
│  │ POST /validate                     POST /validate-image            │ │
│  │ Check: Policy compliant? ✅         Check: No vulnerabilities? ✅  │ │
│  │                                                                    │ │
│  │ Webhook 3: Custom Validator                                       │ │
│  │ POST /custom-validate                                              │ │
│  │ Check: Company rules? ✅                                           │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  IF ANY VALIDATOR REJECTS → ❌ REQUEST REJECTED                          │
│  IF ALL VALIDATORS APPROVE → ✅ CONTINUE                                 │
└──────────────────────────────────────────────────────────────────────────┘
                                   ↓
┌──────────────────────────────────────────────────────────────────────────┐
│  PERSIST TO ETCD ✅                                                       │
│  Pod is created with all mutations applied                               │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## 5. Built-in vs Webhook: Detailed Comparison

### Architecture Differences

```
┌─────────────────────────────────────────────────────────────────────┐
│  BUILT-IN ADMISSION CONTROLLERS                                     │
│                                                                     │
│   ┌─────────────────────────────────────────────────────┐          │
│   │                                                     │          │
│   │   ┌──────────────────────────────────────────┐     │          │
│   │   │         kube-apiserver                   │     │          │
│   │   │  ┌────────────────────────────────────┐  │     │          │
│   │   │  │  ServiceAccount Controller         │  │     │          │
│   │   │  │  (Compiled Go code)                │  │  ←──┼────────  │
│   │   │  │                                    │  │     │   Fast   │
│   │   │  │  ResourceQuota Controller          │  │     │  (in-    │
│   │   │  │  (Compiled Go code)                │  │     │  process)│
│   │   │  │                                    │  │     │          │
│   │   │  │  LimitRanger Controller            │  │     │          │
│   │   │  │  (Compiled Go code)                │  │     │          │
│   │   │  └────────────────────────────────────┘  │     │          │
│   │   └──────────────────────────────────────────┘     │          │
│   └─────────────────────────────────────────────────────┘          │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│  WEBHOOK ADMISSION CONTROLLERS                                      │
│                                                                     │
│   ┌──────────────────────────────────────────┐                     │
│   │         kube-apiserver                   │                     │
│   │  ┌────────────────────────────────────┐  │                     │
│   │  │  MutatingWebhook Plugin            │  │                     │
│   │  │  (Makes HTTP calls)                │  │                     │
│   │  └────────────────────────────────────┘  │                     │
│   └──────────────────┬───────────────────────┘                     │
│                      │ HTTP POST                                   │
│                      │ (Network call)                              │
│                      ↓                                              │
│   ┌──────────────────────────────────────────┐                     │
│   │  Webhook Service Pod                     │  ←───────────────  │
│   │  ┌────────────────────────────────────┐  │       Slower       │
│   │  │  Your custom code                  │  │     (network       │
│   │  │  (Python, Go, Node.js, etc.)       │  │      latency)      │
│   │  │                                    │  │                     │
│   │  │  - Istio sidecar injector          │  │                     │
│   │  │  - Vault agent injector            │  │                     │
│   │  │  - OPA Gatekeeper                  │  │                     │
│   │  │  - Custom validators               │  │                     │
│   │  └────────────────────────────────────┘  │                     │
│   └──────────────────────────────────────────┘                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Feature Comparison Table

| Feature | Built-in Controllers | Webhook Controllers |
|---------|---------------------|---------------------|
| **Performance** | ⚡ Very fast (in-process) | 🐌 Slower (HTTP call) |
| **Latency** | <1ms | 10-100ms+ |
| **Flexibility** | ❌ Fixed logic | ✅ Custom logic |
| **Language** | Go only | Any language |
| **Updates** | ❌ Requires apiserver restart | ✅ Update anytime |
| **Configuration** | API server flags | K8s resources (YAML) |
| **Debugging** | 🔴 Harder (recompile) | 🟢 Easier (logs, debug) |
| **Failure Impact** | ❌ API server crash | 🟡 Request timeout/fail |
| **Examples** | ServiceAccount, ResourceQuota | Istio, OPA, Vault |

---

## 6. Execution Order and Precedence

### Detailed Execution Sequence

```
REQUEST
   │
   ├─ Authentication
   │
   ├─ Authorization
   │
   ├─ MUTATING PHASE (Sequential)
   │   │
   │   ├─ Built-in Mutating Controllers (in configured order)
   │   │   ├─ NamespaceLifecycle
   │   │   ├─ LimitRanger (mutating part)
   │   │   ├─ ServiceAccount
   │   │   ├─ DefaultStorageClass
   │   │   ├─ DefaultTolerationSeconds
   │   │   └─ RuntimeClass
   │   │
   │   └─ MutatingAdmissionWebhooks (ordered by name, then creation time)
   │       ├─ istio-sidecar-injector
   │       ├─ vault-agent-injector
   │       └─ custom-mutator
   │
   ├─ VALIDATING PHASE (Parallel)
   │   │
   │   ├─ Built-in Validating Controllers (parallel)
   │   │   ├─ LimitRanger
   │   │   ├─ ResourceQuota
   │   │   ├─ PodSecurity
   │   │   └─ NodeRestriction
   │   │
   │   └─ ValidatingAdmissionWebhooks (parallel)
   │       ├─ gatekeeper-validator
   │       ├─ image-scanner
   │       └─ custom-validator
   │
   └─ Persist to etcd
```

**Key Points:**
1. **Mutating phase is SEQUENTIAL** - order matters!
2. **Validating phase is PARALLEL** - all run simultaneously
3. **Built-in before Webhooks** within each phase
4. **Any rejection stops the entire request**

---

## 7. Real-World Integration Examples

### Example 1: Complete Pod Creation with All Types

**Original Pod Submission:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp
  labels:
    app: myapp
spec:
  containers:
  - name: app
    image: nginx
    ports:
    - containerPort: 80
```

**After All Mutations (Built-in + Webhooks):**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp
  labels:
    app: myapp
    istio.io/rev: default                          # ← Istio webhook
  annotations:
    vault.hashicorp.com/agent-inject: "true"       # ← Vault webhook
    prometheus.io/scrape: "true"                   # ← Prometheus webhook
spec:
  serviceAccountName: default                      # ← ServiceAccount (built-in)
  automountServiceAccountToken: true
  tolerations:                                     # ← DefaultTolerationSeconds (built-in)
  - key: node.kubernetes.io/not-ready
    operator: Exists
    effect: NoExecute
    tolerationSeconds: 300
  initContainers:                                  # ← Vault webhook
  - name: vault-agent-init
    image: vault:1.12.1
  containers:
  - name: app
    image: myregistry.company.com/nginx:latest     # ← Image Policy webhook (modified!)
    ports:
    - containerPort: 80
    volumeMounts:                                  # ← ServiceAccount (built-in)
    - name: kube-api-access-xxxxx
      mountPath: /var/run/secrets/kubernetes.io/serviceaccount
  - name: istio-proxy                              # ← Istio webhook (added!)
    image: istio/proxyv2:1.17.1
    ports:
    - containerPort: 15001
  volumes:
  - name: kube-api-access-xxxxx                    # ← ServiceAccount (built-in)
    projected:
      sources:
      - serviceAccountToken: ...
```

---

### Example 2: Multi-Cluster Service Mesh

**Scenario:** Using both built-in and webhook types together.

```
┌────────────────────────────────────────────────────────────┐
│  Pod Creation Request                                      │
└────────────────────────────────────────────────────────────┘
                         ↓
        ┌────────────────────────────────┐
        │ Built-in: ServiceAccount       │
        │ Adds: SA token volume          │
        └────────────────────────────────┘
                         ↓
        ┌────────────────────────────────┐
        │ Webhook: Istio Sidecar         │
        │ Adds: Envoy proxy container    │
        └────────────────────────────────┘
                         ↓
        ┌────────────────────────────────┐
        │ Webhook: Linkerd Injector      │
        │ Adds: Linkerd proxy container  │
        └────────────────────────────────┘
                         ↓
        ┌────────────────────────────────┐
        │ Built-in: ResourceQuota        │
        │ Validates: Within quota?       │
        └────────────────────────────────┘
                         ↓
        ┌────────────────────────────────┐
        │ Webhook: OPA Gatekeeper        │
        │ Validates: Policy compliant?   │
        └────────────────────────────────┘
                         ↓
                   ✅ APPROVED
```

---

## 8. Configuration Patterns

### Pattern 1: Only Built-in Controllers (Simple)

```yaml
# /etc/kubernetes/manifests/kube-apiserver.yaml
--enable-admission-plugins=NamespaceLifecycle,LimitRanger,ServiceAccount,ResourceQuota
```

**Use case:** Simple clusters without custom policies

---

### Pattern 2: Built-in + Webhooks (Production)

```yaml
# API Server
--enable-admission-plugins=NamespaceLifecycle,LimitRanger,ServiceAccount,ResourceQuota,MutatingAdmissionWebhook,ValidatingAdmissionWebhook
```

```yaml
# MutatingWebhookConfiguration
apiVersion: admissionregistration.k8s.io/v1
kind: MutatingWebhookConfiguration
metadata:
  name: istio-sidecar-injector
webhooks:
- name: sidecar-injector.istio.io
  clientConfig:
    service:
      name: istiod
      namespace: istio-system
      path: /inject
  rules:
  - operations: ["CREATE"]
    apiGroups: [""]
    apiVersions: ["v1"]
    resources: ["pods"]
```

**Use case:** Production clusters with service mesh, policy enforcement

---

## 9. Troubleshooting the Interconnections

### Issue: "My pod doesn't have the injected sidecar"

**Check the chain:**

```bash
# 1. Is MutatingAdmissionWebhook controller enabled?
kubectl -n kube-system get pod kube-apiserver-<node> -o yaml | grep enable-admission-plugins

# 2. Does the webhook configuration exist?
kubectl get mutatingwebhookconfigurations

# 3. Is the webhook service running?
kubectl get svc -n istio-system istiod

# 4. Check webhook logs
kubectl logs -n istio-system deployment/istiod -f

# 5. Test with dry-run to see mutations
kubectl apply -f pod.yaml --dry-run=server -o yaml
```

---

### Issue: "Request taking too long"

**Likely cause:** Too many webhooks or slow webhook services.

```bash
# Check all webhooks
kubectl get mutatingwebhookconfigurations
kubectl get validatingwebhookconfigurations

# Check webhook timeouts
kubectl get mutatingwebhookconfigurations <name> -o yaml | grep timeoutSeconds

# Monitor API server latency
kubectl get --raw /metrics | grep apiserver_admission_webhook_admission_duration_seconds
```

---

## 10. Summary: The Complete Picture

### Type Matrix

| Type | Category | Location | Performance | Flexibility | Examples |
|------|----------|----------|-------------|-------------|----------|
| **1A** | Built-in Mutating | kube-apiserver | ⚡ Very Fast | ❌ Fixed | ServiceAccount |
| **1B** | Built-in Validating | kube-apiserver | ⚡ Very Fast | ❌ Fixed | ResourceQuota |
| **2A** | Webhook Mutating | External Pod | 🐌 Slower | ✅ Custom | Istio Injector |
| **2B** | Webhook Validating | External Pod | 🐌 Slower | ✅ Custom | OPA Gatekeeper |

### Interconnection Map

```
┌─────────────────────────────────────────────────────────────────┐
│                    ADMISSION CONTROL SYSTEM                     │
│                                                                 │
│  Authentication → Authorization                                 │
│         ↓                                                       │
│  ┌─────────────────────────────────────────────┐                │
│  │  MUTATING (Sequential)                      │                │
│  │  ┌───────────────┐   ┌─────────────────┐   │                │
│  │  │ Built-in      │→→→│ Webhooks        │   │                │
│  │  │ (Type 1A)     │   │ (Type 2A)       │   │                │
│  │  └───────────────┘   └─────────────────┘   │                │
│  └─────────────────────────────────────────────┘                │
│         ↓                                                       │
│  ┌─────────────────────────────────────────────┐                │
│  │  VALIDATING (Parallel)                      │                │
│  │  ┌───────────────┐   ┌─────────────────┐   │                │
│  │  │ Built-in      │║║║│ Webhooks        │   │                │
│  │  │ (Type 1B)     │║║║│ (Type 2B)       │   │                │
│  │  └───────────────┘   └─────────────────┘   │                │
│  └─────────────────────────────────────────────┘                │
│         ↓                                                       │
│  Persist to etcd                                                │
└─────────────────────────────────────────────────────────────────┘
```

---

## Further Reading

- **[Admission Controllers Reference](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/)**  
  Complete list of all built-in controllers

- **[Dynamic Admission Control](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/)**  
  Webhook configuration and implementation

- **[Admission Controller Metrics](https://kubernetes.io/docs/concepts/cluster-administration/system-metrics/#admission-control)**  
  Monitoring admission controller performance
