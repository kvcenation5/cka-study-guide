# Lab 1: Creating KinD Clusters for ArgoCD Multi-Cluster

## Objective

Create three KinD clusters — one hub (where ArgoCD runs) and two spokes (where apps get deployed). You'll understand the port mapping needed to expose the ArgoCD UI from inside Docker.

## Concepts First

### Hub/Spoke Model

```
Hub cluster  ──controls──►  Spoke cluster 1
             ──controls──►  Spoke cluster 2
```

ArgoCD runs **only on the hub**. It reaches the spoke clusters over the Docker network using their API server container IPs. No ArgoCD component runs on the spokes.

### Port Mapping for the ArgoCD UI

KinD nodes are Docker containers. To access ArgoCD from your Mac browser you map a container port to a host port:

| Cluster | NodePort | Host Port | Purpose |
|---------|----------|-----------|---------|
| hub | 30080 | 30080 | ArgoCD HTTP |
| hub | 30443 | 30443 | ArgoCD HTTPS |

Spoke clusters don't need port mappings — ArgoCD only talks to their API servers over the Docker bridge network.

---

## Step 1: Create the Hub Cluster Config

```bash
cat > /tmp/argocd-hub.yaml << 'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: argocd-hub
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 30080
        hostPort: 30080
        protocol: TCP
      - containerPort: 30443
        hostPort: 30443
        protocol: TCP
  - role: worker
  - role: worker
EOF
```

!!! note "Why NodePorts 30080 and 30443?"
    ArgoCD's server service will be patched to use these NodePorts. This lets you open `http://localhost:30080` on your Mac and hit ArgoCD directly.

---

## Step 2: Create the Spoke Cluster Configs

Spokes are simpler — no port mappings needed:

```bash
cat > /tmp/argocd-spoke1.yaml << 'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: spoke1
nodes:
  - role: control-plane
  - role: worker
EOF

cat > /tmp/argocd-spoke2.yaml << 'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: spoke2
nodes:
  - role: control-plane
  - role: worker
EOF
```

---

## Step 3: Create All Three Clusters

```bash
kind create cluster --config /tmp/argocd-hub.yaml
kind create cluster --config /tmp/argocd-spoke1.yaml
kind create cluster --config /tmp/argocd-spoke2.yaml
```

Each cluster takes 1–2 minutes. Watch for:

```
Creating cluster "argocd-hub" ...
 ✓ Ensuring node image (kindest/node:v1.31.0)
 ✓ Preparing nodes
 ✓ Writing configuration
 ✓ Starting control-plane
 ✓ Installing StorageClass
 ✓ Installing CNI
Set kubectl context to "kind-argocd-hub"
```

!!! note "CNI installed automatically"
    Unlike the Cilium lab, we keep the default CNI (kindnet). All pods come up ready without extra steps.

---

## Step 4: Verify All Clusters

```bash
kubectl config get-contexts
```

Expected:

```
CURRENT   NAME               CLUSTER            AUTHINFO
          kind-argocd-hub    kind-argocd-hub    kind-argocd-hub
          kind-spoke1        kind-spoke1        kind-spoke1
*         kind-spoke2        kind-spoke2        kind-spoke2
```

```bash
kubectl get nodes --context kind-argocd-hub
kubectl get nodes --context kind-spoke1
kubectl get nodes --context kind-spoke2
```

All nodes should be `Ready`.

---

## Step 5: Understand the Docker Network

All KinD clusters share the `kind` Docker bridge network. This is how ArgoCD on the hub reaches the spoke API servers:

```bash
docker network inspect kind | python3 -c "
import json, sys
data = json.load(sys.stdin)
for name, c in data[0]['Containers'].items():
    print(c['Name'], '->', c['IPv4Address'])
"
```

**Note each cluster's control-plane IP** — you'll need these in Lab 3:

```bash
docker inspect argocd-hub-control-plane --format '{{ .NetworkSettings.Networks.kind.IPAddress }}'
docker inspect spoke1-control-plane     --format '{{ .NetworkSettings.Networks.kind.IPAddress }}'
docker inspect spoke2-control-plane     --format '{{ .NetworkSettings.Networks.kind.IPAddress }}'
```

---

## Checkpoint

- [ ] Three contexts exist: `kind-argocd-hub`, `kind-spoke1`, `kind-spoke2`
- [ ] All nodes show `Ready`
- [ ] You can switch contexts and run `kubectl cluster-info`

## Troubleshooting

### "port is already allocated"

```bash
lsof -i :30080   # find what's using it
kind delete cluster --name argocd-hub
kind create cluster --config /tmp/argocd-hub.yaml
```

### Clean up and restart

```bash
kind delete cluster --name argocd-hub
kind delete cluster --name spoke1
kind delete cluster --name spoke2
```

---

**Next:** [Lab 2: Installing ArgoCD](./lab2-install-argocd.md)
