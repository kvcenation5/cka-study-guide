# Network Policy: Hands-on YAML Examples

This page provides ready-to-use YAML manifests for common Kubernetes network security scenarios.

---

## 🛑 1. The "Default Deny All" (Baseline)
Before applying specific rules, it's safest to block everything.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: prod
spec:
  podSelector: {} # Target ALL pods
  policyTypes:
  - Ingress
  # Empty ingress list means NOTHING is allowed in
```

---

## 🟢 2. Allow Internal App Communication
Allowing the `api` pod to talk to the `redis` pod inside the same namespace.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: redis-allow-api
  namespace: prod
spec:
  podSelector:
    matchLabels:
      app: redis
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: api
    ports:
    - protocol: TCP
      port: 6379
```

---

## 🧪 3. Cross-Namespace Access
Allowing the `monitoring` namespace to scrape metrics from pods in the `app` namespace.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-monitoring-scrape
  namespace: app
spec:
  podSelector: {} # Allow monitoring to see ALL pods in this ns
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
      port: 8080 # Metrics port
```

---

## 🌐 4. Egress to External Service (CIDR)
Allowing pods to reach a specific external database or API by its IP range.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: egress-to-external-db
  namespace: prod
spec:
  podSelector:
    matchLabels:
      role: worker
  policyTypes:
  - Egress
  egress:
  - to:
    - ipBlock:
        cidr: 192.168.1.0/24
        except:
        - 192.168.1.10/32 # Block one specific IP in the range
    ports:
    - protocol: TCP
      port: 5432
```

---

## 🍱 5. Multi-Rule Policy (Complex)
A single policy that handles multiple sources and protocols.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-policy
  namespace: frontend
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          role: ingress-controller # Allow traffic from Ingress
    ports:
    - protocol: TCP
      port: 80
  - from:
    - ipBlock: # Allow specific admin IP
        cidr: 10.0.0.1/32
    ports:
    - protocol: TCP
      port: 22
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: api # Allow talking to backend API
    ports:
    - protocol: TCP
      port: 8080
```

---

> [!TIP]
> **Check your Labels!**
> If these aren't working, immediately run:
> `kubectl get pods --show-labels -n <namespace>`
> to ensure the `matchLabels` in your YAML exactly match the labels on the physical pods.
