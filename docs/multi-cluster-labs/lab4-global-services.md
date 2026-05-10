# Lab 4: Global Services and Cross-Cluster Discovery

## Objective

Create services that span both clusters. A client in mesh1 can access backends in mesh2 (and vice versa) using the same service name.

## Concepts First

### What is a Global Service?

A **Global Service** is a Kubernetes Service that exists in multiple clusters with the same name and namespace. Cilium Cluster Mesh treats all backends as one pool.

```
Without Global Service:
┌─────────────┐     ┌─────────────┐
│   mesh1     │     │   mesh2     │
│             │     │             │
│  svc: api ──┼──X──┼── svc: api  │  ← Same name, but isolated
│  └─► pod-a  │     │  └─► pod-b  │
└─────────────┘     └─────────────┘

With Global Service:
┌─────────────┐     ┌─────────────┐
│   mesh1     │     │   mesh2     │
│             │     │             │
│  svc: api ◄─┼─────┼─► svc: api  │  ← Shared backends!
│  └─► pod-a ─┼─────┼─► pod-b ◄───│
└─────────────┘     └─────────────┘

Client calling "api" gets load-balanced across pod-a AND pod-b
```

### Annotation Magic

Cilium uses an annotation to make services global:

```yaml
metadata:
  annotations:
    service.cilium.io/global: "true"
```

Additional options:

| Annotation | Effect |
|------------|--------|
| `service.cilium.io/global: "true"` | Enable global service |
| `service.cilium.io/shared: "false"` | Only use local backends (DR failover) |
| `service.cilium.io/affinity: "local"` | Prefer local, fallback to remote |

---

## Step 1: Deploy Backend Service in mesh2

We'll create a backend service that responds with its cluster name.

**Switch to mesh2:**

```bash
kubectl config use-context kind-mesh2
```

**Create the deployment:**

```bash
kubectl create namespace demo
kubectl apply -n demo -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: backend
        image: hashicorp/http-echo
        args:
        - "-text=Response from MESH2"
        - "-listen=:8080"
        ports:
        - containerPort: 8080
EOF
```

**Create the global service:**

```bash
kubectl apply -n demo -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: backend
  annotations:
    service.cilium.io/global: "true"
spec:
  selector:
    app: backend
  ports:
  - port: 8080
    targetPort: 8080
EOF
```

**Verify pods are running:**

```bash
kubectl get pods -n demo -o wide
```

!!! question "Before continuing"
    What happens if we try to access the `backend` service from mesh1 right now?

??? success "Answer"
    It won't work because:

    1. The service doesn't exist in mesh1 yet
    2. Even with Cluster Mesh, you need a local service definition to route traffic
    3. The service must exist in both clusters with the same name/namespace

---

## Step 2: Deploy Backend Service in mesh1

**Switch to mesh1:**

```bash
kubectl config use-context kind-mesh1
```

**Create namespace and deployment:**

```bash
kubectl create namespace demo
kubectl apply -n demo -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: backend
        image: hashicorp/http-echo
        args:
        - "-text=Response from MESH1"
        - "-listen=:8080"
        ports:
        - containerPort: 8080
EOF
```

**Create the matching global service:**

```bash
kubectl apply -n demo -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: backend
  annotations:
    service.cilium.io/global: "true"
spec:
  selector:
    app: backend
  ports:
  - port: 8080
    targetPort: 8080
EOF
```

---

## Step 3: Verify Global Service Is Working

**Check that Cilium sees backends from both clusters:**

```bash
CILIUM_POD=$(kubectl get pods -n kube-system -l k8s-app=cilium --context kind-mesh1 -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n kube-system $CILIUM_POD --context kind-mesh1 -- cilium service list | grep backend
```

You should see the service with backends from **both** clusters (4 total - 2 local + 2 remote).

**View detailed backend info:**

```bash
kubectl exec -n kube-system $CILIUM_POD --context kind-mesh1 -- cilium service list -o json | jq '.[] | select(.spec.frontend-address.port == 8080)'
```

---

## Step 4: Test Cross-Cluster Load Balancing

**Deploy a client pod in mesh1:**

```bash
kubectl run client --image=curlimages/curl --context kind-mesh1 -n demo --command -- sleep 3600
kubectl wait pod/client --for=condition=Ready --context kind-mesh1 -n demo
```

**Call the backend service multiple times:**

```bash
for i in {1..10}; do
  kubectl exec client -n demo --context kind-mesh1 -- curl -s http://backend:8080
  echo
done
```

!!! success "Expected output"
    You should see responses from both clusters:
    ```
    Response from MESH1
    Response from MESH2
    Response from MESH1
    Response from MESH2
    Response from MESH1
    Response from MESH2
    ...
    ```

    Load balancing is working across clusters!

---

## Step 5: Test Failover

What happens if one cluster's backends become unavailable?

**Scale down mesh1 backend to 0:**

```bash
kubectl scale deployment backend --replicas=0 -n demo --context kind-mesh1
```

**Test from client:**

```bash
for i in {1..5}; do
  kubectl exec client -n demo --context kind-mesh1 -- curl -s http://backend:8080
  echo
done
```

All responses should come from MESH2 now.

**Restore mesh1:**

```bash
kubectl scale deployment backend --replicas=2 -n demo --context kind-mesh1
```

---

## Step 6: Explore Service Affinity

You can prefer local backends while allowing remote fallback.

**Update the service to prefer local:**

```bash
kubectl apply -n demo --context kind-mesh1 -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: backend
  annotations:
    service.cilium.io/global: "true"
    service.cilium.io/affinity: "local"
spec:
  selector:
    app: backend
  ports:
  - port: 8080
    targetPort: 8080
EOF
```

**Test again:**

```bash
for i in {1..10}; do
  kubectl exec client -n demo --context kind-mesh1 -- curl -s http://backend:8080
  echo
done
```

With `affinity: local`, you should see mostly MESH1 responses (or all, depending on Cilium version).

**Scale down local to test fallback:**

```bash
kubectl scale deployment backend --replicas=0 -n demo --context kind-mesh1

# Now test - should fallback to MESH2
kubectl exec client -n demo --context kind-mesh1 -- curl -s http://backend:8080
```

---

## Step 7: Clean Up Demo Resources

```bash
kubectl delete namespace demo --context kind-mesh1
kubectl delete namespace demo --context kind-mesh2
```

---

## Checkpoint

Before challenges, verify you understand:

- [ ] How `service.cilium.io/global: "true"` works
- [ ] Service must exist in both clusters (same name/namespace)
- [ ] Cilium combines backends from all clusters
- [ ] `service.cilium.io/affinity: "local"` prefers local backends
- [ ] Failover happens automatically when backends are unavailable

---

## Real-World Use Cases

| Scenario | Configuration |
|----------|---------------|
| Active-active across regions | `global: "true"` on both |
| Primary + DR cluster | Primary: `global: "true"`, DR: `global: "true"` + `shared: "false"` |
| Prefer local, fallback remote | `global: "true"` + `affinity: "local"` |
| Hybrid cloud (on-prem + cloud) | `global: "true"` on both, possibly with affinity |

---

## Troubleshooting

### Service not showing remote backends

**Check service annotation:**

```bash
kubectl get svc backend -n demo -o jsonpath='{.metadata.annotations}' --context kind-mesh1
```

Must have `service.cilium.io/global: "true"`

**Check Cluster Mesh is connected:**

```bash
cilium clustermesh status --context kind-mesh1
```

**Check service sync:**

```bash
kubectl exec -n kube-system $CILIUM_POD -- cilium service list | grep -i backend
```

### Only seeing local backends

Verify:

1. Service exists in **both** clusters
2. Same **namespace** in both clusters
3. Same **service name** in both clusters
4. `global: "true"` annotation on both

### Latency issues

Cross-cluster calls traverse the mesh tunnel. For latency-sensitive apps:

1. Use `affinity: "local"` to prefer local
2. Consider topology-aware hints
3. Monitor with `cilium monitor` for packet flow

---

**Next:** [Lab 5: Challenges](./lab5-challenges.md)
