# Lab 1: Cluster Setup with Cilium

## Objective

Create a KinD cluster with kube-proxy disabled (Cilium replaces it via eBPF) and install Cilium with the service mesh features enabled.

---

## Why Disable kube-proxy?

Traditional Kubernetes uses kube-proxy (iptables rules) for service routing. Cilium's eBPF dataplane replaces this entirely:

| | kube-proxy | Cilium eBPF |
|-|-----------|------------|
| Service routing | iptables (O(n) rules) | eBPF maps (O(1) lookup) |
| Overhead | Grows with service count | Constant |
| Visibility | None | Full flow tracing via Hubble |
| L7 policies | Not possible | HTTP/gRPC/DNS aware |

---

## Step 1: Create the KinD Cluster

```bash
cat > /tmp/cilium-mesh-cluster.yaml << 'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: cilium-mesh
nodes:
  - role: control-plane
  - role: worker
  - role: worker
networking:
  disableDefaultCNI: true
  kubeProxyMode: none
EOF

kind create cluster --config /tmp/cilium-mesh-cluster.yaml
```

!!! note "disableDefaultCNI + kubeProxyMode: none"
    `disableDefaultCNI` stops KinD from installing kindnet. `kubeProxyMode: none` prevents kube-proxy from running. Cilium will handle both CNI and service proxy.

Verify nodes exist (they'll be `NotReady` until Cilium is installed):

```bash
kubectl get nodes --context kind-cilium-mesh
```

---

## Step 2: Install Cilium with Service Mesh Features

```bash
cilium install \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost=cilium-mesh-control-plane \
  --set k8sServicePort=6443 \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true \
  --set ingressController.enabled=true
```

Key flags:

| Flag | Effect |
|------|--------|
| `kubeProxyReplacement=true` | Cilium handles all service routing via eBPF |
| `k8sServiceHost/Port` | Points Cilium at the API server (needed without kube-proxy) |
| `hubble.relay.enabled` | Enables Hubble flow aggregation |
| `hubble.ui.enabled` | Enables the Hubble web UI |
| `ingressController.enabled` | Cilium handles Ingress resources |

---

## Step 3: Wait for Cilium to Be Ready

```bash
cilium status --wait
```

Expected:

```
    /¯¯\
 /¯¯\__/¯¯\    Cilium:             OK
 \__/¯¯\__/    Operator:           OK
 /¯¯\__/¯¯\    Envoy DaemonSet:    OK
 \__/¯¯\__/    Hubble Relay:       OK
    \__/       ClusterMesh:        disabled

Deployment             cilium-operator    Desired: 1, Ready: 1/1, Available: 1/1
DaemonSet              cilium             Desired: 3, Ready: 3/3, Available: 3/3
Deployment             hubble-relay       Desired: 1, Ready: 1/1, Available: 1/1
Deployment             hubble-ui          Desired: 1, Ready: 1/1, Available: 1/1
```

Nodes should now be `Ready`:

```bash
kubectl get nodes
```

---

## Step 4: Run the Connectivity Test

Cilium ships a built-in connectivity test that validates the full dataplane:

```bash
cilium connectivity test
```

This deploys test pods and verifies connectivity across:
- Pod-to-pod (same node)
- Pod-to-pod (cross node)
- Pod-to-service
- External connectivity
- Network policy enforcement

Takes ~5 minutes. All tests should pass.

---

## Step 5: Deploy a Sample App

```bash
kubectl create namespace demo
kubectl label namespace demo app=demo

kubectl apply -n demo -f https://raw.githubusercontent.com/cilium/cilium/main/examples/minikube/http-sw-app.yaml

kubectl get pods -n demo
```

This deploys a Star Wars themed demo app (Death Star + X-Wing) that we'll use in later labs for L7 policy enforcement.

---

## Checkpoint

- [ ] Cluster `cilium-mesh` created with kube-proxy disabled
- [ ] `cilium status` shows all green
- [ ] All nodes `Ready`
- [ ] Connectivity test passed
- [ ] Demo app pods running in `demo` namespace

---

## Troubleshooting

### Nodes stuck in NotReady

```bash
kubectl describe node cilium-mesh-worker
# Look for "container runtime network not ready" — Cilium is still starting
cilium status   # wait for DaemonSet to be Ready: 3/3
```

### Connectivity test fails

```bash
# Check Cilium agent logs on the failing node
kubectl logs -n kube-system -l k8s-app=cilium --tail=50
```

---

**Next:** [Lab 2: Transparent mTLS](./lab2-mtls.md)
