# Lab 1: Creating KinD Clusters for Cluster Mesh

## Objective

Create two KinD clusters configured for Cilium Cluster Mesh. You'll understand why each configuration option is needed.

## Concepts First

### Why KinD Needs Special Config for Cilium?

KinD (Kubernetes in Docker) runs cluster nodes as Docker containers. By default:

1. **KinD uses kindnet CNI** - We need to disable this for Cilium
2. **Nodes share the Docker network** - We need unique pod/service CIDRs per cluster
3. **No external connectivity** - We need port mappings for Cluster Mesh

### CIDR Planning

Each cluster needs unique IP ranges to avoid conflicts:

| Cluster | Pod CIDR | Service CIDR | Cluster ID |
|---------|----------|--------------|------------|
| mesh1 | 10.1.0.0/16 | 172.20.1.0/24 | 1 |
| mesh2 | 10.2.0.0/16 | 172.20.2.0/24 | 2 |

!!! warning "Why unique CIDRs?"
    If both clusters use 10.244.0.0/16 (KinD default), Cluster Mesh can't route traffic correctly. Pod A at 10.244.1.5 in cluster1 conflicts with Pod B at 10.244.1.5 in cluster2.

---

## Step 1: Create Cluster Configuration Files

First, understand what we're configuring:

```yaml
# Key settings explained:
networking:
  disableDefaultCNI: true   # Don't install kindnet, we'll use Cilium
  podSubnet: "10.1.0.0/16"  # Unique per cluster
  serviceSubnet: "172.20.1.0/24"  # Unique per cluster
```

**Create the config for cluster 1:**

```bash
cat > /tmp/mesh1-config.yaml << 'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: mesh1
networking:
  disableDefaultCNI: true
  podSubnet: "10.1.0.0/16"
  serviceSubnet: "172.20.1.0/24"
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 32000
        hostPort: 32000
        protocol: TCP
  - role: worker
  - role: worker
EOF
```

!!! question "Verify your understanding"
    Before creating cluster 2's config, answer:

    1. What should `podSubnet` be for mesh2?
    2. What should `serviceSubnet` be for mesh2?
    3. Why do we have `extraPortMappings`?

??? success "Answers"
    1. `10.2.0.0/16` - Different /16 block to avoid overlap
    2. `172.20.2.0/24` - Different subnet for services
    3. To expose NodePorts from inside Docker to your host machine

**Now create config for cluster 2:**

```bash
cat > /tmp/mesh2-config.yaml << 'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: mesh2
networking:
  disableDefaultCNI: true
  podSubnet: "10.2.0.0/16"
  serviceSubnet: "172.20.2.0/24"
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 32001
        hostPort: 32001
        protocol: TCP
  - role: worker
  - role: worker
EOF
```

---

## Step 2: Create the Clusters

**Create cluster 1:**

```bash
kind create cluster --config /tmp/mesh1-config.yaml
```

Watch the output. You should see:

```
Creating cluster "mesh1" ...
 ✓ Ensuring node image (kindest/node:v1.31.0)
 ✓ Preparing nodes
 ✓ Writing configuration
 ✓ Starting control-plane
 ✓ Installing StorageClass
Set kubectl context to "kind-mesh1"
```

!!! note "No CNI installed"
    Notice it doesn't say "Installing CNI" - that's because we disabled it. Pods won't be schedulable until we install Cilium.

**Create cluster 2:**

```bash
kind create cluster --config /tmp/mesh2-config.yaml
```

---

## Step 3: Verify Cluster State

**Check both contexts exist:**

```bash
kubectl config get-contexts
```

Expected output:

```
CURRENT   NAME         CLUSTER      AUTHINFO     NAMESPACE
          kind-mesh1   kind-mesh1   kind-mesh1
*         kind-mesh2   kind-mesh2   kind-mesh2
```

**Check nodes in each cluster:**

```bash
kubectl get nodes --context kind-mesh1
kubectl get nodes --context kind-mesh2
```

You should see 3 nodes per cluster (1 control-plane, 2 workers).

**Check pod status (they should be pending):**

```bash
kubectl get pods -A --context kind-mesh1
```

!!! warning "Expected: CoreDNS pods stuck in Pending"
    ```
    NAMESPACE     NAME                                    READY   STATUS
    kube-system   coredns-xxxxxx-xxxxx                    0/1     Pending
    kube-system   coredns-xxxxxx-xxxxx                    0/1     Pending
    ```

    This is correct! Without a CNI, pods can't get IP addresses and won't start.

---

## Step 4: Understand the Docker Network

Both clusters run on the same Docker network, which is how they'll communicate:

```bash
docker network ls | grep kind
```

**Inspect the network:**

```bash
docker network inspect kind | grep -A 5 "Containers"
```

You'll see all 6 nodes (3 per cluster) connected to the `kind` bridge network.

**Find each cluster's control-plane IP:**

```bash
# Cluster 1 control-plane IP
docker inspect mesh1-control-plane --format '{{ .NetworkSettings.Networks.kind.IPAddress }}'

# Cluster 2 control-plane IP
docker inspect mesh2-control-plane --format '{{ .NetworkSettings.Networks.kind.IPAddress }}'
```

Write these down - you'll need them for Cluster Mesh configuration.

---

## Checkpoint

Before moving to Lab 2, verify:

- [ ] Two clusters created: `kind-mesh1` and `kind-mesh2`
- [ ] Each cluster has 3 nodes (1 control-plane, 2 workers)
- [ ] CoreDNS pods are Pending (no CNI yet)
- [ ] You can switch contexts: `kubectl config use-context kind-mesh1`
- [ ] You know both control-plane IPs

**Test your context switching:**

```bash
# Switch to mesh1
kubectl config use-context kind-mesh1
kubectl cluster-info

# Switch to mesh2
kubectl config use-context kind-mesh2
kubectl cluster-info
```

---

## Troubleshooting

### "Error: failed to create cluster"

```bash
# Check Docker is running
docker info

# Check available resources (need ~8GB RAM for both clusters)
docker system info | grep Memory

# Delete existing clusters and retry
kind delete cluster --name mesh1
kind delete cluster --name mesh2
```

### "context not found"

```bash
# List all contexts
kubectl config get-contexts

# If missing, kubeconfig might not have been updated
kind export kubeconfig --name mesh1
kind export kubeconfig --name mesh2
```

### Nodes showing "NotReady"

This is expected without CNI! The nodes report NotReady because network isn't configured:

```bash
kubectl get nodes --context kind-mesh1
# NAME                  STATUS     ROLES
# mesh1-control-plane   NotReady   control-plane
# mesh1-worker          NotReady   <none>
# mesh1-worker2         NotReady   <none>
```

---

## Clean Up (if needed)

If you need to start over:

```bash
kind delete cluster --name mesh1
kind delete cluster --name mesh2
rm /tmp/mesh1-config.yaml /tmp/mesh2-config.yaml
```

---

**Next:** [Lab 2: Installing Cilium](./lab2-install-cilium.md)
