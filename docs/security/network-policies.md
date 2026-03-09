# Network Policies: Pod Firewalling

By default, all Pods in a Kubernetes cluster can talk to each other without restriction. **Network Policies (NP)** act as a "distributed firewall" that defines which Pods are allowed to communicate with which other Pods.

---

## 🏗️ 1. Core Concepts: Ingress vs. Egress

Network Policies are defined using two directions:
*   **Ingress**: Traffic **Incoming** to the target Pod.
*   **Egress**: Traffic **Outgoing** from the target Pod.

### The "Default Deny" Strategy
The most secure approach is to block **everything** first, and then selectively open the "holes" you need.

**Example: Default Deny All Ingress**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: my-app
spec:
  podSelector: {} # {} means 'Apply to ALL pods in this namespace'
  policyTypes:
  - Ingress # Only blocking incoming for now
```

---

## 🏷️ 2. Mastering Selectors & Labels

Network Policies don't use IP addresses or Pod names. They use **Labels**. If your labels are wrong, your policy will fail silently.

### A. Knowing your Labels
Before writing any policy, use these commands to see exactly what you are targeting:
```bash
# See pod labels
kubectl get pods --show-labels

# See namespace labels (CRITICAL for namespaceSelectors)
kubectl get ns --show-labels
```

### B. Adding Labels at Runtime
If a pod or namespace is missing a label you need for your policy:
```bash
# Add label to a Pod
kubectl label pod my-pod role=db

# Add label to a Namespace
kubectl label ns my-namespace project=production
```

### C. The `podSelector` Field
The `podSelector` field appears in two places, and it means something different in each:

1.  **Top-Level Target** (`spec.podSelector`):
    *   This defines **which Pods this firewall applies to**.
    *   `podSelector: {}` $\rightarrow$ Target **ALL** pods in this namespace.
    *   `podSelector: { matchLabels: { role: db } }` $\rightarrow$ Target only the DB pods.

2.  **Rule-Level Source/Dest** (`from` or `to`):
    *   This defines **who is allowed** to talk to the target.
    *   `podSelector: {}` $\rightarrow$ Allow traffic from **ANY** pod in the **same namespace** as the target.
    *   *Note: If you want to allow traffic from another namespace, you MUST also use a `namespaceSelector`.*

---

## 🚥 3. Unified Ingress & Egress (The "Full Firewall")

A single `NetworkPolicy` can manage both incoming and outgoing traffic for a Pod. This is common when a Pod acts as an intermediate service (e.g., an API that receives requests and talks to a DB).

### Key Rules for "Both":
1.  **policyTypes**: You must list both `- Ingress` and `- Egress`.
2.  **isolation**: Once you add a field (like `ingress:`), that direction becomes "Denied by default" except for what you list.

#### Example: API Gateway Policy
*   **Ingress**: Allow traffic from the `internet` on port 80.
*   **Egress**: Allow traffic only to the `internal-db` on port 5432.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-full-firewall
spec:
  podSelector:
    matchLabels:
      app: api-gateway
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - ipBlock: { cidr: 0.0.0.0/0 }
    ports:
    - port: 80
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: internal-db
    ports:
    - port: 5432
```

---

## 📄 4. Anatomy of a Network Policy

A `NetworkPolicy` can define **Ingress** (incoming), **Egress** (outgoing), OR **Both** at the same time. The structure follows a standard pattern:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: example-policy
spec:
  # 1. THE TARGET: Which pod(s) are we securing?
  podSelector:
    matchLabels:
      role: db
  
  # 2. THE DIRECTION: Are we firewalling Ingress, Egress, or Both?
  policyTypes:
  - Ingress
  - Egress
  
  # 3. THE RULES: Selective access
  ingress:
  - from:
    - podSelector:
        matchLabels:
          role: api
  egress:
  - to:
    - ipBlock: { cidr: 10.0.0.0/24 }
```

---

## 🚥 5. Selectors: The "AND" vs "OR" Logic
This is the **#1 reason** CKA students fail Network Policy questions.

### Pattern A: "AND" Logic (Combining Selectors)
Use this if the traffic must come from a **specific pod** inside a **specific namespace**.
```yaml
- from:
  - namespaceSelector:
      matchLabels:
        project: beta
    podSelector: # No dash before podSelector!
      matchLabels:
        role: frontend
```

### Pattern B: "OR" Logic (Separate Rules)
Use this if traffic can come from **either** a pod with a label **OR** any pod in a namespace.
```yaml
- from:
  - namespaceSelector: # Note the dash -
      matchLabels:
        user: alice
  - podSelector: # Note the dash -
      matchLabels:
        app: testing
```

---

## 🛠️ 6. Common CKA Scenarios

### Scenario 1: Allow traffic from a specific Namespace
```yaml
- from:
  - namespaceSelector:
      matchLabels:
        name: staging
```

### Scenario 2: Allow Egress to an External IP (e.g., DNS)
```yaml
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - ipBlock: # Allow specific IP range
        cidr: 8.8.8.8/32
    ports:
    - protocol: UDP
      port: 53
```

---

## 🚩 7. CKA Exam Strategy

1.  **Check Labels First**: Before writing a policy, verify the labels on your pods and namespaces.
    `kubectl get pods --show-labels`
    `kubectl get namespaces --show-labels`
2.  **PolicyTypes**: Always explicitly list your `policyTypes` (Ingress, Egress). If you omit this, Kubernetes tries to guess, which can lead to unexpected denials.
3.  **CNI Support**: Remember that Network Policies only work if your cluster uses a CNI that supports them (like **Calico**, **Cilium**, or **Weave**). If you are using simple Flannel, these YAMLs will be accepted by the API but **nothing will happen**.
4.  **Dry Run**: Use `-o yaml --dry-run=client` to generate the skeleton if you forget the syntax.

---

> [!TIP]
> **Troubleshooting**: If a Pod can't talk to another one, use `kubectl describe networkpolicy <name>` to see exactly what rules are active. If multiple policies apply to the same Pod, they are **Additive** (unions). If any one policy allows the traffic, it goes through.