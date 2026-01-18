# CoreDNS & Kubernetes Networking: Complete Guide with Real-World Examples

---

## **What is CoreDNS?**

CoreDNS is the **DNS server** that runs inside your Kubernetes cluster. It acts as a "phone book" that translates service names into IP addresses so pods can find each other.

**Real-world analogy:** Instead of remembering that your database is at `10.244.5.23:5432`, you just call it `postgres-service` and CoreDNS handles the translation.

---

## **How CoreDNS Works**

### **Architecture Overview**

```
Pod wants to connect to "my-api-service"
         ↓
Pod queries CoreDNS at 10.96.0.10:53
         ↓
CoreDNS checks Kubernetes API for service info
         ↓
Returns IP: 10.96.5.100
         ↓
Pod connects to 10.96.5.100
         ↓
kube-proxy routes to actual pod at 10.244.2.15
```

### **Key Components**

| Component | Purpose | Port |
|-----------|---------|------|
| **CoreDNS Deployment** | Runs 2+ DNS server pods for HA | - |
| **kube-dns Service** | ClusterIP that pods use for DNS | 53 |
| **CoreDNS ConfigMap** | Configuration (Corefile) | - |
| **ServiceAccount/RBAC** | Permissions to read Services/Endpoints | - |

---

## **CoreDNS Configuration (Corefile)**

```yaml
# Handles internal cluster domains
kubernetes cluster.local in-addr.arpa ip6.arpa {
   pods insecure              # Allow pod DNS records
   fallthrough in-addr.arpa   # Pass reverse lookups through
   ttl 30                     # Cache for 30 seconds
}

# Forward external queries
forward . /etc/resolv.conf    # Use node's DNS for google.com, etc.

# Other plugins
prometheus :9153              # Metrics endpoint
ready :8181                   # Health check endpoint
cache 30                      # Cache responses for 30s
loop                          # Detect DNS loops
reload                        # Auto-reload on config changes
loadbalance                   # Round-robin between endpoints
```

---

## **Common CoreDNS Errors & Real-World Scenarios**

---

### **Error 1: DNS Loop Detection**

#### **What You See:**
```bash
$ kubectl get pods -n kube-system
NAME                      READY   STATUS             RESTARTS   AGE
coredns-xxx               0/1     CrashLoopBackOff   5          3m

$ kubectl logs coredns-xxx -n kube-system
[FATAL] plugin/loop: Loop (127.0.0.1:56162 -> :53) detected for zone "."
Query: "HINFO 7087784449798295848.7359092265978106814."
```

#### **Real-World Scenario:**
**Company:** E-commerce startup deploying on Ubuntu 22.04 servers

**What happened:**
- DevOps engineer set up a new Kubernetes cluster
- Used Ubuntu's default DNS setup (systemd-resolved)
- Node's `/etc/resolv.conf` pointed to `127.0.0.53` (localhost)
- CoreDNS forwarded external queries to `127.0.0.53`
- systemd-resolved forwarded back to CoreDNS → **LOOP!**

#### **Root Cause:**
```bash
# On the node:
$ cat /etc/resolv.conf
nameserver 127.0.0.53  # ← Problem: localhost reference
options edns0 trust-ad
search .
```

CoreDNS uses this file to forward queries for `google.com`, but `127.0.0.53` creates a circular reference.

#### **The Fix:**
```bash
# Edit kubelet config on each node
sudo vi /var/lib/kubelet/config.yaml

# Add this line:
resolvConf: /run/systemd/resolve/resolv.conf

# Restart kubelet
sudo systemctl restart kubelet

# Restart CoreDNS
kubectl rollout restart deployment coredns -n kube-system
```

#### **Alternative Quick Fix (for testing):**
```bash
kubectl edit configmap coredns -n kube-system

# Change:
forward . /etc/resolv.conf
# To:
forward . 8.8.8.8 1.1.1.1
```

**Impact:** All pods lost DNS resolution for 15 minutes during troubleshooting. API calls to external services failed.

---

### **Error 2: Cannot Reach Kubernetes API**

#### **What You See:**
```bash
$ kubectl logs coredns-xxx -n kube-system
[INFO] plugin/kubernetes: waiting for Kubernetes API before starting server
[INFO] plugin/ready: Still waiting on: "kubernetes"
[ERROR] plugin/kubernetes: Unhandled Error
failed to list *v1.Service: Get "https://10.96.0.1:443/api/v1/services": 
dial tcp 10.96.0.1:443: i/o timeout
```

#### **Real-World Scenario:**
**Company:** FinTech company migrating from EKS to bare-metal Kubernetes

**What happened:**
- Infrastructure team installed Kubernetes with `kubeadm`
- Forgot to install a CNI plugin (Calico/Flannel)
- Pods had IPs but couldn't communicate across nodes
- CoreDNS couldn't reach the API server's Service IP

#### **Root Cause:**
```bash
# No CNI plugin installed
$ kubectl get pods -n kube-system | grep -E 'calico|flannel|weave'
# (nothing shows up)

$ kubectl get nodes
NAME     STATUS     ROLES           AGE   VERSION
node-1   NotReady   control-plane   10m   v1.28.0
node-2   NotReady   <none>          10m   v1.28.0
```

Nodes show `NotReady` because there's no network overlay.

#### **The Fix:**
```bash
# Install Calico
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml

# Wait for CNI pods to start
kubectl get pods -n kube-system -w

# Nodes become Ready
$ kubectl get nodes
NAME     STATUS   ROLES           AGE   VERSION
node-1   Ready    control-plane   15m   v1.28.0
node-2   Ready    <none>          15m   v1.28.0
```

**Impact:** Entire cluster was non-functional for 2 hours. No service-to-service communication worked.

---

### **Error 3: CrashLoopBackOff (SELinux)**

#### **What You See:**
```bash
$ kubectl get pods -n kube-system
NAME                      READY   STATUS             RESTARTS   AGE
coredns-xxx               0/1     CrashLoopBackOff   8          10m

$ kubectl logs coredns-xxx -n kube-system
Error: open /etc/coredns/Corefile: permission denied
```

#### **Real-World Scenario:**
**Company:** Government contractor on RHEL 8 with SELinux enforcing

**What happened:**
- Security requirements mandated SELinux in enforcing mode
- CoreDNS couldn't read its config file due to SELinux policies
- Running older Docker version that didn't handle SELinux labels properly

#### **Root Cause:**
```bash
# Check SELinux status
$ getenforce
Enforcing

# CoreDNS security context conflicts with SELinux
$ kubectl get pod coredns-xxx -n kube-system -o yaml | grep -A5 securityContext
securityContext:
  allowPrivilegeEscalation: false  # ← Too restrictive for SELinux
  capabilities:
    add:
    - NET_BIND_SERVICE
```

#### **The Fix:**
```bash
# Option 1: Allow privilege escalation
kubectl -n kube-system get deployment coredns -o yaml | \
  sed 's/allowPrivilegeEscalation: false/allowPrivilegeEscalation: true/g' | \
  kubectl apply -f -

# Option 2: Update Docker (recommended)
sudo yum update docker-ce
sudo systemctl restart docker kubelet
```

**Impact:** DNS outage during business hours. Incident report filed with customer.

---

### **Error 4: No Endpoints for kube-dns Service**

#### **What You See:**
```bash
$ kubectl get svc kube-dns -n kube-system
NAME       TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)         AGE
kube-dns   ClusterIP   10.96.0.10   <none>        53/UDP,53/TCP   5d

$ kubectl get endpoints kube-dns -n kube-system
NAME       ENDPOINTS   AGE
kube-dns   <none>      5d  # ← No endpoints!

# DNS queries fail
$ kubectl run test --image=busybox --rm -it -- nslookup kubernetes.default
;; connection timed out; no servers could be reached
```

#### **Real-World Scenario:**
**Company:** SaaS platform doing blue-green deployment

**What happened:**
- DevOps engineer modified CoreDNS deployment selectors during upgrade
- Changed `k8s-app: kube-dns` to `k8s-app: coredns`
- kube-dns Service still looked for old label
- Service couldn't find any pods → no endpoints

#### **Root Cause:**
```bash
# Check service selector
$ kubectl get svc kube-dns -n kube-system -o yaml | grep -A2 selector
selector:
  k8s-app: kube-dns  # Looking for this label

# Check actual pod labels
$ kubectl get pods -n kube-system -l k8s-app=kube-dns
No resources found.  # ← No pods match!

$ kubectl get pods -n kube-system -l k8s-app=coredns
NAME                      READY   STATUS    RESTARTS   AGE
coredns-xxx               1/1     Running   0          2m  # Found with different label
```

#### **The Fix:**
```bash
# Edit the CoreDNS deployment to restore correct labels
kubectl edit deployment coredns -n kube-system

# Ensure these labels exist:
metadata:
  labels:
    k8s-app: kube-dns  # ← Critical!
spec:
  template:
    metadata:
      labels:
        k8s-app: kube-dns

# Verify endpoints appear
$ kubectl get ep kube-dns -n kube-system
NAME       ENDPOINTS                     AGE
kube-dns   10.244.0.5:53,10.244.0.6:53   5d
```

**Impact:** 45-minute DNS outage affecting production traffic. Customer complaints about "service unavailable" errors.

---

### **Error 5: Transient Startup Timeouts**

#### **What You See:**
```bash
$ kubectl logs coredns-xxx -n kube-system
[INFO] plugin/kubernetes: waiting for Kubernetes API before starting server
[INFO] plugin/ready: Still waiting on: "kubernetes"
[ERROR] plugin/kubernetes: dial tcp 10.96.0.1:443: i/o timeout
[WARNING] plugin/kubernetes: starting server with unsynced Kubernetes API
.:53
CoreDNS-1.12.1
[INFO] plugin/ready: Still waiting on: "kubernetes"
# ... then errors stop and it works fine
```

#### **Real-World Scenario:**
**Company:** Developer's minikube cluster

**What happened:**
- Minikube cluster restarted (after Docker Desktop update)
- During pod startup, brief race condition:
  1. CoreDNS pod starts
  2. CNI hasn't finished configuring network routes
  3. CoreDNS can't reach API for ~30 seconds
  4. Network stabilizes, everything works

#### **Root Cause:**
**This is actually NORMAL startup behavior!**

```bash
# Check pod status - it's running fine now
$ kubectl get pods -n kube-system
NAME                      READY   STATUS    RESTARTS      AGE
coredns-xxx               1/1     Running   4 (19h ago)   83d
                          ↑ Running fine!   ↑ Old restarts
```

The errors were logged during the restart event 19 hours ago, not currently happening.

#### **Verification:**
```bash
# Check for RECENT errors (none = it's fine)
$ kubectl logs coredns-xxx -n kube-system --since=1h | grep ERROR
# (no output = no recent errors)

# Test DNS works
$ kubectl run test-dns --image=busybox:1.28 --rm -it -- nslookup kubernetes.default
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local
Name:      kubernetes.default
Address 1: 10.96.0.1 kubernetes.default.svc.cluster.local
# ✅ Works perfectly!
```

#### **When to Worry:**
- ❌ Errors persist for **> 2 minutes** after pod start
- ❌ Pod never reaches `Running` state
- ❌ DNS queries actually fail

#### **When NOT to Worry:**
- ✅ Errors only during pod startup (first 30-60 seconds)
- ✅ Pod is `Running` with `1/1` ready
- ✅ DNS queries work fine

**Impact:** None! This is expected behavior. The logs just look scary.

---

## **Troubleshooting Workflow**

### **Step 1: Check CoreDNS Pod Status**
```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Possible states:
# Running (1/1)     → ✅ Healthy
# Pending           → CNI not installed
# CrashLoopBackOff  → DNS loop or SELinux issue
# ImagePullBackOff  → Registry problem
```

### **Step 2: Check Recent Logs**
```bash
# Don't look at ALL logs - only recent ones
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=50 --since=10m

# Look for:
# [FATAL] plugin/loop     → DNS loop
# [ERROR] dial tcp timeout → API connectivity issue
# permission denied       → SELinux/RBAC issue
```

### **Step 3: Test DNS Resolution**
```bash
# Test internal DNS
kubectl run test-dns --image=busybox:1.28 --rm -it -- nslookup kubernetes.default

# Test external DNS
kubectl run test-dns --image=busybox:1.28 --rm -it -- nslookup google.com

# If internal works but external fails → check forward config
# If both fail → CoreDNS is broken
```

### **Step 4: Check Service & Endpoints**
```bash
# Verify service exists
kubectl get svc kube-dns -n kube-system

# Check it has endpoints
kubectl get ep kube-dns -n kube-system

# Should show CoreDNS pod IPs:
# ENDPOINTS: 10.244.0.5:53,10.244.0.6:53
```

### **Step 5: Verify Network Plugin**
```bash
# Check CNI is running
kubectl get pods -n kube-system | grep -E 'calico|flannel|weave|cilium'

# Check nodes are Ready
kubectl get nodes

# On node, verify CNI config
ls /etc/cni/net.d/
# Should have .conf or .conflist files
```

### **Step 6: Check kube-proxy**
```bash
# CoreDNS needs kube-proxy to route traffic
kubectl get pods -n kube-system | grep kube-proxy

# Check logs for errors
kubectl logs -n kube-system kube-proxy-xxx
```

---

## **Prevention Best Practices**

### **1. Always Install CNI First**
```bash
# Correct order when building cluster:
kubeadm init                    # 1. Initialize control plane
kubectl apply -f calico.yaml    # 2. Install CNI immediately
kubectl join...                 # 3. Then join nodes
```

### **2. Configure kubelet Before Deploying**
```bash
# Set this BEFORE first boot
# /var/lib/kubelet/config.yaml
resolvConf: /run/systemd/resolve/resolv.conf
```

### **3. Monitor CoreDNS Health**
```bash
# Prometheus metrics
curl http://<coredns-pod-ip>:9153/metrics

# Key metrics:
# coredns_dns_request_count_total
# coredns_dns_request_duration_seconds
# coredns_forward_request_count_total
```

### **4. Set Resource Limits**
```yaml
# CoreDNS can OOM under heavy load
resources:
  requests:
    memory: "170Mi"
    cpu: "100m"
  limits:
    memory: "512Mi"  # Increase for large clusters
    cpu: "500m"
```

### **5. Use Multiple Replicas**
```bash
# For high availability
kubectl scale deployment coredns -n kube-system --replicas=3
```

---

## **Quick Reference: Error → Solution**

| Error Message | Root Cause | Fix |
|---------------|------------|-----|
| `[FATAL] plugin/loop` | DNS loop detected | Configure kubelet `resolvConf` or use `forward . 8.8.8.8` |
| `dial tcp timeout` | Can't reach API | Install CNI plugin |
| `CrashLoopBackOff` | SELinux or permissions | Set `allowPrivilegeEscalation: true` |
| `No endpoints` | Label mismatch | Fix deployment labels to match service selector |
| `Waiting for Kubernetes API` (brief) | Startup race condition | Normal - wait 60 seconds |
| `permission denied` | RBAC or SELinux | Check ServiceAccount and SELinux mode |

---

## **Real-World Lesson: Always Check Timestamps!**

**The most important takeaway:**

```bash
# This looks scary:
[ERROR] plugin/kubernetes: Unhandled Error

# But check when it happened:
RESTARTS: 4 (19h ago)
         ↑ These errors are from 19 hours ago!

# Current status:
READY: 1/1, STATUS: Running
       ↑ It's working fine NOW
```

**Key insight:** Old errors in logs don't mean current problems. Always:
1. Check pod status first (`1/1 Running` = probably fine)
2. Use `--since=1h` to see only recent logs
3. Actually test DNS before assuming it's broken

---

## **kube-proxy Overview**

### **What is kube-proxy?**

kube-proxy is a network proxy that runs on **every node** (as a DaemonSet). It maintains network rules that allow traffic to Services to be routed to the correct pods.

### **How it Works**

```
Client connects to Service IP (10.96.5.100:80)
         ↓
kube-proxy intercepts using iptables/ipvs rules
         ↓
Forwards to actual pod (10.244.2.15:8080)
         ↓
Pod processes request
```

### **Key Components**

```bash
# kube-proxy runs with this config:
/usr/local/bin/kube-proxy --config=/var/lib/kube-proxy/config.conf

# Config includes:
# - clusterCIDR: Pod IP range
# - mode: iptables, ipvs, or userspace
# - bindAddress: What IP to listen on
# - kubeconfig: How to authenticate to API
```

### **Common kube-proxy Issues**

#### **Problem 1: Services Not Accessible**
```bash
# Check if kube-proxy is running
kubectl get pods -n kube-system | grep kube-proxy

# Check logs
kubectl logs -n kube-system kube-proxy-xxx

# Verify it's listening
kubectl exec -n kube-system kube-proxy-xxx -- netstat -plan | grep kube-proxy
# Should see ports like 10249 (metrics) and 10256 (healthz)
```

#### **Problem 2: Wrong ConfigMap**
```bash
# Check the config
kubectl get cm kube-proxy -n kube-system -o yaml

# Verify mode matches your setup
mode: "iptables"  # or "ipvs"
```

#### **Problem 3: iptables Rules Missing**
```bash
# On a node, check if rules exist
sudo iptables-save | grep KUBE-SERVICES

# Should see many rules like:
# -A KUBE-SERVICES -d 10.96.0.10/32 -p tcp -m tcp --dport 53 -j KUBE-SVC-XXX
```

---

## **Summary**

CoreDNS is critical infrastructure that requires:
- ✅ Working CNI plugin
- ✅ Proper `/etc/resolv.conf` configuration
- ✅ Correct RBAC permissions
- ✅ Network connectivity to API server
- ✅ Matching service selectors and labels

kube-proxy is essential for:
- ✅ Service IP to Pod IP translation
- ✅ Load balancing across pod replicas
- ✅ Network rule management

When troubleshooting:
1. Don't panic at old logs
2. Check current pod status
3. Test actual DNS resolution
4. Verify network plugin is running
5. Check timestamps on errors

Most "errors" are actually normal startup behavior - verify with actual DNS tests before declaring an emergency! 🎯