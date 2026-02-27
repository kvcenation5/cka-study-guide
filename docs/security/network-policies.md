# Network Policies

Network Policies are the Kubernetes equivalent of a firewall. They allow you to control traffic flow at the IP address or port level (Layer 3 or 4) for Pod communication.

![Network Policy Architecture](network-policy-architecture-v3.png)

## Core Concepts

### 1. Default Behavior vs. Isolation
- **Non-isolated:** By default, all Pods in a cluster can communicate with each other (**All Allow**).
- **Isolated:** As soon as a Pod is selected by *any* `NetworkPolicy`, it becomes isolated for that traffic type (Ingress/Egress). You must then explicitly "whitelist" any traffic you want to allow.

### 2. The Three Selectors
You can define allow rules based on three types of selectors:
1.  **podSelector:** Traffic to/from Pods with specific labels in the same namespace.
2.  **namespaceSelector:** Traffic to/from Pods in namespaces that have specific labels.
3.  **ipBlock:** Traffic to/from specific IP ranges (CIDR).

---

## Example: Allowing Ingress from a Specific App

This is a common CKA task: "Allow traffic to the `db` pod only from the `frontend` pod."

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: db-policy
  namespace: prod
spec:
  podSelector:
    matchLabels:
      role: db
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          role: frontend
    ports:
    - protocol: TCP
      port: 5432
```

---

## Important CKA Gotchas

### 1. The "Default Deny" All
To secure a namespace, it is common practice to start with a "Deny All" policy.
```yaml
spec:
  podSelector: {} # Selects all pods in the namespace
  policyTypes:
  - Ingress
  - Egress
  # No rules defined = Deny All
```

### 2. Don't Forget DNS (Egress)
If you apply an **Egress** policy to a Pod, it will likely lose the ability to resolve service names unless you explicitly allow DNS traffic.
- **Port:** 53
- **Protocol:** UDP (and TCP)
- **Destination:** kube-system namespace (usually)

### 3. "And" vs "Or" in Selectors
- **List items (Dash `-`):** These are **OR** conditions.
- **Key-Value pairs (No Dash):** These are **AND** conditions.

```yaml
# Example of AND (Pod in Namespace with label)
- from:
  - namespaceSelector:
      matchLabels:
        user: alice
    podSelector:
      matchLabels:
        role: client
```

---

## Common Pitfalls
1. **Implicit Deny**: Empty egress rules block ALL outbound traffic (including DNS).
2. **Label Typos**: Selectors don't warn if 0 pods match.
3. **One-Way Rules**: Allowing egress doesn't automatically allow ingress on the destination.
4. **Missing CNI Plugin**: Network Policies **require** a networking plugin that supports them (like Calico, Cilium, or Canal). Flannel does NOT support Network Policies.