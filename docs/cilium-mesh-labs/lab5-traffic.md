# Lab 5: Traffic Management

## Objective

Use Cilium's eBPF-native load balancing, implement canary deployments via CiliumEnvoyConfig, and configure circuit breaking — all without a sidecar proxy.

---

## Cilium Traffic Management Options

| Feature | How |
|---------|-----|
| L3/L4 load balancing | eBPF — replaces kube-proxy |
| L7 load balancing | CiliumEnvoyConfig (embedded Envoy, no sidecar) |
| Canary / traffic split | CiliumEnvoyConfig + weighted clusters |
| Circuit breaking | CiliumEnvoyConfig outlier detection |
| Ingress | CiliumEnvoyConfig via Ingress resource |

---

## Step 1: Verify eBPF Service Load Balancing

Cilium replaces kube-proxy with eBPF maps. Check that services are backed by eBPF:

```bash
# List all services in eBPF
kubectl exec -n kube-system \
  $(kubectl get pod -n kube-system -l k8s-app=cilium -o name | head -1) \
  -- cilium service list
```

You'll see each Kubernetes Service as an entry with its backends (pod IPs). Cilium does consistent hashing and session affinity at the eBPF level — much faster than iptables.

---

## Step 2: Deploy Two App Versions

```bash
# Deploy v1 and v2 of a simple echo server
kubectl apply -n demo -f - << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: echo-v1
spec:
  replicas: 2
  selector:
    matchLabels:
      app: echo
      version: v1
  template:
    metadata:
      labels:
        app: echo
        version: v1
    spec:
      containers:
        - name: echo
          image: hashicorp/http-echo
          args: ["-text=v1"]
          ports:
            - containerPort: 5678
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: echo-v2
spec:
  replicas: 2
  selector:
    matchLabels:
      app: echo
      version: v2
  template:
    metadata:
      labels:
        app: echo
        version: v2
    spec:
      containers:
        - name: echo
          image: hashicorp/http-echo
          args: ["-text=v2"]
          ports:
            - containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: echo
spec:
  selector:
    app: echo
  ports:
    - port: 5678
EOF
```

Without any policy, the service round-robins across all 4 pods (2x v1, 2x v2).

---

## Step 3: Canary with CiliumEnvoyConfig

Split traffic 90% v1 / 10% v2:

```bash
cat << 'EOF' | kubectl apply -n demo -f -
apiVersion: cilium.io/v2
kind: CiliumEnvoyConfig
metadata:
  name: echo-canary
spec:
  services:
    - name: echo
      namespace: demo
  resources:
    - "@type": type.googleapis.com/envoy.config.listener.v3.Listener
      name: echo-listener
    - "@type": type.googleapis.com/envoy.config.route.v3.RouteConfiguration
      name: echo-route
      virtual_hosts:
        - name: echo
          domains: ["*"]
          routes:
            - match:
                prefix: "/"
              route:
                weighted_clusters:
                  clusters:
                    - name: echo-v1
                      weight: 90
                    - name: echo-v2
                      weight: 10
    - "@type": type.googleapis.com/envoy.config.cluster.v3.Cluster
      name: echo-v1
      type: EDS
    - "@type": type.googleapis.com/envoy.config.cluster.v3.Cluster
      name: echo-v2
      type: EDS
EOF
```

Test the split:

```bash
for i in $(seq 1 20); do
  kubectl exec -n demo \
    $(kubectl get pod -n demo -l app=xwing -o name | head -1) \
    -- curl -s echo.demo.svc.cluster.local:5678
done | sort | uniq -c
# ~18x "v1", ~2x "v2"
```

---

## Step 4: Circuit Breaking

Configure Cilium to open the circuit when a backend shows errors:

```bash
cat << 'EOF' | kubectl apply -n demo -f -
apiVersion: cilium.io/v2
kind: CiliumEnvoyConfig
metadata:
  name: echo-circuit-breaker
spec:
  services:
    - name: echo
      namespace: demo
  resources:
    - "@type": type.googleapis.com/envoy.config.cluster.v3.Cluster
      name: echo
      outlier_detection:
        consecutive_5xx: 3
        interval: 10s
        base_ejection_time: 30s
        max_ejection_percent: 50
EOF
```

Settings:
- After `3` consecutive 5xx errors, eject the backend for `30s`
- Never eject more than `50%` of backends at once

---

## Step 5: Session Affinity

Pin a client to the same backend pod (useful for stateful apps):

```bash
kubectl patch service echo -n demo \
  --type merge \
  -p '{"spec":{"sessionAffinity":"ClientIP","sessionAffinityConfig":{"clientIP":{"timeoutSeconds":10800}}}}'
```

Cilium implements this in eBPF using a consistent hash on the source IP — no iptables rules, no sidecar needed.

Test that the same pod always responds:

```bash
for i in $(seq 1 5); do
  kubectl exec -n demo \
    $(kubectl get pod -n demo -l app=xwing -o name | head -1) \
    -- curl -s echo.demo.svc.cluster.local:5678
done
# Should always return the same version
```

---

## Clean Up

```bash
kind delete cluster --name cilium-mesh
```

---

## Key Takeaways

| Cilium Feature | What Replaces |
|---------------|--------------|
| eBPF service proxy | kube-proxy (iptables) |
| CiliumNetworkPolicy L7 | Separate ingress controller |
| CiliumEnvoyConfig canary | Istio VirtualService |
| Hubble flows | Service mesh observability sidecar |
| WireGuard node encryption | IPsec / overlay encryption |

Cilium gives you most service mesh capabilities at much lower overhead by operating in the kernel rather than via per-pod sidecar proxies.
