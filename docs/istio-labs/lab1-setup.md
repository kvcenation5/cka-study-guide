# Lab 1: Cluster Setup with Istio

## Objective

Create a KinD cluster, install Istio with the demo profile, and enable automatic sidecar injection in a namespace.

---

## How Istio's Sidecar Model Works

```
Without Istio:          With Istio:
┌─────────────┐         ┌─────────────────────────┐
│  app pod    │         │  app pod                │
│ [container] │         │ [app container]          │
└─────────────┘         │ [envoy sidecar] ← injected│
                        └─────────────────────────┘
```

`istiod` watches for new pods in injection-enabled namespaces and mutates them via a MutatingWebhook to add the Envoy sidecar container automatically. All traffic to/from the app container flows through Envoy, giving Istio full L7 visibility and control.

---

## Step 1: Create the KinD Cluster

```bash
cat > /tmp/istio-cluster.yaml << 'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: istio-mesh
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 30080
        hostPort: 30080
        protocol: TCP
  - role: worker
  - role: worker
EOF

kind create cluster --config /tmp/istio-cluster.yaml
kubectl config use-context kind-istio-mesh
```

---

## Step 2: Install Istio

```bash
istioctl install --set profile=demo -y
```

The `demo` profile enables all Istio components including tracing and telemetry — ideal for learning:

| Profile | Use Case |
|---------|----------|
| `minimal` | Just the control plane, no extras |
| `demo` | All features, higher resource use — good for labs |
| `production` | Tuned for production workloads |

Wait for all Istio pods:

```bash
kubectl wait --for=condition=Ready pod \
  -n istio-system --all --timeout=120s

kubectl get pods -n istio-system
```

Expected:

```
NAME                                   READY   STATUS
istio-egressgateway-xxxxxxxxxx-xxxxx   1/1     Running
istio-ingressgateway-xxxxxxxxxx-xxxxx  1/1     Running
istiod-xxxxxxxxxx-xxxxx                1/1     Running
```

---

## Step 3: Install Observability Addons

```bash
# Kiali (service graph), Prometheus, Grafana, Jaeger (tracing)
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/prometheus.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/grafana.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/jaeger.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/kiali.yaml

kubectl wait --for=condition=Ready pod \
  -n istio-system -l app=kiali --timeout=60s
```

---

## Step 4: Enable Sidecar Injection

Label the namespace where you want sidecars injected automatically:

```bash
kubectl create namespace bookinfo
kubectl label namespace bookinfo istio-injection=enabled

# Verify the label
kubectl get namespace bookinfo --show-labels
```

```
NAME       STATUS   LABELS
bookinfo   Active   istio-injection=enabled
```

!!! note "Per-namespace injection"
    Only namespaces with `istio-injection=enabled` get sidecars. The `istio-system` namespace itself never gets injected.

---

## Step 5: Deploy the Bookinfo Sample App

Istio's canonical demo app — a book review site with four microservices:

```
productpage → details
           → reviews → ratings
```

```bash
kubectl apply -n bookinfo \
  -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/bookinfo/platform/kube/bookinfo.yaml

kubectl wait --for=condition=Ready pod \
  -n bookinfo --all --timeout=120s

kubectl get pods -n bookinfo
```

Each pod should show `2/2 Running` — one app container and one Envoy sidecar:

```
NAME                              READY   STATUS
details-v1-xxxxxxxxxx-xxxxx       2/2     Running
productpage-v1-xxxxxxxxxx-xxxxx   2/2     Running
ratings-v1-xxxxxxxxxx-xxxxx       2/2     Running
reviews-v1-xxxxxxxxxx-xxxxx       2/2     Running
reviews-v2-xxxxxxxxxx-xxxxx       2/2     Running
reviews-v3-xxxxxxxxxx-xxxxx       2/2     Running
```

---

## Step 6: Expose the App via Istio Gateway

```bash
kubectl apply -n bookinfo \
  -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/bookinfo/networking/bookinfo-gateway.yaml

# Get the ingress gateway NodePort
kubectl get svc istio-ingressgateway -n istio-system
```

Patch the ingress gateway to use NodePort 30080 (mapped in Lab 1):

```bash
kubectl patch svc istio-ingressgateway -n istio-system \
  --type='json' \
  -p='[{"op":"add","path":"/spec/ports/0/nodePort","value":30080}]'
```

Open `http://localhost:30080/productpage` — you should see the Bookinfo app.

---

## Step 7: Verify Istio Analysis

```bash
istioctl analyze -n bookinfo
```

Should return no errors or warnings. If it does, address them before moving on.

---

## Checkpoint

- [ ] All `istio-system` pods `Running`
- [ ] Observability addons installed (Kiali, Jaeger, Prometheus, Grafana)
- [ ] `bookinfo` namespace has `istio-injection=enabled`
- [ ] All bookinfo pods show `2/2 Running`
- [ ] `http://localhost:30080/productpage` loads

---

## Troubleshooting

### Pods show 1/1 instead of 2/2

Sidecar wasn't injected — the namespace label was missing when pods were created:

```bash
kubectl label namespace bookinfo istio-injection=enabled
kubectl rollout restart deployment -n bookinfo
```

### istioctl analyze shows warnings

```bash
istioctl analyze -n bookinfo --failure-threshold WARN
# Read the output and apply suggested fixes
```

---

**Next:** [Lab 2: Traffic Management](./lab2-traffic.md)
