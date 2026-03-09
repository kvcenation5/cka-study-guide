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

## 📄 2. Anatomy of a Network Policy

To write a policy, you must define **Who** is the target and **Who** is allowed to talk to them.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-allow-db
  namespace: prod
spec:
  # 1. THE TARGET: Which pods does this rule apply to?
  podSelector:
    matchLabels:
      role: db
  policyTypes:
  - Ingress
  # 2. THE RULE: Who can talk to the database?
  ingress:
  - from:
    - podSelector:
        matchLabels:
          role: api
    ports:
    - protocol: TCP
      port: 5432
```

---

## 🔗 3. Selectors: The "AND" vs "OR" Logic
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

## 🛠️ 4. Common CKA Scenarios

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

## 🚩 5. CKA Exam Strategy

1.  **Check Labels First**: Before writing a policy, verify the labels on your pods and namespaces.
    `kubectl get pods --show-labels`
    `kubectl get namespaces --show-labels`
2.  **PolicyTypes**: Always explicitly list your `policyTypes` (Ingress, Egress). If you omit this, Kubernetes tries to guess, which can lead to unexpected denials.
3.  **CNI Support**: Remember that Network Policies only work if your cluster uses a CNI that supports them (like **Calico**, **Cilium**, or **Weave**). If you are using simple Flannel, these YAMLs will be accepted by the API but **nothing will happen**.
4.  **Dry Run**: Use `-o yaml --dry-run=client` to generate the skeleton if you forget the syntax.

---

> [!TIP]
> **Troubleshooting**: If a Pod can't talk to another one, use `kubectl describe networkpolicy <name>` to see exactly what rules are active. If multiple policies apply to the same Pod, they are **Additive** (unions). If any one policy allows the traffic, it goes through.