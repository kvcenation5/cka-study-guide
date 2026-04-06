# CKA Mock Test 3

This is your third practice test for the Certified Kubernetes Administrator exam.

## Questions

### Question 1: Configure Sysctl Parameters for Kubeadm
**Scenario**: Prepare system network parameters for Kubernetes cluster installation using kubeadm.

**Task**: Configure the following sysctl parameters to support Kubernetes networking, ensuring they persist across reboots:
- `net.ipv4.ip_forward = 1`
- `net.bridge.bridge-nf-call-iptables = 1`

**Answer**:

**Method 1: Using sysctl command (temporary + persistent)**
```bash
# Step 1: Set parameters immediately (runtime)
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.bridge.bridge-nf-call-iptables=1

# Step 2: Make persistent by adding to /etc/sysctl.conf
cat <<EOF | sudo tee /etc/sysctl.conf
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

# Or create a separate file in sysctl.d (recommended)
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

# Step 3: Apply all sysctl settings
sudo sysctl --system

# Alternative: Reload specific parameters
sudo sysctl -p /etc/sysctl.d/99-kubernetes-cri.conf
```

**Method 2: Direct file editing**
```bash
# Check current values
sysctl net.ipv4.ip_forward
sysctl net.bridge.bridge-nf-call-iptables

# Edit sysctl configuration
sudo vi /etc/sysctl.conf
# Add these lines:
# net.ipv4.ip_forward = 1
# net.bridge.bridge-nf-call-iptables = 1

# Apply changes
sudo sysctl -p
```

**Verification Commands**:
```bash
# Check current runtime values
sysctl net.ipv4.ip_forward
sysctl net.bridge.bridge-nf-call-iptables

# Check values in proc filesystem
cat /proc/sys/net/ipv4/ip_forward
cat /proc/sys/net/bridge/bridge-nf-call-iptables

# Verify persistent configuration
grep -E "net.ipv4.ip_forward|net.bridge.bridge-nf-call-iptables" /etc/sysctl.conf /etc/sysctl.d/*.conf 2>/dev/null

# Test after reboot (values should persist)
# reboot and check again
```

**Why These Parameters Are Required**:
- **`net.ipv4.ip_forward=1`**: Enables IP forwarding for pod-to-pod communication and external traffic routing
- **`net.bridge.bridge-nf-call-iptables=1`**: Ensures iptables rules are applied to bridged traffic (required for kube-proxy and CNI plugins)

**Common kubeadm Pre-requisites**:
```bash
# Load required kernel modules
sudo modprobe overlay
sudo modprobe br_netfilter

# Verify modules are loaded
lsmod | grep -E "overlay|br_netfilter"

# Make modules persistent
sudo tee /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF
```

**Verification Checklist**:
- ✅ net.ipv4.ip_forward is set to 1
- ✅ net.bridge.bridge-nf-call-iptables is set to 1
- ✅ Settings persist in /etc/sysctl.conf or /etc/sysctl.d/
- ✅ Changes applied with sysctl --system or sysctl -p
- ✅ Values verified in /proc/sys/ filesystem

---

### Question 2: Create and Configure PersistentVolume
**Scenario**: Create a PersistentVolume for a database that requires specific storage requirements.

**Requirements**:
- PV name: `db-pv`
- Storage capacity: `10Gi`
- Access modes: `ReadWriteOnce`
- Host path: `/mnt/data/db`
- Reclaim policy: `Retain`

**Answer**:
```bash
cat > db-pv.yaml << EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: db-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /mnt/data/db
EOF

kubectl apply -f db-pv.yaml
```

**Verification**:
```bash
kubectl get pv db-pv
kubectl describe pv db-pv
```

---

### Question 3: Create PVC and Mount to Pod
**Scenario**: Create a PersistentVolumeClaim and mount it to a pod.

**Requirements**:
- PVC name: `db-pvc`
- Namespace: `default`
- Storage request: `5Gi`
- Access mode: `ReadWriteOnce`
- Pod name: `db-app`
- Image: `mysql`
- Mount path: `/var/lib/mysql`

**Answer**:
```bash
# Create PVC
cat > db-pvc.yaml << EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: db-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
EOF

kubectl apply -f db-pvc.yaml

# Create Pod with PVC
cat > db-app.yaml << EOF
apiVersion: v1
kind: Pod
metadata:
  name: db-app
  namespace: default
spec:
  containers:
  - name: mysql
    image: mysql
    env:
    - name: MYSQL_ROOT_PASSWORD
      value: password
    volumeMounts:
    - name: db-storage
      mountPath: /var/lib/mysql
  volumes:
  - name: db-storage
    persistentVolumeClaim:
      claimName: db-pvc
EOF

kubectl apply -f db-app.yaml
```

**Verification**:
```bash
kubectl get pvc db-pvc
kubectl get pod db-app
kubectl describe pod db-app | grep -A 5 "Volumes:"
```

---

### Question 4: Resource Quotas and Limits
**Scenario**: Set resource quotas for a development namespace.

**Requirements**:
- Namespace: `dev-team`
- Create ResourceQuota with:
  - CPU requests: `10`
  - CPU limits: `20`
  - Memory requests: `20Gi`
  - Memory limits: `40Gi`
  - Pods: `10`
  - Services: `5`

**Answer**:
```bash
# Create namespace
kubectl create namespace dev-team

# Create ResourceQuota
cat > dev-quota.yaml << EOF
apiVersion: v1
kind: ResourceQuota
metadata:
  name: dev-team-quota
  namespace: dev-team
spec:
  hard:
    requests.cpu: "10"
    requests.memory: 20Gi
    limits.cpu: "20"
    limits.memory: 40Gi
    pods: "10"
    services: "5"
EOF

kubectl apply -f dev-quota.yaml
```

**Verification**:
```bash
kubectl get resourcequota dev-team-quota -n dev-team
kubectl describe resourcequota dev-team-quota -n dev-team
```

---

### Question 5: LimitRange for Namespace
**Scenario**: Configure default resource limits for containers in a namespace.

**Requirements**:
- Namespace: `dev-team`
- LimitRange name: `dev-limits`
- Default CPU limit: `500m`
- Default CPU request: `100m`
- Default memory limit: `512Mi`
- Default memory request: `128Mi`
- Max CPU: `1`
- Max memory: `1Gi`

**Answer**:
```bash
cat > dev-limits.yaml << EOF
apiVersion: v1
kind: LimitRange
metadata:
  name: dev-limits
  namespace: dev-team
spec:
  limits:
  - default:
      cpu: 500m
      memory: 512Mi
    defaultRequest:
      cpu: 100m
      memory: 128Mi
    max:
      cpu: "1"
      memory: 1Gi
    type: Container
EOF

kubectl apply -f dev-limits.yaml
```

**Verification**:
```bash
kubectl get limitrange dev-limits -n dev-team
kubectl describe limitrange dev-limits -n dev-team
```

---

### Question 6: Pod Affinity - Run Pods on Same Node
**Scenario**: Ensure two pods run on the same node using pod affinity.

**Requirements**:
- Pod 1: `web-server` with label `app: web`
- Pod 2: `cache-server` must run on same node as `web-server`
- Use `podAffinity` with `requiredDuringSchedulingIgnoredDuringExecution`

**Answer**:
```bash
# Create first pod
kubectl run web-server --image=nginx --labels="app=web"

# Create second pod with affinity
cat > cache-server.yaml << EOF
apiVersion: v1
kind: Pod
metadata:
  name: cache-server
spec:
  affinity:
    podAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values:
            - web
        topologyKey: kubernetes.io/hostname
  containers:
  - name: cache
    image: redis
EOF

kubectl apply -f cache-server.yaml
```

**Verification**:
```bash
kubectl get pods -o wide
# Check both pods are on same node
```

---

### Question 7: Pod Anti-Affinity - Spread Pods Across Nodes
**Scenario**: Ensure pods are spread across different nodes using anti-affinity.

**Requirements**:
- Deployment: `api-deployment`
- Replicas: `3`
- Image: `nginx`
- Label: `app: api`
- Anti-affinity: Pods should not run on same node

**Answer**:
```bash
cat > api-deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - api
              topologyKey: kubernetes.io/hostname
      containers:
      - name: api
        image: nginx
EOF

kubectl apply -f api-deployment.yaml
```

**Verification**:
```bash
kubectl get pods -o wide -l app=api
# Check pods are on different nodes
```

---

### Question 8: Node Selector
**Scenario**: Schedule a pod on a specific node type.

**Requirements**:
- Pod name: `gpu-worker`
- Image: `cuda:latest`
- Node label: `hardware-type: gpu`
- Node name: `node02`

**Answer**:
```bash
# First, label the node
kubectl label node node02 hardware-type=gpu

# Create pod with nodeSelector
cat > gpu-worker.yaml << EOF
apiVersion: v1
kind: Pod
metadata:
  name: gpu-worker
spec:
  nodeSelector:
    hardware-type: gpu
  containers:
  - name: gpu-container
    image: cuda:latest
EOF

kubectl apply -f gpu-worker.yaml
```

**Verification**:
```bash
kubectl get pod gpu-worker -o wide
# Should show node02
kubectl describe pod gpu-worker | grep -i "node"
```

---

### Question 9: Taints and Tolerations
**Scenario**: Reserve a node for specific workloads using taints and tolerations.

**Requirements**:
- Node: `node01`
- Taint: `dedicated=special-user:NoSchedule`
- Pod: `special-app` with toleration to run on tainted node

**Answer**:
```bash
# Add taint to node
kubectl taint node node01 dedicated=special-user:NoSchedule

# Create pod with toleration
cat > special-app.yaml << EOF
apiVersion: v1
kind: Pod
metadata:
  name: special-app
spec:
  tolerations:
  - key: dedicated
    operator: Equal
    value: special-user
    effect: NoSchedule
  containers:
  - name: app
    image: nginx
EOF

kubectl apply -f special-app.yaml
```

**Verification**:
```bash
kubectl describe node node01 | grep -i taint
kubectl get pod special-app -o wide
```

---

### Question 10: Backup and Restore etcd
**Scenario**: Backup etcd data and restore it.

**Requirements**:
- Backup etcd snapshot to `/opt/etcd-backup.db`
- Use etcdctl with proper certificates
- etcd endpoint: `https://127.0.0.1:2379`

**Answer**:
```bash
# Backup etcd
ETCDCTL_API=3 etcdctl snapshot save /opt/etcd-backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Verify backup
ETCDCTL_API=3 etcdctl snapshot status /opt/etcd-backup.db
```

**Restore** (on different node or after disaster):
```bash
# Stop kube-apiserver and etcd
sudo systemctl stop kube-apiserver
sudo systemctl stop etcd

# Restore from snapshot
ETCDCTL_API=3 etcdctl snapshot restore /opt/etcd-backup.db \
  --data-dir=/var/lib/etcd-restored

# Update etcd to use new data directory
# Edit /etc/kubernetes/manifests/etcd.yaml
# Change hostPath to /var/lib/etcd-restored

# Start services
sudo systemctl start etcd
sudo systemctl start kube-apiserver
```

**Verification**:
```bash
ls -lh /opt/etcd-backup.db
ETCDCTL_API=3 etcdctl snapshot status /opt/etcd-backup.db
```

---

### Question 11: Kubelet Troubleshooting
**Scenario**: A worker node is in NotReady state. Troubleshoot and fix the kubelet.

**Answer**:
```bash
# Check node status
kubectl get nodes

# SSH to the problematic node
ssh node01

# Check kubelet status
sudo systemctl status kubelet

# Check kubelet logs
sudo journalctl -u kubelet -n 100

# Common fixes:
# 1. Check kubelet configuration
sudo cat /var/lib/kubelet/config.yaml | grep -E "cgroupDriver|containerRuntimeEndpoint"

# 2. Restart kubelet
sudo systemctl restart kubelet

# 3. Check if certificates are valid
sudo openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -noout -dates

# 4. Check disk space (kubelet requires >15% free)
df -h

# 5. Check if node is under memory pressure
kubectl describe node node01 | grep -A 5 "Conditions"
```

---

### Question 12: Upgrade Kubernetes Cluster
**Scenario**: Upgrade a Kubernetes cluster from v1.28 to v1.29.

**Requirements**:
- Upgrade control plane first
- Drain and upgrade worker nodes
- Maintain cluster availability

**Answer**:
```bash
# Step 1: Check current version
kubectl version

# Step 2: Upgrade kubeadm (on control plane)
sudo apt-mark unhold kubeadm
sudo apt-get update
sudo apt-get install -y kubeadm=1.29.x-00
sudo apt-mark hold kubeadm

# Step 3: Plan the upgrade
sudo kubeadm upgrade plan

# Step 4: Apply upgrade
sudo kubeadm upgrade apply v1.29.x

# Step 5: Upgrade kubelet and kubectl
sudo apt-mark unhold kubelet kubectl
sudo apt-get update
sudo apt-get install -y kubelet=1.29.x-00 kubectl=1.29.x-00
sudo apt-mark hold kubelet kubectl

# Step 6: Restart kubelet
sudo systemctl restart kubelet

# Step 7: Upgrade worker nodes (on each node)
kubectl drain node01 --ignore-daemonsets

# On node01:
sudo apt-mark unhold kubeadm kubelet kubectl
sudo apt-get update
sudo apt-get install -y kubeadm=1.29.x-00 kubelet=1.29.x-00 kubectl=1.29.x-00
sudo apt-mark hold kubeadm kubelet kubectl
sudo systemctl restart kubelet

# On control plane:
kubectl uncordon node01
```

---

### Question 13: Multi-Container Pod with Init Container
**Scenario**: Create a pod with an init container that prepares data before the main container starts.

**Requirements**:
- Pod name: `web-init`
- Init container: `data-init` with image `busybox` that creates `/data/index.html`
- Main container: `nginx` with image `nginx` mounting `/data` to `/usr/share/nginx/html`
- Shared volume: `shared-data` (emptyDir)

**Answer**:
```bash
cat > web-init.yaml << EOF
apiVersion: v1
kind: Pod
metadata:
  name: web-init
spec:
  initContainers:
  - name: data-init
    image: busybox
    command: ['sh', '-c', 'echo "<h1>Hello from Init Container</h1>" > /data/index.html']
    volumeMounts:
    - name: shared-data
      mountPath: /data
  containers:
  - name: nginx
    image: nginx
    ports:
    - containerPort: 80
    volumeMounts:
    - name: shared-data
      mountPath: /usr/share/nginx/html
  volumes:
  - name: shared-data
    emptyDir: {}
EOF

kubectl apply -f web-init.yaml
```

**Verification**:
```bash
kubectl get pod web-init
kubectl logs web-init -c data-init
kubectl exec web-init -c nginx -- cat /usr/share/nginx/html/index.html
curl http://<pod-ip>:80
```

---

### Question 14: Deployments - Rolling Update and Rollback
**Scenario**: Perform a rolling update and rollback of a deployment.

**Requirements**:
- Deployment: `frontend-app`
- Current image: `nginx:1.19`
- Update to: `nginx:1.20`
- Rollback if needed

**Answer**:
```bash
# Check current deployment
kubectl get deployment frontend-app
kubectl describe deployment frontend-app | grep Image

# Update image (rolling update)
kubectl set image deployment/frontend-app nginx=nginx:1.20

# Watch rollout status
kubectl rollout status deployment/frontend-app

# Check rollout history
kubectl rollout history deployment/frontend-app

# Rollback if needed
kubectl rollout undo deployment/frontend-app

# Or rollback to specific revision
kubectl rollout undo deployment/frontend-app --to-revision=2
```

**Verification**:
```bash
kubectl get deployment frontend-app
kubectl describe deployment frontend-app | grep Image
kubectl get pods -l app=frontend-app
```

---

### Question 15: CronJob for Scheduled Tasks
**Scenario**: Create a CronJob that runs a backup task every hour.

**Requirements**:
- CronJob name: `hourly-backup`
- Schedule: Every hour (`0 * * * *`)
- Image: `busybox`
- Command: `echo "Backup started at $(date)"`
- Keep last 3 successful jobs
- Keep last 1 failed job

**Answer**:
```bash
cat > hourly-backup.yaml << EOF
apiVersion: batch/v1
kind: CronJob
metadata:
  name: hourly-backup
spec:
  schedule: "0 * * * *"
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: busybox
            command: ["sh", "-c", 'echo "Backup started at $(date)"']
          restartPolicy: OnFailure
EOF

kubectl apply -f hourly-backup.yaml
```

**Verification**:
```bash
kubectl get cronjob hourly-backup
kubectl describe cronjob hourly-backup

# Trigger manual run
kubectl create job --from=cronjob/hourly-backup manual-backup-001

# Check jobs
kubectl get jobs
kubectl logs job/manual-backup-001
```

---

### Question 16: Taints and Tolerations - Dev vs Prod Workloads
**Scenario**: Separate development and production workloads using taints and tolerations.

**Requirements**:
1. Taint worker node `node01` with:
   - Key: `env_type`
   - Value: `production`
   - Effect: `NoSchedule`
2. Create pod `dev-redis` with image `redis:alpine` (no tolerations)
   - Should NOT be scheduled on node01
3. Create pod `prod-redis` with image `redis:alpine` with toleration:
   - Key: `env_type`
   - Value: `production`
   - Operator: `Equal`
   - Effect: `NoSchedule`
   - Should be scheduled on node01

**Answer**:

**Step 1: Taint node01**
```bash
kubectl taint node node01 env_type=production:NoSchedule
```

**Step 2: Create dev-redis pod (no tolerations)**
```bash
kubectl run dev-redis --image=redis:alpine
```

**Step 3: Create prod-redis pod with toleration**
```bash
cat > prod-redis.yaml << EOF
apiVersion: v1
kind: Pod
metadata:
  name: prod-redis
spec:
  tolerations:
  - key: env_type
    operator: Equal
    value: production
    effect: NoSchedule
  containers:
  - name: redis
    image: redis:alpine
EOF

kubectl apply -f prod-redis.yaml
```

**Verification Commands**:
```bash
# Check node taint
kubectl describe node node01 | grep -i taint
# Should show: env_type=production:NoSchedule

# dev-redis should NOT be on node01 (no tolerations)
kubectl get pod dev-redis -o wide
# Should show: Running on controlplane or other node (not node01)

# prod-redis SHOULD be on node01 (has toleration)
kubectl get pod prod-redis -o wide
# Should show: Running on node01

# Verify toleration in prod-redis
kubectl get pod prod-redis -o yaml | grep -A 4 tolerations
```

**Key Concepts**:
- **NoSchedule**: Pods without toleration won't be scheduled on tainted node
- **Existing pods** are not evicted (unlike NoExecute)
- **Toleration must match** key, value, and effect exactly (when operator=Equal)
- **Use case**: Reserve nodes for specific workloads (production, GPU, etc.)

**Verification Checklist**:
- ✅ node01 has taint env_type=production:NoSchedule
- ✅ dev-redis pod is NOT scheduled on node01 (no tolerations)
- ✅ dev-redis is running on different node (e.g., controlplane)
- ✅ prod-redis pod IS scheduled on node01 (has matching toleration)
- ✅ prod-redis has correct toleration configuration

---

### Question 17: Troubleshoot PVC/PV Binding
**Scenario**: A PVC is not binding to an available PV. Identify and fix the issue.

**Given**:
- PVC: `app-pvc` in namespace `storage-ns` (Status: Pending)
- PV: `app-pv` (Status: Available)
- Do NOT modify the PV resource

**PV Details**:
- Capacity: 1Gi
- Access Modes: RWO
- No StorageClass

**Task**: Fix the PVC so it binds to the PV.

**Answer**:

**Step 1: Inspect the resources**
```bash
kubectl get pvc app-pvc -n storage-ns
kubectl get pv app-pv
kubectl describe pvc app-pvc -n storage-ns
```

**Step 2: Check for binding issues**

Common issues:
1. PVC storage request doesn't match PV capacity
2. PVC access mode doesn't match PV
3. PVC StorageClass doesn't match PV (or PV has no StorageClass)
4. PV already bound to another PVC

**Step 3: Fix the PVC**

The PVC must match:
- Capacity: 1Gi (equal to or less than PV)
- AccessMode: ReadWriteOnce (matching PV)
- storageClassName: "" (empty string to match PV with no StorageClass)

```bash
# Edit the PVC to match PV specs
kubectl patch pvc app-pvc -n storage-ns --type merge -p '
{
  "spec": {
    "accessModes": ["ReadWriteOnce"],
    "resources": {"requests": {"storage": "1Gi"}},
    "storageClassName": ""
  }
}'

# Or use kubectl edit
kubectl edit pvc app-pvc -n storage-ns
```

Add/modify in spec:
```yaml
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: ""  # Important: match PV with no StorageClass
```

**Step 4: Verify binding**
```bash
kubectl get pvc app-pvc -n storage-ns
kubectl get pv app-pv
```

**Key Troubleshooting Tips**:
- PVC storage request can be ≤ PV capacity
- Access modes must match exactly
- If PV has no StorageClass, PVC must have `storageClassName: ""`
- If PV has a StorageClass, PVC must match it or use same/default SC
- Check `kubectl describe pvc` for Events section showing binding errors

**Verification Commands**:
```bash
# Check PVC is bound
kubectl get pvc app-pvc -n storage-ns
# Should show: STATUS=Bound, VOLUME=app-pv

# Check PV shows claim
kubectl get pv app-pv
# Should show: STATUS=Bound, CLAIM=storage-ns/app-pvc

# Verify details
kubectl describe pvc app-pvc -n storage-ns | grep -A 3 "Used By"
kubectl describe pv app-pv | grep -A 3 "Claim"
```

**Verification Checklist**:
- ✅ PVC app-pvc shows STATUS: Bound
- ✅ PV app-pv shows STATUS: Bound
- ✅ PV shows CLAIM: storage-ns/app-pvc
- ✅ PVC specs match PV specs (capacity, access mode, storage class)
- ✅ No modification to PV resource

---

### Question 18: Troubleshoot Kubeconfig
**Scenario**: A kubeconfig file has configuration issues preventing cluster access.

**Given**:
- Kubeconfig file: `/root/CKA/super.kubeconfig`
- Cannot connect to cluster using this config

**Common Issues to Check**:
1. Wrong API server port (should be 6443, not 9999)
2. certificate-authority vs certificate-authority-data
3. Missing or incorrect current-context
4. Malformed YAML structure
5. Wrong user credentials

**Answer**:

**Step 1: View the kubeconfig**
```bash
cat /root/CKA/super.kubeconfig
kubectl config view --kubeconfig=/root/CKA/super.kubeconfig
```

**Step 2: Identify and fix common issues**

**Issue 1: Wrong server port**
```bash
# Fix server URL (common mistake: using :9999 instead of :6443)
kubectl config set-cluster kubernetes \
  --server=https://controlplane:6443 \
  --kubeconfig=/root/CKA/super.kubeconfig
```

**Issue 2: Fix certificate paths**
```bash
# If using certificate files instead of embedded data
kubectl config set-cluster kubernetes \
  --certificate-authority=/etc/kubernetes/pki/ca.crt \
  --embed-certs=true \
  --kubeconfig=/root/CKA/super.kubeconfig
```

**Issue 3: Set correct context**
```bash
# Set current context if missing
kubectl config use-context kubernetes-admin@kubernetes \
  --kubeconfig=/root/CKA/super.kubeconfig

# Or create context if it doesn't exist
kubectl config set-context kubernetes-admin@kubernetes \
  --cluster=kubernetes \
  --user=kubernetes-admin \
  --kubeconfig=/root/CKA/super.kubeconfig
```

**Issue 4: Fix user credentials**
```bash
# Set user with correct certificates
kubectl config set-credentials kubernetes-admin \
  --client-certificate=/etc/kubernetes/pki/apiserver-kubelet-client.crt \
  --client-key=/etc/kubernetes/pki/apiserver-kubelet-client.key \
  --embed-certs=true \
  --kubeconfig=/root/CKA/super.kubeconfig
```

**Step 3: Validate the fixed config**
```bash
# Test connection
kubectl cluster-info --kubeconfig=/root/CKA/super.kubeconfig

# Get nodes
kubectl get nodes --kubeconfig=/root/CKA/super.kubeconfig
```

**Complete Fix Example**:
```bash
# If the config is completely broken, recreate it properly
cat > /root/CKA/super.kubeconfig << EOF
apiVersion: v1
clusters:
- cluster:
    certificate-authority: /etc/kubernetes/pki/ca.crt
    server: https://controlplane:6443
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: kubernetes-admin
  name: kubernetes-admin@kubernetes
current-context: kubernetes-admin@kubernetes
kind: Config
users:
- name: kubernetes-admin
  user:
    client-certificate: /etc/kubernetes/pki/apiserver-kubelet-client.crt
    client-key: /etc/kubernetes/pki/apiserver-kubelet-client.key
EOF
```

**Verification Commands**:
```bash
# Check config is valid YAML
kubectl config view --kubeconfig=/root/CKA/super.kubeconfig

# Verify current context
kubectl config current-context --kubeconfig=/root/CKA/super.kubeconfig

# Test cluster connection
kubectl get nodes --kubeconfig=/root/CKA/super.kubeconfig

# Check all contexts
kubectl config get-contexts --kubeconfig=/root/CKA/super.kubeconfig
```

**Key Troubleshooting Tips**:
- **Port 6443**: Default Kubernetes API server port (not 8080 or 9999)
- **Certificate paths**: Must be absolute paths or use `--embed-certs`
- **Current context**: Must be set or specify `--context` flag
- **YAML syntax**: Check for indentation errors (use 2 spaces)
- **Permissions**: Ensure cert files are readable

**Common CKA Kubeconfig Issues**:
1. Server URL pointing to wrong port
2. Missing `current-context` field
3. Certificate data vs certificate file path confusion
4. Context name mismatch
5. User credentials not matching cluster CA

**Verification Checklist**:
- ✅ Kubeconfig file is valid YAML
- ✅ Server URL uses correct port (6443)
- ✅ Current context is set
- ✅ Cluster CA certificate is valid
- ✅ User client certificates are valid
- ✅ Can connect to cluster with the config

---

### Question 19: HPA with Custom Metric
**Scenario**: Create a Horizontal Pod Autoscaler that scales based on a custom metric.

**Requirements**:
- HPA name: `api-hpa`
- Namespace: `api`
- Target deployment: `api-deployment`
- Metric: `requests_per_second`
- Target type: `AverageValue` of 1000
- Min replicas: 1
- Max replicas: 20

**Answer**:
```bash
cat > api-hpa.yaml << EOF
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-hpa
  namespace: api
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api-deployment
  minReplicas: 1
  maxReplicas: 20
  metrics:
  - type: Pods
    pods:
      metric:
        name: requests_per_second
      target:
        type: AverageValue
        averageValue: "1000"
EOF

kubectl apply -f api-hpa.yaml
```

**Verification**:
```bash
kubectl get hpa api-hpa -n api
kubectl describe hpa api-hpa -n api
kubectl get hpa api-hpa -n api -o yaml | grep -A 10 "metrics:"
```

---

### Question 20: HTTPRoute Traffic Splitting
**Scenario**: Configure traffic splitting between two services using Gateway API HTTPRoute.

**Requirements**:
- HTTPRoute name: `web-route`
- Gateway: `web-gateway`
- Traffic split:
  - 80% to `web-service`
  - 20% to `web-service-v2`
- Port: 80

**Answer**:
```bash
cat > web-route.yaml << EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: web-route
spec:
  parentRefs:
  - name: web-gateway
  rules:
  - backendRefs:
    - name: web-service
      port: 80
      weight: 80
    - name: web-service-v2
      port: 80
      weight: 20
EOF

kubectl apply -f web-route.yaml
```

**Verification**:
```bash
kubectl get httproute web-route
kubectl describe httproute web-route
kubectl get httproute web-route -o yaml | grep -A 5 "backendRefs:"
```

---

### Question 21: Helm Chart Upgrade and Release Management
**Scenario**: Upgrade an application using Helm by installing a new version and removing the old release.

**Requirements**:
- Old release: `webpage-server-01` (already deployed)
- New chart location: `/root/new-version`
- New release name: `webpage-server-02`
- Steps: Validate chart → Install new → Uninstall old

**Answer**:
```bash
# Step 1: Validate the new Helm chart
helm lint /root/new-version

# Step 2: Install as new release webpage-server-02
helm install webpage-server-02 /root/new-version

# Step 3: Verify new release is installed
helm list
helm status webpage-server-02
kubectl get pods | grep webpage-server-02

# Step 4: Uninstall old release
helm uninstall webpage-server-01

# Step 5: Verify old release is gone
helm list | grep webpage-server-01
```

**Verification**:
```bash
# Check new release exists
helm list | grep webpage-server-02
kubectl get pods | grep webpage-server-02

# Check old release is removed
helm list | grep webpage-server-01  # Should return nothing
kubectl get pods | grep webpage-server-01  # Should return nothing
```

---

### Question 22: Get Cluster Pod CIDR from Kubeadm Config
**Scenario**: Identify the cluster-wide Pod network CIDR from kubeadm configuration.

**Requirements**:
- Source: `kubeadm-config` ConfigMap in `kube-system` namespace
- Field: `podSubnet` under `ClusterConfiguration`
- Output file: `/root/pod-cidr.txt`
- Format: `x.x.x.x/x`

**Note**: Use cluster-wide podSubnet, NOT per-node CIDR from `kubectl get node`

**Answer**:
```bash
# Method 1: Extract from ClusterConfiguration
cat > /root/pod-cidr.txt << EOF
$(kubectl get configmap kubeadm-config -n kube-system -o jsonpath='{.data.ClusterConfiguration}' | grep podSubnet | awk '{print $2}')
EOF

# Method 2: Direct extraction
echo "$(kubectl get cm kubeadm-config -n kube-system -o jsonpath='{.data.ClusterConfiguration}' | grep podSubnet | sed 's/.*podSubnet: //')" > /root/pod-cidr.txt

# Method 3: Using grep and sed
kubectl get configmap kubeadm-config -n kube-system -o yaml | grep podSubnet | head -1 | sed 's/.*podSubnet: //' > /root/pod-cidr.txt
```

**Verification**:
```bash
cat /root/pod-cidr.txt
# Should show: 10.244.0.0/16 (or your cluster's pod CIDR)

# Verify against kubeadm-config
kubectl get cm kubeadm-config -n kube-system -o yaml | grep podSubnet
```

**Why Cluster-wide CIDR matters**:
- Used by CNI plugins (Calico, Weave, Flannel)
- Defines IP range for all pods across the cluster
- Different from per-node podCIDRs assigned by controller-manager

---

*Good luck with your practice!*
