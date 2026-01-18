# Admission Controllers in Kubernetes

**Admission Controllers** are plugins that intercept requests to the Kubernetes API server **after authentication and authorization** but **before the object is persisted** in etcd. They can modify (mutate) or reject requests.

---

## 1. The "Security Checkpoint" Analogy

Think of admission controllers like **airport security checkpoints**:

```
You (User) → Passport Check (Authentication) → Visa Check (Authorization) → Security Screening (Admission) → Gate (etcd)
                    ✅                              ✅                         🔍                    ✅
```

**What happens at each stage:**
1. **Authentication**: "Who are you?" (Are you a valid user?)
2. **Authorization**: "What can you do?" (Do you have permission?)
3. **Admission Control**: "Is this request safe and compliant?" (Does it follow cluster policies?)
4. **Persistence**: Store the object in etcd

---

## 2. What Are Admission Controllers?

Admission controllers are **compiled into the kube-apiserver binary** and can only be configured by administrators.

### Key Characteristics

| Feature | Description |
|---------|-------------|
| **Location** | Run inside kube-apiserver |
| **Timing** | After authentication/authorization, before persistence |
| **Types** | Mutating (modify requests) and Validating (approve/reject) |
| **Configuration** | Via `--enable-admission-plugins` flag |
| **Extensibility** | Custom webhooks (MutatingWebhookConfiguration, ValidatingWebhookConfiguration) |

---

## 3. The Two Types of Admission Controllers

### Mutating Admission Controllers

**Purpose**: **Modify** the request before it's persisted.

**Example**: Automatically inject a sidecar container into every pod.

```yaml
# Original request
apiVersion: v1
kind: Pod
metadata:
  name: web-app
spec:
  containers:
  - name: nginx
    image: nginx

# After MutatingAdmission
apiVersion: v1
kind: Pod
metadata:
  name: web-app
spec:
  containers:
  - name: nginx
    image: nginx
  - name: sidecar-proxy    # ← Injected by admission controller!
    image: envoy:latest
```

### Validating Admission Controllers

**Purpose**: **Validate** the request and reject if it violates policies.

**Example**: Reject pods that request more than 4 CPUs.

```yaml
# Request
spec:
  containers:
  - name: app
    resources:
      requests:
        cpu: "8"    # ← Exceeds limit!

# Response from ValidatingAdmission
Error: Pod cpu request exceeds cluster policy maximum of 4 cores
```

---

## 4. The Admission Control Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    REQUEST TO API SERVER                        │
│                     (kubectl apply -f pod.yaml)                 │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 1: AUTHENTICATION                                        │
│  Plugin: X509, ServiceAccount, OIDC, etc.                       │
│  Question: "Who are you?"                                       │
│  Result: ✅ User identified as "alice@example.com"               │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 2: AUTHORIZATION                                         │
│  Plugin: RBAC, ABAC, Webhook, etc.                              │
│  Question: "Can you create pods in namespace 'prod'?"           │
│  Result: ✅ Allowed (alice has pod:create permission)            │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 3A: MUTATING ADMISSION CONTROL                           │
│                                                                 │
│  Controllers run in sequence:                                   │
│  1. NamespaceLifecycle    ✅ (namespace exists)                 │
│  2. ServiceAccount        ✅ (inject SA token)                  │
│  3. MutatingWebhook       ✅ (add sidecar container)            │
│                                                                 │
│  Result: Pod object modified                                    │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 3B: VALIDATING ADMISSION CONTROL                         │
│                                                                 │
│  Controllers run in parallel:                                   │
│  1. ResourceQuota         ✅ (within quota)                     │
│  2. LimitRanger           ✅ (within limits)                    │
│  3. PodSecurityPolicy     ✅ (meets security requirements)      │
│  4. ValidatingWebhook     ✅ (passes custom validation)         │
│                                                                 │
│  Result: Pod approved                                           │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 4: PERSISTENCE                                           │
│  Write object to etcd                                           │
│  Result: ✅ Pod created successfully                             │
└─────────────────────────────────────────────────────────────────┘
```

### Key Point: Order Matters

**Mutating → Validating**

Why? Because mutating controllers modify the object, validation must happen **after** all modifications are complete.

---

## 5. Built-in Admission Controllers

Kubernetes comes with many built-in admission controllers. Here are the most important ones for CKA:

### Essential Admission Controllers (Usually Enabled)

| Name | Type | What It Does | CKA Importance |
|------|------|--------------|----------------|
| **NamespaceLifecycle** | Validating | Prevents creating resources in non-existent or terminating namespaces | High |
| **LimitRanger** | Validating | Enforces LimitRange constraints | High |
| **ServiceAccount** | Mutating | Injects default ServiceAccount if not specified | High |
| **ResourceQuota** | Validating | Enforces ResourceQuota limits | High |
| **DefaultStorageClass** | Mutating | Assigns default StorageClass to PVCs | Medium |
| **DefaultTolerationSeconds** | Mutating | Sets default toleration for taints | Low |
| **MutatingAdmissionWebhook** | Mutating | Calls external webhooks for custom mutation | Medium |
| **ValidatingAdmissionWebhook** | Validating | Calls external webhooks for custom validation | Medium |
| **PodSecurityPolicy** | Validating | (Deprecated) Enforces pod security standards | Low (deprecated in 1.25) |
| **NodeRestriction** | Validating | Limits what kubelets can modify | Medium |

### Other Important Ones

| Name | What It Does |
|------|--------------|
| **AlwaysPullImages** | Forces image pull even if already cached |
| **DenyEscalatingExec** | Prevents `exec` into privileged pods |
| **ImagePolicyWebhook** | Validates images against external policy |
| **PersistentVolumeClaimResize** | Allows PVC expansion |
| **Priority** | Sets pod priority based on PriorityClass |
| **StorageObjectInUseProtection** | Prevents deletion of in-use PVs/PVCs |

---

## 6. Default Admission Controllers

### Enabled by Default (Kubernetes 1.28+)

These admission controllers are **automatically enabled** in most Kubernetes distributions:

| Controller Name | Type | Why Enabled by Default |
|----------------|------|------------------------|
| **NamespaceLifecycle** | Validating | Prevents resources in non-existent/terminating namespaces |
| **LimitRanger** | Validating | Enforces LimitRange constraints |
| **ServiceAccount** | Mutating | Auto-injects ServiceAccount tokens |
| **DefaultStorageClass** | Mutating | Assigns default StorageClass to PVCs |
| **DefaultTolerationSeconds** | Mutating | Sets default toleration for node taints |
| **MutatingAdmissionWebhook** | Mutating | Enables custom mutation webhooks |
| **ValidatingAdmissionWebhook** | Validating | Enables custom validation webhooks |
| **ResourceQuota** | Validating | Enforces ResourceQuota limits |
| **Priority** | Validating | Handles pod priority scheduling |
| **TaintNodesByCondition** | Mutating | Taints nodes based on conditions |
| **PodSecurity** | Validating | Enforces Pod Security Standards (replaces PSP) |
| **StorageObjectInUseProtection** | Validating | Prevents deletion of in-use PVs/PVCs |
| **PersistentVolumeClaimResize** | Validating | Allows PVC expansion |
| **RuntimeClass** | Validating | Validates RuntimeClass references |
| **CertificateApproval** | Validating | Validates certificate signing requests |
| **CertificateSigning** | Validating | Signs certificates |
| **CertificateSubjectRestriction** | Validating | Restricts certificate subjects |

### NOT Enabled by Default

These require manual enablement via `--enable-admission-plugins`:

| Controller Name | Type | Why Not Default | Use Case |
|----------------|------|-----------------|----------|
| **AlwaysPullImages** | Mutating | Performance impact | Multi-tenant clusters |
| **NodeRestriction** | Validating | May break some setups | Restrict kubelet permissions |
| **ImagePolicyWebhook** | Validating | Requires external service | Image scanning/validation |
| **PodSecurityPolicy** | Validating | Deprecated in 1.25+ | Use PodSecurity instead |
| **DenyEscalatingExec** | Validating | May break debugging | Prevent exec into privileged pods |
| **EventRateLimit** | Validating | Requires configuration | Prevent event flooding |
| **ExtendedResourceToleration** | Mutating | Specific use case | GPU/FPGA tolerations |
| **PodNodeSelector** | Validating | Namespace-specific | Force node selection per namespace |

---

## 7. How to List Admission Controllers

### Method 1: Check Currently Enabled Controllers

```bash
# Get the API server pod name
kubectl get pod -n kube-system | grep kube-apiserver

# View enabled admission plugins
kubectl -n kube-system get pod kube-apiserver-<node-name> -o yaml | grep enable-admission-plugins
```

**Example Output:**
```
--enable-admission-plugins=NamespaceLifecycle,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota,MutatingAdmissionWebhook,ValidatingAdmissionWebhook
```

### Method 2: Check Static Pod Manifest (Control Plane)

```bash
# SSH to control plane node
ssh controlplane

# View the manifest
cat /etc/kubernetes/manifests/kube-apiserver.yaml | grep enable-admission-plugins
```

### Method 3: List ALL Available Admission Plugins

```bash
# This shows all admission plugins compiled into kube-apiserver
kube-apiserver -h | grep -A 30 enable-admission-plugins
```

**Example Output:**
```
--enable-admission-plugins strings
      admission plugins that should be enabled in addition to default 
      enabled ones (NamespaceLifecycle, LimitRanger, ServiceAccount...).
      Comma-delimited list of admission plugins: ..., AlwaysPullImages,
      CertificateApproval, CertificateSigning, ...
```

### Method 4: Describe API Server Pod

```bash
# More detailed view
kubectl -n kube-system describe pod kube-apiserver-<node-name> | grep -i admission
```

**Example Output:**
```
--enable-admission-plugins=NamespaceLifecycle,LimitRanger,ServiceAccount...
--disable-admission-plugins=
```

### Method 5: Check Which Plugins Are Actually Running

```bash
# Extract just the enabled plugins list
kubectl -n kube-system get pod kube-apiserver-<node-name> -o jsonpath='{.spec.containers[0].command}' | grep -o 'enable-admission-plugins=[^"]*' | cut -d= -f2
```

**Example Output:**
```
NamespaceLifecycle,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota
```

### Method 6: Check Both Enabled and Disabled

```bash
# See what's enabled
kubectl -n kube-system get pod kube-apiserver-<node-name> -o yaml | grep enable-admission-plugins

# See what's explicitly disabled
kubectl -n kube-system get pod kube-apiserver-<node-name> -o yaml | grep disable-admission-plugins
```

---

## 8. Viewing Admission Controllers - Complete Reference

### Quick Commands Table

| Task | Command |
|------|---------|
| **List enabled plugins** | `kubectl -n kube-system get pod kube-apiserver-<node> -o yaml \| grep enable-admission-plugins` |
| **List disabled plugins** | `kubectl -n kube-system get pod kube-apiserver-<node> -o yaml \| grep disable-admission-plugins` |
| **View manifest file** | `cat /etc/kubernetes/manifests/kube-apiserver.yaml \| grep admission` |
| **List ALL available** | `kube-apiserver -h \| grep -A 30 enable-admission-plugins` |
| **Extract enabled list** | `kubectl -n kube-system get pod kube-apiserver-<node> -o jsonpath='{.spec.containers[0].command}' \| tr ',' '\n' \| grep -A 50 enable-admission-plugins` |

### Formatted Output Examples

**Clean list of enabled controllers:**
```bash
kubectl -n kube-system get pod kube-apiserver-controlplane -o yaml | \
  grep enable-admission-plugins | \
  sed 's/.*enable-admission-plugins=//' | \
  tr ',' '\n'
```

**Output:**
```
NamespaceLifecycle
LimitRanger
ServiceAccount
DefaultStorageClass
ResourceQuota
MutatingAdmissionWebhook
ValidatingAdmissionWebhook
```

---

## 9. Default Controllers by Kubernetes Version

### Kubernetes 1.28+ (Current)

**Default Enabled:**
```
NamespaceLifecycle, LimitRanger, ServiceAccount, 
DefaultStorageClass, DefaultTolerationSeconds, 
MutatingAdmissionWebhook, ValidatingAdmissionWebhook,
ResourceQuota, Priority, TaintNodesByCondition, 
PodSecurity, StorageObjectInUseProtection,
PersistentVolumeClaimResize, RuntimeClass,
CertificateApproval, CertificateSigning, 
CertificateSubjectRestriction
```

### Kubernetes 1.23-1.27

**Default Enabled:**
```
NamespaceLifecycle, LimitRanger, ServiceAccount,
TaintNodesByCondition, Priority, DefaultTolerationSeconds,
DefaultStorageClass, StorageObjectInUseProtection,
PersistentVolumeClaimResize, RuntimeClass, 
CertificateApproval, CertificateSigning, 
CertificateSubjectRestriction, DefaultIngressClass,
MutatingAdmissionWebhook, ValidatingAdmissionWebhook,
ResourceQuota, PodSecurity
```

### Changes from Older Versions

| Version | Change |
|---------|--------|
| **1.25+** | `PodSecurityPolicy` **deprecated** |
| **1.23+** | `PodSecurity` **enabled by default** (replaces PSP) |
| **1.21+** | `PersistentVolumeClaimResize` **enabled by default** |

---

## 10. Enabling/Disabling Admission Controllers

### Configuration File Location

`/etc/kubernetes/manifests/kube-apiserver.yaml` (on control plane)

### Enable Additional Controllers

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: kube-apiserver
  namespace: kube-system
spec:
  containers:
  - name: kube-apiserver
    command:
    - kube-apiserver
    - --enable-admission-plugins=NamespaceLifecycle,LimitRanger,ServiceAccount,ResourceQuota,PodSecurityPolicy
    #                                                                                                  ↑
    #                                                                          Added PodSecurityPolicy
```

### Disable Controllers

```yaml
- --disable-admission-plugins=ServiceAccount,DefaultStorageClass
```

**After modification:**
The kubelet will automatically restart the API server pod.

## 8. Visual Examples: Admission Controllers in Action

### Example 1: ServiceAccount Mutating Controller

```
┌──────────────────────────────────────────────────────────────────────┐
│  USER SUBMITS POD (kubectl apply -f pod.yaml)                       │
└──────────────────────────────────────────────────────────────────────┘
                              ↓
┌──────────────────────────────────────────────────────────────────────┐
│  ORIGINAL REQUEST                                                    │
│  ┌────────────────────────────────────────────────────────────┐     │
│  │ apiVersion: v1                                             │     │
│  │ kind: Pod                                                  │     │
│  │ metadata:                                                  │     │
│  │   name: nginx                                              │     │
│  │ spec:                                                      │     │
│  │   containers:                                              │     │
│  │   - name: nginx                                            │     │
│  │     image: nginx                                           │     │
│  └────────────────────────────────────────────────────────────┘     │
└──────────────────────────────────────────────────────────────────────┘
                              ↓
┌──────────────────────────────────────────────────────────────────────┐
│  SERVICEACCOUNT ADMISSION CONTROLLER (MUTATING)                      │
│                                                                      │
│  Action: Inject default ServiceAccount and token volume             │
└──────────────────────────────────────────────────────────────────────┘
                              ↓
┌──────────────────────────────────────────────────────────────────────┐
│  MODIFIED REQUEST (sent to etcd)                                    │
│  ┌────────────────────────────────────────────────────────────┐     │
│  │ apiVersion: v1                                             │     │
│  │ kind: Pod                                                  │     │
│  │ metadata:                                                  │     │
│  │   name: nginx                                              │     │
│  │ spec:                                                      │     │
│  │   serviceAccountName: default       ← INJECTED!            │     │
│  │   containers:                                              │     │
│  │   - name: nginx                                            │     │
│  │     image: nginx                                           │     │
│  │     volumeMounts:                    ← INJECTED!           │     │
│  │     - name: kube-api-access-xxxxx                          │     │
│  │       mountPath: /var/run/secrets/kubernetes.io/serviceaccount  │
│  │   volumes:                           ← INJECTED!           │     │
│  │   - name: kube-api-access-xxxxx                            │     │
│  │     projected:                                             │     │
│  │       sources:                                             │     │
│  │       - serviceAccountToken:                               │     │
│  │           path: token                                      │     │
│  └────────────────────────────────────────────────────────────┘     │
└──────────────────────────────────────────────────────────────────────┘
                              ↓
                         ✅ PERSISTED TO ETCD
```

---

### Example 2: ResourceQuota Validating Controller

```
┌──────────────────────────────────────────────────────────────────────┐
│  CLUSTER STATE: ResourceQuota in 'prod' namespace                   │
│  ┌────────────────────────────────────────────────────────────┐     │
│  │ hard:                                                      │     │
│  │   requests.cpu: "10"                                       │     │
│  │   requests.memory: "20Gi"                                  │     │
│  │                                                            │     │
│  │ used:                                                      │     │
│  │   requests.cpu: "8"                                        │     │
│  │   requests.memory: "12Gi"                                  │     │
│  └────────────────────────────────────────────────────────────┘     │
└──────────────────────────────────────────────────────────────────────┘

                              ↓

┌──────────────────────────────────────────────────────────────────────┐
│  USER TRIES TO CREATE POD                                           │
│  ┌────────────────────────────────────────────────────────────┐     │
│  │ spec:                                                      │     │
│  │   containers:                                              │     │
│  │   - name: app                                              │     │
│  │     resources:                                             │     │
│  │       requests:                                            │     │
│  │         cpu: "4"                                           │     │
│  │         memory: "8Gi"                                      │     │
│  └────────────────────────────────────────────────────────────┘     │
└──────────────────────────────────────────────────────────────────────┘

                              ↓

┌──────────────────────────────────────────────────────────────────────┐
│  RESOURCEQUOTA ADMISSION CONTROLLER (VALIDATING)                     │
│                                                                      │
│  Check: Will this pod exceed quota?                                 │
│  ┌────────────────────────────────────────────────────────────┐     │
│  │ Current CPU usage:  8 cores                                │     │
│  │ Requested:          +4 cores                               │     │
│  │ Total if approved:  12 cores                               │     │
│  │ Quota limit:        10 cores                               │     │
│  │                                                            │     │
│  │ 12 > 10  ❌ EXCEEDS QUOTA!                                 │     │
│  └────────────────────────────────────────────────────────────┘     │
└──────────────────────────────────────────────────────────────────────┘

                              ↓

┌──────────────────────────────────────────────────────────────────────┐
│  ❌ REQUEST REJECTED                                                 │
│                                                                      │
│  Error from server (Forbidden): pods "app" is forbidden:             │
│  exceeded quota: mem-cpu-quota, requested: requests.cpu=4,           │
│  used: requests.cpu=8, limited: requests.cpu=10                      │
└──────────────────────────────────────────────────────────────────────┘
```

---

### Example 3: Multiple Controllers Working Together

```
┌──────────────────────────────────────────────────────────────────────────┐
│  POD CREATION REQUEST                                                    │
│  namespace: prod                                                         │
│  cpu: 2                                                                  │
│  memory: 4Gi                                                             │
└──────────────────────────────────────────────────────────────────────────┘
                                   ↓
┌──────────────────────────────────────────────────────────────────────────┐
│  MUTATING ADMISSION PHASE (Sequential)                                  │
│                                                                          │
│  Controller 1: NamespaceLifecycle                                        │
│  ┌────────────────────────────────────────────────────┐                 │
│  │ Check: Does namespace 'prod' exist?                │                 │
│  │ Result: ✅ Yes, continue                            │                 │
│  └────────────────────────────────────────────────────┘                 │
│                                   ↓                                      │
│  Controller 2: ServiceAccount                                            │
│  ┌────────────────────────────────────────────────────┐                 │
│  │ Action: Inject serviceAccountName: default         │                 │
│  │ Action: Add volume mount for SA token              │                 │
│  │ Result: ✅ Pod modified                             │                 │
│  └────────────────────────────────────────────────────┘                 │
│                                   ↓                                      │
│  Controller 3: DefaultStorageClass                                       │
│  ┌────────────────────────────────────────────────────┐                 │
│  │ Check: Does pod use PVCs?                          │                 │
│  │ Result: ✅ No, skip                                 │                 │
│  └────────────────────────────────────────────────────┘                 │
└──────────────────────────────────────────────────────────────────────────┘
                                   ↓
┌──────────────────────────────────────────────────────────────────────────┐
│  VALIDATING ADMISSION PHASE (Parallel)                                  │
│                                                                          │
│  Controller 1: LimitRanger          Controller 2: ResourceQuota          │
│  ┌────────────────────────────┐   ┌──────────────────────────────┐     │
│  │ Check: Within limits?      │   │ Check: Within quota?         │     │
│  │ cpu: 2 ≤ 4 (max)    ✅     │   │ Current: 8 cores             │     │
│  │ mem: 4Gi ≤ 8Gi (max) ✅    │   │ Request: +2 cores            │     │
│  │ Result: APPROVE            │   │ Total: 10 cores ≤ 10 ✅      │     │
│  └────────────────────────────┘   │ Result: APPROVE              │     │
│                                   └──────────────────────────────┘     │
│            ↓                                     ↓                       │
│  Controller 3: PodSecurity          Controller 4: NodeRestriction       │
│  ┌────────────────────────────┐   ┌──────────────────────────────┐     │
│  │ Check: Privileged?         │   │ Check: Valid node selector?  │     │
│  │ privileged: false    ✅     │   │ Result: ✅ Yes               │     │
│  │ Result: APPROVE            │   │                              │     │
│  └────────────────────────────┘   └──────────────────────────────┘     │
│                                                                          │
│  ALL VALIDATING CONTROLLERS: ✅ APPROVED                                 │
└──────────────────────────────────────────────────────────────────────────┘
                                   ↓
┌──────────────────────────────────────────────────────────────────────────┐
│  ✅ FINAL RESULT: POD PERSISTED TO ETCD                                  │
└──────────────────────────────────────────────────────────────────────────┘
```

---

### Example 4: Rejection Flow

```
┌──────────────────────────────────────────────────────────────────────┐
│  USER TRIES TO CREATE POD IN NON-EXISTENT NAMESPACE                 │
│                                                                      │
│  kubectl run nginx --image=nginx -n does-not-exist                  │
└──────────────────────────────────────────────────────────────────────┘
                              ↓
┌──────────────────────────────────────────────────────────────────────┐
│  AUTHENTICATION: ✅ User authenticated                               │
└──────────────────────────────────────────────────────────────────────┘
                              ↓
┌──────────────────────────────────────────────────────────────────────┐
│  AUTHORIZATION: ✅ User has pod:create permission                    │
└──────────────────────────────────────────────────────────────────────┘
                              ↓
┌──────────────────────────────────────────────────────────────────────┐
│  MUTATING ADMISSION: NamespaceLifecycle                             │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────┐     │
│  │ Check: Does namespace 'does-not-exist' exist?             │     │
│  │                                                            │     │
│  │ Query etcd for namespace: does-not-exist                  │     │
│  │ Result: ❌ NOT FOUND                                       │     │
│  │                                                            │     │
│  │ Action: REJECT REQUEST                                    │     │
│  └────────────────────────────────────────────────────────────┘     │
└──────────────────────────────────────────────────────────────────────┘
                              ↓
┌──────────────────────────────────────────────────────────────────────┐
│  ❌ ERROR RETURNED TO USER                                           │
│                                                                      │
│  Error from server (NotFound): namespaces "does-not-exist" not found │
│                                                                      │
│  Pod was NEVER created. Request stopped at admission control.       │
└──────────────────────────────────────────────────────────────────────┘
```

---

### Decision Flow: How Admission Controllers Decide

```
┌────────────────────────────────────────────────────────────┐
│  For Each Admission Controller                            │
└────────────────────────────────────────────────────────────┘
                          ↓
           ┌──────────────────────────┐
           │  Is it enabled?          │
           └──────────────────────────┘
                    ↓           ↓
               NO ──┘           └── YES
                │                    │
                │                    ↓
                │      ┌─────────────────────────┐
                │      │ Type: Mutating?         │
                │      └─────────────────────────┘
                │              ↓           ↓
                │         YES ──┘           └── NO (Validating)
                │          │                     │
                │          ↓                     ↓
                │   ┌──────────────┐     ┌──────────────┐
                │   │  Modify      │     │  Validate    │
                │   │  Request     │     │  Request     │
                │   └──────────────┘     └──────────────┘
                │          │                     │
                │          ↓                     ↓
                │   ┌──────────────┐     ┌──────────────┐
                │   │ Continue to  │     │  Pass/Fail?  │
                │   │ next mutator │     └──────────────┘
                │   └──────────────┘            │
                │          │            ┌───────┴────────┐
                │          │            ↓                ↓
                │          │         PASS             FAIL
                │          │            │                │
                │          │            ↓                ↓
                │          │    ┌──────────────┐  ┌──────────┐
                │          │    │ Continue to  │  │  REJECT  │
                │          │    │ next         │  │  REQUEST │
                │          │    │ validator    │  │          │
                │          │    └──────────────┘  └──────────┘
                │          │            │                │
                └──────────┴────────────┘                │
                           │                             │
                           ↓                             ↓
                  ┌─────────────────┐         User gets error message
                  │  All controllers │
                  │  passed?         │
                  └─────────────────┘
                           │
                    ┌──────┴──────┐
                    ↓             ↓
                  YES            NO
                    │             │
                    ↓             ↓
            ┌──────────────┐  ┌────────┐
            │ PERSIST      │  │ REJECT │
            │ TO ETCD      │  └────────┘
            └──────────────┘
                    │
                    ↓
              ✅ SUCCESS
```

---

## 9. Real-World Examples

### Example 1: ServiceAccount Injection

**What you submit:**
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

**What gets stored (after ServiceAccount admission controller):**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  serviceAccountName: default    # ← Injected!
  containers:
  - name: nginx
    image: nginx
    volumeMounts:
    - name: kube-api-access-xxxxx
      mountPath: /var/run/secrets/kubernetes.io/serviceaccount
  volumes:
  - name: kube-api-access-xxxxx
    projected:
      sources:
      - serviceAccountToken:
          path: token
```

### Example 2: ResourceQuota Validation

**Cluster has a quota:**
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: mem-cpu-quota
  namespace: prod
spec:
  hard:
    requests.cpu: "10"
    requests.memory: "20Gi"
```

**You try to create a pod:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: big-app
  namespace: prod
spec:
  containers:
  - name: app
    resources:
      requests:
        cpu: "12"     # ← Exceeds quota!
        memory: "8Gi"
```

**Result:**
```
Error from server (Forbidden): pods "big-app" is forbidden: 
exceeded quota: mem-cpu-quota, requested: requests.cpu=12, 
used: requests.cpu=8, limited: requests.cpu=10
```

### Example 3: NamespaceLifecycle Protection

**Try to create a pod in a non-existent namespace:**
```bash
kubectl run nginx --image=nginx -n does-not-exist
```

**Result:**
```
Error from server (NotFound): namespaces "does-not-exist" not found
```

The **NamespaceLifecycle** admission controller rejected the request.

---

## 9. Custom Admission Controllers (Webhooks)

For custom logic, use **Admission Webhooks** instead of modifying the API server.

### MutatingWebhookConfiguration

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: MutatingWebhookConfiguration
metadata:
  name: inject-sidecar
webhooks:
- name: sidecar.example.com
  clientConfig:
    service:
      name: webhook-service
      namespace: default
      path: /mutate
  rules:
  - operations: ["CREATE"]
    apiGroups: [""]
    apiVersions: ["v1"]
    resources: ["pods"]
```

### ValidatingWebhookConfiguration

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  name: validate-images
webhooks:
- name: images.example.com
  clientConfig:
    service:
      name: webhook-service
      namespace: default
      path: /validate
  rules:
  - operations: ["CREATE", "UPDATE"]
    apiGroups: [""]
    apiVersions: ["v1"]
    resources: ["pods"]
```

---

## 10. Troubleshooting Admission Controller Issues

### Issue 1: Pods Not Being Created

**Symptom:**
```bash
kubectl run nginx --image=nginx
Error from server: admission webhook "validate-pods" denied the request
```

**Debug:**
```bash
# Check which admission controllers are enabled
kubectl -n kube-system get pod kube-apiserver-<node> -o yaml | grep enable-admission-plugins

# Check webhook configurations
kubectl get mutatingwebhookconfigurations
kubectl get validatingwebhookconfigurations

# Describe the webhook
kubectl describe validatingwebhookconfiguration <name>
```

### Issue 2: ServiceAccount Not Injected

**Check if ServiceAccount admission controller is enabled:**
```bash
grep enable-admission-plugins /etc/kubernetes/manifests/kube-apiserver.yaml
```

Should include `ServiceAccount`.

### Issue 3: ResourceQuota Not Enforced

**Check if ResourceQuota admission controller is enabled:**
```bash
grep enable-admission-plugins /etc/kubernetes/manifests/kube-apiserver.yaml
```

Should include `ResourceQuota`.

---

## 11. CKA Exam Tips

### Common Exam Tasks

**Task: "Enable PodSecurityPolicy admission controller"**

```bash
# SSH to control plane
ssh controlplane

# Edit the API server manifest
vi /etc/kubernetes/manifests/kube-apiserver.yaml
```

Find the line:
```yaml
--enable-admission-plugins=...
```

Add `PodSecurityPolicy`:
```yaml
--enable-admission-plugins=NamespaceLifecycle,LimitRanger,ServiceAccount,ResourceQuota,PodSecurityPolicy
```

Save and wait for API server to restart (~30 seconds).

**Task: "Check which admission controllers are enabled"**

```bash
kubectl -n kube-system describe pod kube-apiserver-<node-name> | grep enable-admission-plugins
```

---

## 12. Quick Reference

### Check Enabled Controllers

```bash
# Method 1: Via kubectl
kubectl -n kube-system get pod kube-apiserver-<node> -o yaml | grep enable-admission-plugins

# Method 2: Via static manifest
cat /etc/kubernetes/manifests/kube-apiserver.yaml | grep enable-admission-plugins
```

### Enable a Controller

Edit `/etc/kubernetes/manifests/kube-apiserver.yaml`:
```yaml
--enable-admission-plugins=NamespaceLifecycle,ServiceAccount,NewController
```

### Disable a Controller

```yaml
--disable-admission-plugins=ServiceAccount
```

### List All Available Controllers

```bash
kube-apiserver -h | grep admission-plugins
```

---

## Summary

!!! success "Key Takeaways"
    ✅ Admission controllers run **after authentication/authorization**, **before persistence**  
    ✅ **Mutating** controllers modify requests, **Validating** controllers approve/reject  
    ✅ Mutating controllers run **before** validating controllers  
    ✅ Configured via `--enable-admission-plugins` flag in kube-apiserver  
    ✅ Built-in controllers are compiled into kube-apiserver  
    ✅ Custom logic uses **Webhooks** (MutatingWebhookConfiguration, ValidatingWebhookConfiguration)  
    ✅ Common controllers: **ServiceAccount**, **ResourceQuota**, **LimitRanger**, **NamespaceLifecycle**  
    ✅ Changes require editing `/etc/kubernetes/manifests/kube-apiserver.yaml` and waiting for restart  

### Essential Controllers for CKA

| Controller | Must Know? | Why? |
|------------|-----------|------|
| **NamespaceLifecycle** | ✅ | Prevents namespace errors |
| **ServiceAccount** | ✅ | Automatically injects SA tokens |
| **ResourceQuota** | ✅ | Enforces quotas (exam topic) |
| **LimitRanger** | ✅ | Enforces limits (exam topic) |
| **MutatingAdmissionWebhook** | 🟡 | Know the concept |
| **ValidatingAdmissionWebhook** | 🟡 | Know the concept |

---

## Further Reading

- **[Official Kubernetes Documentation: Admission Controllers](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/)**  
  Complete reference for all admission controllers

- **[A Guide to Kubernetes Admission Controllers](https://kubernetes.io/blog/2019/03/21/a-guide-to-kubernetes-admission-controllers/)**  
  Official blog post explaining admission controller concepts

- **[Dynamic Admission Control](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/)**  
  How to build custom admission webhooks
