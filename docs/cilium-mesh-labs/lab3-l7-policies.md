# Lab 3: L7 Network Policies

## Objective

Write HTTP-aware `CiliumNetworkPolicy` rules that allow or deny traffic based on HTTP method, path, and headers — not just IP and port.

---

## L3/L4 vs L7 Policies

| Layer | What You Can Match | Example |
|-------|-------------------|---------|
| L3 | Source/dest IP, CIDR | Allow from 10.0.0.0/8 |
| L4 | Port, protocol | Allow TCP 8080 |
| L7 | HTTP method, path, headers, DNS | Allow GET /api only |

Traditional `NetworkPolicy` (Kubernetes built-in) stops at L4. Cilium's L7 policies let you express: "allow GET /v1/status but deny POST /v1/request-landing from these pods."

---

## Step 1: Block All Traffic First (Default Deny)

```bash
cat << 'EOF' | kubectl apply -f -
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: default-deny
  namespace: demo
spec:
  endpointSelector: {}
  ingress:
    - {}
  egress:
    - {}
EOF
```

!!! warning "This blocks everything in the demo namespace"
    After applying this, all connections (including DNS) are blocked. We'll add explicit allows in the next steps.

---

## Step 2: Allow DNS

```bash
cat << 'EOF' | kubectl apply -f -
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-dns
  namespace: demo
spec:
  endpointSelector: {}
  egress:
    - toEndpoints:
        - matchLabels:
            k8s:io.kubernetes.pod.namespace: kube-system
            k8s-app: kube-dns
      toPorts:
        - ports:
            - port: "53"
              protocol: UDP
          rules:
            dns:
              - matchPattern: "*"
EOF
```

---

## Step 3: Allow GET /v1/status Only (L7)

Allow xwing to call deathstar, but only HTTP GET on `/v1/status` — block the landing request path:

```bash
cat << 'EOF' | kubectl apply -f -
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: l7-deathstar-policy
  namespace: demo
spec:
  endpointSelector:
    matchLabels:
      app: deathstar
  ingress:
    - fromEndpoints:
        - matchLabels:
            app: xwing
      toPorts:
        - ports:
            - port: "80"
              protocol: TCP
          rules:
            http:
              - method: GET
                path: /v1/status
EOF
```

**Test — allowed (GET /v1/status):**

```bash
kubectl exec -n demo -it \
  $(kubectl get pod -n demo -l app=xwing -o name | head -1) \
  -- curl -s deathstar.demo.svc.cluster.local/v1/status
# {"server": "deathstar-..."}
```

**Test — blocked (POST /v1/request-landing):**

```bash
kubectl exec -n demo -it \
  $(kubectl get pod -n demo -l app=xwing -o name | head -1) \
  -- curl -s -XPOST deathstar.demo.svc.cluster.local/v1/request-landing
# Access denied
```

Only the HTTP method + path combination is allowed — everything else is rejected even on the same port.

---

## Step 4: DNS-Based Egress Policy

Allow pods to reach external services by domain name:

```bash
cat << 'EOF' | kubectl apply -f -
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-external-api
  namespace: demo
spec:
  endpointSelector:
    matchLabels:
      app: xwing
  egress:
    - toFQDNs:
        - matchName: "api.example.com"
      toPorts:
        - ports:
            - port: "443"
              protocol: TCP
EOF
```

Cilium intercepts DNS responses and dynamically creates eBPF rules for the resolved IPs. When `api.example.com` resolves to a new IP, Cilium updates the rules automatically — no CIDR management needed.

---

## Step 5: Verify Policies in Cilium

```bash
# List all CiliumNetworkPolicies
kubectl get ciliumnetworkpolicies -n demo

# Check a specific policy's status
kubectl get ciliumnetworkpolicy l7-deathstar-policy -n demo -o yaml | grep -A 10 status

# View policy enforcement from inside the agent
kubectl exec -n kube-system \
  $(kubectl get pod -n kube-system -l k8s-app=cilium -o name | head -1) \
  -- cilium policy get
```

---

## Checkpoint

- [ ] Default-deny policy in place
- [ ] DNS allowed for all pods
- [ ] L7 policy on deathstar: GET /v1/status allowed, POST blocked
- [ ] Confirmed both behaviors with curl
- [ ] DNS-based egress policy created

---

## L7 Policy Summary

```
CiliumNetworkPolicy allows you to match on:

HTTP:  method (GET/POST/PUT/DELETE)
       path (exact, prefix, regex)
       headers (key: value)

DNS:   matchName (exact domain)
       matchPattern (wildcard)

Kafka: topic, role (produce/consume)

gRPC:  service name, method
```

---

**Next:** [Lab 4: Hubble Observability](./lab4-hubble.md)
