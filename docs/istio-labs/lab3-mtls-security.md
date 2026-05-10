# Lab 3: mTLS and Security Policies

## Objective

Enable strict mTLS across the mesh, then write `AuthorizationPolicy` rules to control which services can talk to which — Istio's equivalent of Kubernetes RBAC but for service-to-service traffic.

---

## Two Separate Concepts

| Resource | Controls |
|----------|---------|
| `PeerAuthentication` | **How** traffic is encrypted — enforces mTLS |
| `AuthorizationPolicy` | **Who** can talk to whom — allow/deny rules |

You need both: mTLS proves identity, AuthorizationPolicy uses that identity to make access decisions.

---

## Step 1: Enable Strict mTLS Mesh-Wide

By default Istio runs in `PERMISSIVE` mode — it accepts both plain-text and mTLS traffic. Switch to `STRICT`:

```bash
cat << 'EOF' | kubectl apply -f -
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT
EOF
```

Applying this in `istio-system` makes it mesh-wide. Now any service without a sidecar (no Envoy proxy) cannot communicate with mesh services.

Verify:

```bash
# This should FAIL — no sidecar, so no identity, so mTLS rejected
kubectl run plain-curl --image=curlimages/curl --restart=Never \
  -- curl -s http://productpage.bookinfo:9080/productpage
kubectl logs plain-curl
# Connection reset or SSL error
kubectl delete pod plain-curl
```

---

## Step 2: Verify mTLS is Active

```bash
istioctl authn tls-check \
  $(kubectl get pod -n bookinfo -l app=productpage -o jsonpath='{.items[0].metadata.name}').bookinfo \
  reviews.bookinfo.svc.cluster.local
```

Expected:

```
HOST:PORT                                  STATUS   SERVER   CLIENT   AUTHN POLICY
reviews.bookinfo.svc.cluster.local:9080    OK       STRICT   STRICT   default/istio-system
```

Both SERVER and CLIENT show `STRICT` — all traffic is mutually authenticated.

---

## Step 3: Default Deny All

```bash
cat << 'EOF' | kubectl apply -n bookinfo -f -
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: bookinfo
spec:
  {}
EOF
```

An empty spec with no `rules` denies everything. Refresh the Bookinfo page — you should get `RBAC: access denied`.

---

## Step 4: Allow Only Required Service-to-Service Traffic

Restore access by explicitly allowing the call graph:

```bash
# Allow ingress gateway → productpage
cat << 'EOF' | kubectl apply -n bookinfo -f -
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-productpage
spec:
  selector:
    matchLabels:
      app: productpage
  rules:
    - from:
        - source:
            principals:
              - cluster.local/ns/istio-system/sa/istio-ingressgateway-service-account
      to:
        - operation:
            methods: ["GET"]
EOF

# Allow productpage → reviews and details
cat << 'EOF' | kubectl apply -n bookinfo -f -
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-reviews-details
spec:
  selector:
    matchLabels:
      app: reviews
  rules:
    - from:
        - source:
            principals:
              - cluster.local/ns/bookinfo/sa/bookinfo-productpage
---
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-details
spec:
  selector:
    matchLabels:
      app: details
  rules:
    - from:
        - source:
            principals:
              - cluster.local/ns/bookinfo/sa/bookinfo-productpage
EOF

# Allow reviews → ratings
cat << 'EOF' | kubectl apply -n bookinfo -f -
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-ratings
spec:
  selector:
    matchLabels:
      app: ratings
  rules:
    - from:
        - source:
            principals:
              - cluster.local/ns/bookinfo/sa/bookinfo-reviews
EOF
```

Refresh the Bookinfo page — it should work again.

!!! note "principals use SPIFFE format"
    `cluster.local/ns/<namespace>/sa/<serviceaccount>` is the SPIFFE identity Istio assigns to each pod based on its ServiceAccount. This is what mTLS proves — the peer's identity.

---

## Step 5: Method and Path Restrictions

Restrict the ratings service to only accept GET requests:

```bash
cat << 'EOF' | kubectl apply -n bookinfo -f -
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-ratings
spec:
  selector:
    matchLabels:
      app: ratings
  rules:
    - from:
        - source:
            principals:
              - cluster.local/ns/bookinfo/sa/bookinfo-reviews
      to:
        - operation:
            methods: ["GET"]
            paths: ["/ratings/*"]
EOF
```

Any other method or path to the ratings service is now denied.

---

## Checkpoint

- [ ] Strict mTLS mesh-wide via PeerAuthentication
- [ ] Plain-text pod rejected by mesh services
- [ ] Default-deny AuthorizationPolicy blocks all traffic
- [ ] Explicit allows restore the Bookinfo call graph
- [ ] Method + path restrictions on ratings

---

**Next:** [Lab 4: Observability](./lab4-observability.md)
