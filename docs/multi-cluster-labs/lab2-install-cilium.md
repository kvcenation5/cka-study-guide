# Lab 2: Installing Cilium CNI

## Objective

Install Cilium on both clusters and understand the components. By the end, both clusters will have working networking.

## Concepts First

### What is Cilium?

Cilium is a CNI plugin that uses **eBPF** (extended Berkeley Packet Filter) instead of iptables for networking. Key advantages:

| Feature | iptables-based CNI | Cilium (eBPF) |
|---------|-------------------|---------------|
| Performance | O(n) rule lookup | O(1) map lookup |
| Observability | Limited | Full L3-L7 visibility |
| Network Policies | L3/L4 only | L3-L7 (HTTP, gRPC, DNS) |
| Multi-cluster | Complex setup | Native Cluster Mesh |

### Cilium Components

When you install Cilium, you get:

```
┌─────────────────────────────────────────────────────────┐
│                    Control Plane                        │
│  ┌─────────────────┐    ┌─────────────────────────┐    │
│  │ cilium-operator │    │ clustermesh-apiserver   │    │
│  │ (1 replica)     │    │ (for multi-cluster)     │    │
│  └─────────────────┘    └─────────────────────────┘    │
├─────────────────────────────────────────────────────────┤
│                    Per Node (DaemonSet)                 │
│  ┌─────────────────┐    ┌─────────────────────────┐    │
│  │  cilium-agent   │    │     cilium-envoy        │    │
│  │  (eBPF loader)  │    │   (L7 proxy, optional)  │    │
│  └─────────────────┘    └─────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

- **cilium-agent**: Runs on every node, manages eBPF programs
- **cilium-operator**: Cluster-wide operations (IP allocation, etc.)
- **clustermesh-apiserver**: Shares state between clusters (installed in Lab 3)

---

## Step 1: Install Cilium on Cluster 1

**Switch to cluster 1:**

```bash
kubectl config use-context kind-mesh1
```

**Verify you're on the right cluster:**

```bash
kubectl config current-context
# Should output: kind-mesh1
```

**Install Cilium with Cluster Mesh prerequisites:**

```bash
cilium install \
  --set cluster.id=1 \
  --set cluster.name=mesh1 \
  --set ipam.mode=kubernetes
```

!!! info "What these flags mean"
    - `cluster.id=1`: Unique numeric ID for this cluster (used in Cluster Mesh)
    - `cluster.name=mesh1`: Human-readable name
    - `ipam.mode=kubernetes`: Use Kubernetes-native IP address management

**Watch the installation:**

```bash
cilium status --wait
```

This will wait until Cilium is fully operational. You should see:

```
    /¯¯\
 /¯¯\__/¯¯\    Cilium:             OK
 \__/¯¯\__/    Operator:           OK
 /¯¯\__/¯¯\    Envoy DaemonSet:    disabled (not required)
 \__/¯¯\__/    Hubble Relay:       disabled
    \__/       ClusterMesh:        disabled

Deployment             cilium-operator    Desired: 1, Ready: 1/1
DaemonSet              cilium             Desired: 3, Ready: 3/3
```

---

## Step 2: Verify Cilium Installation on Cluster 1

**Check all Cilium pods are running:**

```bash
kubectl get pods -n kube-system -l app.kubernetes.io/part-of=cilium
```

Expected:

```
NAME                              READY   STATUS    RESTARTS   AGE
cilium-xxxxx                      1/1     Running   0          2m
cilium-xxxxx                      1/1     Running   0          2m
cilium-xxxxx                      1/1     Running   0          2m
cilium-operator-xxxxxxx-xxxxx     1/1     Running   0          2m
```

**Check nodes are now Ready:**

```bash
kubectl get nodes
```

Now they should show `Ready`:

```
NAME                  STATUS   ROLES           AGE   VERSION
mesh1-control-plane   Ready    control-plane   10m   v1.31.0
mesh1-worker          Ready    <none>          10m   v1.31.0
mesh1-worker2         Ready    <none>          10m   v1.31.0
```

**Check CoreDNS is running:**

```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
```

CoreDNS should now be `Running` (it was `Pending` before).

---

## Step 3: Explore Cilium Agent

Let's understand what Cilium installed on each node.

**Exec into a Cilium agent:**

```bash
CILIUM_POD=$(kubectl get pods -n kube-system -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n kube-system $CILIUM_POD -- cilium status
```

**View endpoints (network identities):**

```bash
kubectl exec -n kube-system $CILIUM_POD -- cilium endpoint list
```

You'll see entries for system pods (CoreDNS, etc.). Each has:

- **ID**: Local endpoint identifier
- **Identity**: Cilium security identity
- **IPv4/IPv6**: Assigned IP addresses
- **Status**: Health state

**View the eBPF maps:**

```bash
kubectl exec -n kube-system $CILIUM_POD -- cilium bpf lb list
```

This shows the load balancer entries - every Kubernetes Service is programmed here.

---

## Step 4: Install Cilium on Cluster 2

**Switch to cluster 2:**

```bash
kubectl config use-context kind-mesh2
```

**Install Cilium with cluster 2 settings:**

```bash
cilium install \
  --set cluster.id=2 \
  --set cluster.name=mesh2 \
  --set ipam.mode=kubernetes
```

!!! question "Before waiting, predict:"
    What `cluster.id` did we use? Why must it be different from cluster 1?

??? success "Answer"
    We used `cluster.id=2`. Each cluster in a Cluster Mesh must have a unique ID (1-255). This ID is embedded in pod identity information and used to route traffic correctly.

**Wait for installation:**

```bash
cilium status --wait
```

---

## Step 5: Verify Both Clusters

**Run connectivity tests on each cluster:**

```bash
# Test cluster 1
cilium connectivity test --context kind-mesh1 --test "ping" --test "http"

# Test cluster 2
cilium connectivity test --context kind-mesh2 --test "ping" --test "http"
```

This deploys test pods and verifies networking works.

!!! note "Full connectivity test"
    `cilium connectivity test` (without `--test` flags) runs the full suite (~60 tests). It takes ~10 minutes but is comprehensive. Try it later:
    ```bash
    cilium connectivity test --context kind-mesh1
    ```

---

## Step 6: Understanding What You Installed

**Compare iptables vs eBPF:**

Check if iptables rules were created (there should be very few):

```bash
kubectl exec -n kube-system $CILIUM_POD -- iptables -L -n | head -20
```

Now check eBPF maps (where the real work happens):

```bash
kubectl exec -n kube-system $CILIUM_POD -- cilium bpf ct list global | head -20
```

The `ct` (connection tracking) map shows all active connections, handled in kernel space by eBPF.

---

## Checkpoint

Before moving to Lab 3, verify:

- [ ] Cilium running on both clusters
- [ ] All nodes show `Ready` in both clusters
- [ ] CoreDNS running in both clusters
- [ ] `cilium status` shows OK on both clusters
- [ ] You understand: cluster.id, cluster.name, IPAM mode

**Quick verification:**

```bash
# Should both show "OK" status
cilium status --context kind-mesh1
cilium status --context kind-mesh2
```

---

## Troubleshooting

### Cilium pods in CrashLoopBackOff

Check logs:

```bash
kubectl logs -n kube-system -l k8s-app=cilium --tail=50
```

Common issues:

- **BPF filesystem not mounted**: KinD usually handles this, but check `mount | grep bpf`
- **Kernel too old**: Need Linux 4.9+ (Docker Desktop handles this)

### Nodes still NotReady after Cilium install

Check Cilium agent is running on that node:

```bash
kubectl get pods -n kube-system -l k8s-app=cilium -o wide
```

If a node's Cilium pod is missing or failing, check node resources:

```bash
kubectl describe node <node-name> | grep -A 10 Conditions
```

### "cluster.id must be set"

You ran `cilium install` without `--set cluster.id`. Uninstall and retry:

```bash
cilium uninstall
cilium install --set cluster.id=1 --set cluster.name=mesh1 --set ipam.mode=kubernetes
```

---

## What's Next?

You have two isolated clusters, each with working Cilium networking. In Lab 3, we'll connect them with Cluster Mesh.

```
Current state:
┌────────────┐         ┌────────────┐
│   mesh1    │   ???   │   mesh2    │
│  (working) │         │  (working) │
└────────────┘         └────────────┘

After Lab 3:
┌────────────┐ ◄─────► ┌────────────┐
│   mesh1    │  mesh   │   mesh2    │
│  (working) │  tunnel │  (working) │
└────────────┘         └────────────┘
```

---

**Next:** [Lab 3: Enabling Cluster Mesh](./lab3-cluster-mesh.md)
