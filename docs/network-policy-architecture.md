# Network Policy Architecture

This diagram illustrates how NetworkPolicies control pod-to-pod communication in Kubernetes.

![Network Policy Architecture](network-policy-architecture-v3.png)

## How NetworkPolicies Work

### Default Behavior
- By default, all pods can communicate with each other
- Once a NetworkPolicy selects a pod, that pod becomes isolated
- Must explicitly allow desired traffic (whitelist approach)

### Policy Types

#### Ingress Rules
- Control incoming traffic TO the selected pods
- Specify which sources can connect (pods, namespaces, IP blocks)
- Define allowed ports and protocols

#### Egress Rules
- Control outgoing traffic FROM the selected pods
- Specify allowed destinations
- Critical: Must allow DNS (port 53) for name resolution

### Label Selectors

#### podSelector
- Selects which pods the policy applies to
- Uses label matching (exact match required)
- Empty podSelector = applies to all pods in namespace

#### namespaceSelector
- Selects pods from specific namespaces
- Useful for cross-namespace communication
- Can combine with podSelector for fine-grained control

## Common Pitfalls

1. **Implicit Deny**: Empty egress rules block ALL outbound traffic (including DNS)
2. **Label Typos**: Selector doesn't warn if 0 pods match
3. **One-Way Rules**: Allowing egress doesn't automatically allow ingress on destination
4. **Missing DNS**: Always allow port 53 UDP to kube-system namespace