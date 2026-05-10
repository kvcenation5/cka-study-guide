# Lab 3: Enabling Cluster Mesh

## Objective

Connect both clusters using Cilium Cluster Mesh. You'll understand the mesh architecture and how cross-cluster communication is established.

## Concepts First

### How Cluster Mesh Works

```
┌─────────────────────────────────────────────────────────────────┐
│                         Cluster Mesh                            │
│                                                                 │
│  ┌─────────────────────┐         ┌─────────────────────┐       │
│  │      mesh1          │         │      mesh2          │       │
│  │                     │         │                     │       │
│  │ clustermesh-apiserver  ◄────► clustermesh-apiserver │       │
│  │         │           │  mTLS   │         │           │       │
│  │         ▼           │ tunnel  │         ▼           │       │
│  │   cilium-agents ────┼─────────┼───► cilium-agents   │       │
│  │                     │         │                     │       │
│  └─────────────────────┘         └─────────────────────┘       │
│                                                                 │
│  What gets shared:                                              │
│  - Service definitions (ClusterIP, endpoints)                   │
│  - Pod identity information                                     │
│  - Network policy context                                       │
└─────────────────────────────────────────────────────────────────┘
```

**Key components:**

- **clustermesh-apiserver**: etcd-based store that shares state between clusters
- **mTLS tunnel**: Encrypted connection between clusters
- **Cilium agents**: Read remote cluster state and program eBPF rules

### What Happens When You Enable Cluster Mesh?

1. A `clustermesh-apiserver` deployment is created in each cluster
2. TLS certificates are generated for secure communication
3. Each cluster's apiserver connects to the others
4. Cilium agents start syncing services and endpoints from remote clusters
5. eBPF maps are updated to include remote pod IPs

---

## Step 1: Enable Cluster Mesh on Both Clusters

**Enable on cluster 1:**

```bash
cilium clustermesh enable --context kind-mesh1 --service-type NodePort
```

!!! info "Why NodePort?"
    In KinD, we can't use LoadBalancer (no cloud provider). NodePort exposes the clustermesh-apiserver on a port accessible from other Docker containers.

**Enable on cluster 2:**

```bash
cilium clustermesh enable --context kind-mesh2 --service-type NodePort
```

**Wait for both to be ready:**

```bash
cilium clustermesh status --context kind-mesh1 --wait
cilium clustermesh status --context kind-mesh2 --wait
```

Expected output (for each):

```
✅ Service "clustermesh-apiserver" of type "NodePort" found
✅ Cluster access information is available:
  - 172.18.0.2:32379
✅ Deployment clustermesh-apiserver is ready
⚠️  Cluster is not connected to any other cluster
```

That warning is expected - we haven't connected them yet.

---

## Step 2: Examine What Was Created

**Check the new pods:**

```bash
kubectl get pods -n kube-system -l app=clustermesh-apiserver --context kind-mesh1
```

**Check the service:**

```bash
kubectl get svc -n kube-system clustermesh-apiserver --context kind-mesh1
```

Note the NodePort assigned (e.g., 32379).

**Check the secrets created:**

```bash
kubectl get secrets -n kube-system --context kind-mesh1 | grep clustermesh
```

You'll see:

- `clustermesh-apiserver-server-cert`: TLS cert for the apiserver
- `clustermesh-apiserver-admin-cert`: Admin cert for management
- `clustermesh-apiserver-client-cert`: Client cert for cilium-agents

!!! question "Understanding certificates"
    Why are certificates needed?

??? success "Answer"
    Cluster Mesh uses mTLS (mutual TLS). Both sides present certificates to authenticate. This prevents:

    - Unauthorized clusters joining the mesh
    - Man-in-the-middle attacks
    - Traffic interception between clusters

---

## Step 3: Connect the Clusters

This is the key step - telling each cluster about the other.

**Connect mesh2 to mesh1:**

```bash
cilium clustermesh connect \
  --context kind-mesh1 \
  --destination-context kind-mesh2
```

This command:

1. Extracts connection info from mesh2
2. Creates a secret in mesh1 with mesh2's address and CA cert
3. Tells mesh1's cilium-agents to connect to mesh2's apiserver

**Watch the connection establish:**

```bash
cilium clustermesh status --context kind-mesh1 --wait
```

Expected output:

```
✅ Service "clustermesh-apiserver" of type "NodePort" found
✅ Cluster access information is available:
  - 172.18.0.2:32379
✅ Deployment clustermesh-apiserver is ready
✅ All 3 nodes are connected to all clusters [min:1 / avg:1.0 / max:1]

Cluster Connections:
- mesh2: 3/3 nodes connected
```

---

## Step 4: Verify Bidirectional Connection

**Check from mesh2's perspective:**

```bash
cilium clustermesh status --context kind-mesh2
```

You should see mesh1 connected as well.

**Verify from cilium agents:**

```bash
# On mesh1, check an agent sees mesh2
CILIUM_POD=$(kubectl get pods -n kube-system -l k8s-app=cilium --context kind-mesh1 -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n kube-system $CILIUM_POD --context kind-mesh1 -- cilium clustermesh status
```

---

## Step 5: Understand the Shared State

**View remote services (from mesh1's perspective):**

```bash
kubectl exec -n kube-system $CILIUM_POD --context kind-mesh1 -- cilium service list | grep mesh2
```

Initially empty - we haven't created cross-cluster services yet.

**View the connection details:**

```bash
kubectl get secret -n kube-system clustermesh-mesh2 --context kind-mesh1 -o yaml
```

This secret contains:

- `etcd-config`: How to connect to mesh2's clustermesh-apiserver
- `ca.crt`: mesh2's CA certificate for TLS verification

---

## Step 6: Test Basic Connectivity

Let's verify the mesh tunnel works.

**Deploy a test pod in mesh1:**

```bash
kubectl run test-mesh1 --image=busybox --context kind-mesh1 --command -- sleep 3600
kubectl wait pod/test-mesh1 --for=condition=Ready --context kind-mesh1
```

**Get its IP:**

```bash
kubectl get pod test-mesh1 --context kind-mesh1 -o wide
```

**Deploy a test pod in mesh2:**

```bash
kubectl run test-mesh2 --image=busybox --context kind-mesh2 --command -- sleep 3600
kubectl wait pod/test-mesh2 --for=condition=Ready --context kind-mesh2
```

**Try to ping from mesh2 to mesh1's pod:**

```bash
MESH1_POD_IP=$(kubectl get pod test-mesh1 --context kind-mesh1 -o jsonpath='{.status.podIP}')
echo "mesh1 pod IP: $MESH1_POD_IP"

kubectl exec test-mesh2 --context kind-mesh2 -- ping -c 3 $MESH1_POD_IP
```

!!! success "Cross-cluster ping works!"
    If ping succeeds, the mesh tunnel is working. Packets are:

    1. Sent from test-mesh2 in mesh2
    2. Routed by Cilium to mesh1's cluster
    3. Delivered to test-mesh1

**Clean up test pods:**

```bash
kubectl delete pod test-mesh1 --context kind-mesh1
kubectl delete pod test-mesh2 --context kind-mesh2
```

---

## Checkpoint

Before moving to Lab 4, verify:

- [ ] `cilium clustermesh status` shows both clusters connected
- [ ] All nodes show connected (3/3 in each cluster)
- [ ] Cross-cluster pod-to-pod ping works
- [ ] You understand: clustermesh-apiserver, mTLS, NodePort service

**Quick verification:**

```bash
# Both should show the other cluster connected
cilium clustermesh status --context kind-mesh1
cilium clustermesh status --context kind-mesh2
```

---

## Troubleshooting

### "connection refused" when connecting

Check the NodePort service is accessible:

```bash
# Get mesh2's NodePort
kubectl get svc clustermesh-apiserver -n kube-system --context kind-mesh2 -o jsonpath='{.spec.ports[0].nodePort}'

# Get mesh2's control-plane IP
docker inspect mesh2-control-plane --format '{{ .NetworkSettings.Networks.kind.IPAddress }}'

# Test connectivity from mesh1's control-plane
docker exec mesh1-control-plane nc -zv <mesh2-ip> <nodeport>
```

### Nodes showing 0/3 connected

Cilium agents can't reach the remote apiserver. Check:

```bash
# Cilium agent logs
kubectl logs -n kube-system -l k8s-app=cilium --context kind-mesh1 --tail=50 | grep -i mesh
```

Common issues:

- Docker network isolation (shouldn't happen in KinD)
- Firewall rules
- Wrong port in connection info

### Certificates expired or invalid

Regenerate:

```bash
cilium clustermesh disable --context kind-mesh1
cilium clustermesh disable --context kind-mesh2
# Then re-enable and reconnect
```

---

## Architecture Deep Dive

Now that mesh is working, understand the data flow:

```
Pod A (mesh1) wants to reach Service B (mesh2)

1. Pod A sends packet to Service B's ClusterIP
2. Cilium agent on Pod A's node intercepts
3. Agent checks eBPF map - finds Service B backends include mesh2 pods
4. Agent encapsulates packet in tunnel (VXLAN or Geneve)
5. Packet travels over Docker network to mesh2 node
6. mesh2's Cilium agent decapsulates
7. Packet delivered to Service B's pod

All of this happens in kernel space via eBPF - no userspace proxying!
```

---

**Next:** [Lab 4: Global Services](./lab4-global-services.md)
