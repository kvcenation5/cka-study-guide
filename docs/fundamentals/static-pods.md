# Understanding Static Pods in Kubernetes

## What are Static Pods?

**Static Pods** are pods that are managed directly by the **kubelet** on a specific node, **without** the Kubernetes API server or any controllers (like Deployments or ReplicaSets) managing them.

!!! note "Key Difference"
    - **Regular Pods**: Created and managed by the API server and controllers
    - **Static Pods**: Created and managed directly by kubelet on each node

## How Static Pods Work

### The Basic Concept

```
Regular Pod Flow:
User → kubectl → API Server → Scheduler → Kubelet → Pod

Static Pod Flow:
Manifest file on node → Kubelet reads it → Kubelet creates Pod
(No API server, no scheduler involved!)
```

### Where Kubelet Gets Manifests

The kubelet watches a specific directory on the node's filesystem for YAML/JSON pod manifests:

**Default location (configurable):**
```bash
/etc/kubernetes/manifests/
```

This path is defined in the kubelet configuration.

### The Process

1. **You place a pod manifest** in `/etc/kubernetes/manifests/`
2. **Kubelet watches this directory** (filesystem monitoring)
3. **Kubelet reads the manifest** and creates the pod
4. **Kubelet manages the pod** directly
5. **If the pod crashes**, kubelet restarts it automatically
6. **If you delete the manifest file**, kubelet deletes the pod
7. **If you modify the manifest file**, kubelet updates the pod

!!! tip "Self-Healing"
    Static pods are automatically restarted by kubelet if they crash, just like regular pods.

## Configuration

### Finding the Static Pod Path

The static pod path is configured in the kubelet config file:

```bash
# Check kubelet config
cat /var/lib/kubelet/config.yaml
```

Look for:
```yaml
staticPodPath: /etc/kubernetes/manifests
```

Or in the kubelet service file:
```bash
systemctl status kubelet
# Look for --pod-manifest-path flag
```

### Alternative Configuration Methods

**Method 1: Static Pod Path (Recommended)**
```yaml
# /var/lib/kubelet/config.yaml
staticPodPath: /etc/kubernetes/manifests
```

**Method 2: Manifest URL**
```yaml
# /var/lib/kubelet/config.yaml
staticPodURL: http://example.com/manifests/
```

Kubelet can fetch manifests from a URL (less common).

## Creating a Static Pod

### Example: Creating a Static Nginx Pod

**Step 1: Create the manifest**

```bash
# SSH to the node
ssh user@node1

# Create manifest in the static pod directory
sudo vim /etc/kubernetes/manifests/static-nginx.yaml
```

**Step 2: Add the pod definition**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: static-nginx
  labels:
    app: nginx
    type: static
spec:
  containers:
  - name: nginx
    image: nginx:1.19
    ports:
    - containerPort: 80
```

**Step 3: Save the file**

The kubelet automatically detects the file and creates the pod!

**Step 4: Verify**

```bash
# On the node
sudo crictl pods
# You'll see static-nginx running

# From master node (if API server is running)
kubectl get pods -A
# You'll see static-nginx-node1 (note the node name suffix)
```

### Naming Convention

Static pods appear in `kubectl get pods` with the **node name as a suffix**:

```
Pod manifest name: static-nginx
Actual pod name:   static-nginx-node1
                                 ^^^^^ node hostname appended
```

## Why Static Pods are Needed

### 1. Bootstrapping the Control Plane

**The Chicken-and-Egg Problem:**

How do you run the API server if you need the API server to run pods?

**Answer: Static Pods!**

On a kubeadm-created cluster, the control plane components run as static pods:

```bash
# On master node
ls /etc/kubernetes/manifests/

# Output:
etcd.yaml
kube-apiserver.yaml
kube-controller-manager.yaml
kube-scheduler.yaml
```

**The Bootstrap Process:**

1. Node boots up
2. Kubelet starts (it's a system service)
3. Kubelet reads `/etc/kubernetes/manifests/`
4. Kubelet starts:
   - etcd (static pod)
   - kube-apiserver (static pod)
   - kube-controller-manager (static pod)
   - kube-scheduler (static pod)
5. Now the control plane is running!
6. Now the API server can manage regular pods

!!! success "Self-Hosting"
    This is called "self-hosting" - Kubernetes manages itself using its own mechanisms.

### 2. Critical Node-Specific Services

Services that **must** run on specific nodes, independent of the control plane:

- **Monitoring agents** that must run even if the control plane is down
- **Logging agents** that collect kubelet logs
- **Node-critical workloads** that need guaranteed placement

### 3. Air-Gapped or Isolated Environments

In environments without API server access:

- Edge computing nodes
- IoT devices
- Disconnected/offline scenarios
- Disaster recovery scenarios

### 4. Cluster Recovery

If the control plane crashes but nodes are still running:

- Static pods keep running
- Critical services remain available
- You can troubleshoot and recover

## What Happens When There's No Master Node?

This is where static pods shine!

### Scenario: Master Node is Down

```
Before (Normal Operation):
┌─────────────┐         ┌──────────────┐
│ Master Node │────────▶│ Worker Node  │
│ API Server  │ manages │ Regular Pods │
│ Scheduler   │         │              │
└─────────────┘         └──────────────┘

After (Master Down):
┌─────────────┐         ┌──────────────┐
│ Master Node │  XXXX   │ Worker Node  │
│   (DOWN)    │  DEAD   │ Static Pods  │
│             │         │ STILL RUNNING│
└─────────────┘         └──────────────┘
```

### What Happens to Different Pod Types

**Static Pods:**
```
✅ Keep running
✅ Kubelet restarts them if they crash
✅ Completely independent of master
✅ Can still be managed via manifest files
```

**Regular Pods (DaemonSets, Deployments, etc.):**
```
✅ Keep running (for now)
❌ If they crash, they won't be restarted
❌ No new pods can be scheduled
❌ Cannot be updated or scaled
⚠️  Gradually become unhealthy
```

### Practical Example

**Setup:**
```bash
# Master node runs control plane as static pods
/etc/kubernetes/manifests/
  ├── etcd.yaml
  ├── kube-apiserver.yaml
  ├── kube-controller-manager.yaml
  └── kube-scheduler.yaml

# Worker node runs application as regular pod
# Plus a monitoring agent as static pod
/etc/kubernetes/manifests/
  └── node-monitoring.yaml
```

**Master fails:**
```
Master Node:
  ❌ API server - down
  ❌ Scheduler - down
  ❌ Controller manager - down

Worker Node:
  ✅ Static monitoring pod - still running
  ✅ Application pods - still running (for now)
  ❌ If app pod crashes - won't restart (no controller)
  ✅ If static pod crashes - kubelet restarts it
```

**Recovery:**
```bash
# Even with master down, you can still manage static pods

# Add new static pod on worker
ssh worker-node
sudo vim /etc/kubernetes/manifests/debug-pod.yaml
# Pod starts immediately!

# Remove static pod
sudo rm /etc/kubernetes/manifests/debug-pod.yaml
# Pod stops immediately!
```

## Static Pods vs Regular Pods

| Feature | Static Pods | Regular Pods |
|---------|-------------|--------------|
| **Managed by** | Kubelet directly | API server + controllers |
| **Manifest location** | Node filesystem | etcd (via API server) |
| **Survives master failure** | ✅ Yes | ❌ No (won't restart if crashed) |
| **Can be created via kubectl** | ❌ No | ✅ Yes |
| **Visible in kubectl get pods** | ✅ Yes (as mirror pods) | ✅ Yes |
| **Can be deleted via kubectl** | ❌ No (must delete manifest file) | ✅ Yes |
| **Scheduled by scheduler** | ❌ No (always on same node) | ✅ Yes |
| **Node binding** | ✅ Permanent (tied to node) | ❌ Can be rescheduled |
| **Restart policy** | ✅ Kubelet restarts | ✅ Controller restarts |

## Mirror Pods

When a static pod is created, kubelet creates a **mirror pod** in the API server (if it's available).

### What is a Mirror Pod?

A **read-only** representation of the static pod in the API server:

```
Node Filesystem:           API Server (etcd):
/etc/kubernetes/manifests/ 
  └── nginx.yaml    ────▶  Mirror Pod: nginx-node1
                           (read-only reflection)
```

**Characteristics:**
- ✅ Visible via `kubectl get pods`
- ❌ Cannot be deleted via `kubectl delete`
- ❌ Cannot be modified via `kubectl edit`
- ✅ Shows status and logs
- ✅ Automatically updated when manifest changes

**Identifying Mirror Pods:**

```bash
kubectl get pod static-nginx-node1 -o yaml
```

Look for this annotation:
```yaml
metadata:
  annotations:
    kubernetes.io/config.mirror: "true"  # This is a mirror pod!
  ownerReferences:
  - apiVersion: v1
    kind: Node
    name: node1
    uid: ...
```

### Trying to Delete a Mirror Pod

```bash
# This appears to work...
kubectl delete pod static-nginx-node1
# pod "static-nginx-node1" deleted

# But the pod comes right back!
kubectl get pods
# NAME                  READY   STATUS    RESTARTS   AGE
# static-nginx-node1    1/1     Running   0          3s

# Because kubelet recreates it from the manifest file!
```

**To actually delete it:**
```bash
# SSH to the node
ssh node1

# Delete the manifest file
sudo rm /etc/kubernetes/manifests/static-nginx.yaml

# Now it's really gone
kubectl get pods
# No resources found
```

## Use Cases and Scenarios

### Use Case 1: Control Plane Components

**Scenario:** Running Kubernetes control plane itself

```bash
# On master node
ls /etc/kubernetes/manifests/
```

**Manifests:**
```
etcd.yaml                    # Database for cluster state
kube-apiserver.yaml          # API server
kube-controller-manager.yaml # Controllers
kube-scheduler.yaml          # Scheduler
```

**Why static pods?**
- Control plane needs to start before API server is available
- Self-hosting: Kubernetes manages its own components
- Survives control plane failures (can restart itself)

### Use Case 2: Node Monitoring Agent

**Scenario:** Critical monitoring that must always run

```yaml
# /etc/kubernetes/manifests/node-exporter.yaml
apiVersion: v1
kind: Pod
metadata:
  name: node-exporter
  labels:
    app: monitoring
spec:
  hostNetwork: true
  hostPID: true
  containers:
  - name: node-exporter
    image: prom/node-exporter:latest
    ports:
    - containerPort: 9100
    volumeMounts:
    - name: proc
      mountPath: /host/proc
      readOnly: true
    - name: sys
      mountPath: /host/sys
      readOnly: true
  volumes:
  - name: proc
    hostPath:
      path: /proc
  - name: sys
    hostPath:
      path: /sys
```

**Why static pod?**
- Runs even if master is down
- Monitors node health independently
- Guaranteed to be on specific node

### Use Case 3: Edge Computing

**Scenario:** IoT device with intermittent master connectivity

```
Cloud (Master):              Edge Device (Worker):
┌──────────────┐            ┌─────────────────────┐
│ API Server   │            │ Kubelet             │
│ (Sometimes   │ ◀────┬────▶│ Static Pods:        │
│  unreachable)│      │     │  - Data collector   │
└──────────────┘      │     │  - Local processor  │
                      │     │  - Cache service    │
        Intermittent  │     └─────────────────────┘
        connection    │
                      └─── Works offline!
```

**Static pods on edge device:**
```bash
/etc/kubernetes/manifests/
  ├── data-collector.yaml    # Collects sensor data
  ├── local-processor.yaml   # Processes data locally
  └── cache-service.yaml     # Caches data for sync
```

**Benefits:**
- Works offline when master is unreachable
- Guaranteed to run on edge device
- Kubelet manages lifecycle independently

### Use Case 4: Disaster Recovery

**Scenario:** Control plane crashed, need to debug

```bash
# Master is completely down
# But you can still deploy debug tools as static pods!

# SSH to worker node
ssh worker-node1

# Create debug pod
cat <<EOF | sudo tee /etc/kubernetes/manifests/debug.yaml
apiVersion: v1
kind: Pod
metadata:
  name: debug-tools
spec:
  hostNetwork: true
  containers:
  - name: debug
    image: nicolaka/netshoot
    command: ["sleep", "infinity"]
EOF

# Pod starts immediately!
# Now you can exec into it and debug
sudo crictl exec -it <container-id> bash
```

### Use Case 5: Custom Node Services

**Scenario:** Node-specific service that must run on exact node

```yaml
# /etc/kubernetes/manifests/local-cache.yaml
apiVersion: v1
kind: Pod
metadata:
  name: local-cache
spec:
  containers:
  - name: redis
    image: redis:alpine
    volumeMounts:
    - name: cache-data
      mountPath: /data
  volumes:
  - name: cache-data
    hostPath:
      path: /mnt/ssd/redis-cache  # Fast local SSD
      type: DirectoryOrCreate
```

**Why static pod?**
- Guaranteed placement on node with specific hardware (SSD)
- Uses local node storage
- No risk of being rescheduled elsewhere

## Managing Static Pods

### Creating

```bash
# SSH to node
ssh node1

# Create manifest
sudo vim /etc/kubernetes/manifests/my-pod.yaml

# Kubelet detects and creates it automatically
```

### Updating

```bash
# Edit the manifest file
sudo vim /etc/kubernetes/manifests/my-pod.yaml

# Kubelet detects changes and recreates the pod
# (Old pod deleted, new pod created)
```

### Deleting

```bash
# Remove the manifest file
sudo rm /etc/kubernetes/manifests/my-pod.yaml

# Kubelet detects deletion and removes the pod
```

### Viewing Logs

```bash
# From node (using crictl)
sudo crictl logs <container-id>

# From master (using kubectl, if API server is up)
kubectl logs static-pod-name-node1
```

### Debugging

```bash
# Check if kubelet is watching the directory
sudo journalctl -u kubelet -f

# Check pod status on node
sudo crictl pods

# Check pod status via kubectl
kubectl get pods -A -o wide | grep node1

# Describe the mirror pod
kubectl describe pod static-pod-name-node1
```

## Common Issues and Solutions

### Issue 1: Static Pod Not Starting

**Problem:**
```bash
# Created manifest but pod doesn't start
sudo vim /etc/kubernetes/manifests/test.yaml
# ... wait ...
crictl pods  # Pod not showing up
```

**Solutions:**

1. **Check kubelet is running:**
```bash
sudo systemctl status kubelet
```

2. **Check kubelet logs:**
```bash
sudo journalctl -u kubelet -f
# Look for errors parsing manifest
```

3. **Verify static pod path:**
```bash
cat /var/lib/kubelet/config.yaml | grep staticPodPath
```

4. **Check manifest syntax:**
```bash
# Validate YAML
kubectl apply --dry-run=client -f /etc/kubernetes/manifests/test.yaml
```

### Issue 2: Cannot Delete Static Pod

**Problem:**
```bash
kubectl delete pod static-nginx-node1
# pod "static-nginx-node1" deleted

kubectl get pods
# Pod comes right back!
```

**Solution:**
```bash
# You must delete the manifest file on the node
ssh node1
sudo rm /etc/kubernetes/manifests/static-nginx.yaml
```

### Issue 3: Static Pod Path Changed

**Problem:**
```bash
# Changed kubelet config but pods not loading
```

**Solution:**
```bash
# Restart kubelet after changing config
sudo systemctl restart kubelet

# Verify new path is loaded
sudo journalctl -u kubelet | grep staticPodPath
```

## Static Pods in CKA Exam

### Common Tasks

**Task 1: Create a static pod**

```bash
# SSH to the specified node
ssh node01

# Create manifest in static pod directory
sudo vim /etc/kubernetes/manifests/static-web.yaml
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: static-web
spec:
  containers:
  - name: nginx
    image: nginx
```

**Task 2: Identify static pods**

```bash
# Look for pods with node name suffix
kubectl get pods -A

# Check for mirror pod annotation
kubectl get pod <pod-name> -o yaml | grep config.mirror
```

**Task 3: Delete a static pod**

```bash
# Identify which node it's on
kubectl get pod static-pod-node01 -o wide

# SSH to that node
ssh node01

# Find and delete manifest
ls /etc/kubernetes/manifests/
sudo rm /etc/kubernetes/manifests/static-pod.yaml
```

**Task 4: Find static pod manifest path**

```bash
# Check kubelet config
cat /var/lib/kubelet/config.yaml | grep staticPodPath

# Or check systemd service
ps aux | grep kubelet | grep pod-manifest-path
```

## Best Practices

### Do's

✅ **Use for control plane components** - Industry standard  
✅ **Use for critical node services** - Monitoring, logging  
✅ **Use for guaranteed placement** - When pod MUST be on specific node  
✅ **Use for offline scenarios** - Edge computing, air-gapped  
✅ **Keep manifests simple** - Static pods should be straightforward  

### Don'ts

❌ **Don't use for regular applications** - Use Deployments instead  
❌ **Don't use for scaling** - Static pods don't scale (one per node)  
❌ **Don't use for stateful sets** - Use StatefulSets  
❌ **Don't use for multi-node deployments** - Use DaemonSets  
❌ **Don't modify via kubectl** - Edit manifest files directly  

## Comparison with DaemonSets

Both run one pod per node, but they're different:

| Feature | Static Pods | DaemonSets |
|---------|-------------|------------|
| **Managed by** | Kubelet | DaemonSet controller (API server) |
| **Survives master failure** | ✅ Yes | ❌ No |
| **Node selection** | ❌ Fixed to one node | ✅ All nodes (or selected) |
| **Managed via** | Manifest files | kubectl / YAML |
| **Use case** | Control plane, critical services | Cluster-wide agents |

**When to use which:**

- **Static Pods**: Control plane, critical single-node services
- **DaemonSets**: Cluster-wide agents (logging, monitoring, networking)

## Summary

### Key Points

!!! success "Static Pods Essentials"
    ✅ Managed directly by kubelet, not API server  
    ✅ Manifests stored in `/etc/kubernetes/manifests/` (default)  
    ✅ Survive master node failures  
    ✅ Cannot be deleted via kubectl  
    ✅ Always run on the same specific node  
    ✅ Used for control plane components  
    ✅ Create mirror pods in API server (when available)  

### When to Use Static Pods

1. **Control plane components** (API server, scheduler, etc.)
2. **Critical node-specific services** (monitoring, logging)
3. **Edge computing** scenarios
4. **Air-gapped** environments
5. **Disaster recovery** situations
6. **Services requiring guaranteed node placement**

### Quick Reference

```bash
# Find static pod path
cat /var/lib/kubelet/config.yaml | grep staticPodPath

# Create static pod
sudo vim /etc/kubernetes/manifests/my-pod.yaml

# Delete static pod
sudo rm /etc/kubernetes/manifests/my-pod.yaml

# View static pods (as mirror pods)
kubectl get pods -A | grep <node-name>

# Identify static pod
kubectl get pod <name> -o yaml | grep config.mirror

# Check kubelet logs
sudo journalctl -u kubelet -f
```

---

*Static pods are a powerful mechanism for running critical services independently of the Kubernetes control plane, providing resilience and enabling self-hosted clusters.*
