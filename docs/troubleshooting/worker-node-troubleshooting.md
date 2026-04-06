# Worker Node Troubleshooting

When a worker node goes `NotReady`, there is a systematic way to diagnose and fix it. This page covers every command you need — from the control plane down to the node level.

---

## 🔍 Step 1 — Check Node Status (from Control Plane)

Always start here. Never SSH into a node without checking this first.

```bash
# quick overview
kubectl get nodes

# with more detail
kubectl get nodes -o wide
```

**What to look for:**

| Status | Meaning |
|---|---|
| `Ready` | Node is healthy ✅ |
| `NotReady` | Node has a problem ❌ |
| `Unknown` | Node stopped communicating with control plane ⚠️ |

---

## 🔎 Step 2 — Describe the Node

```bash
kubectl describe node <node-name>
```

### Node Conditions to check

```bash
kubectl describe node node01 | grep -A20 Conditions
```

| Condition | Status: True means |
|---|---|
| `OutOfDisk` | No disk space left |
| `MemoryPressure` | Node is low on memory |
| `DiskPressure` | Disk capacity is low |
| `PIDPressure` | Too many processes running |
| `Ready` | Node is fully healthy |

!!! warning "Unknown Status"
    If conditions show `Unknown`, the node stopped sending heartbeats to the control plane. This usually means the node crashed or lost network connectivity.

    ```bash
    # check when the node last communicated
    kubectl describe node node01 | grep -i heartbeat
    ```

---

## 🖥️ Step 3 — Check Node Resources (SSH into Node)

```bash
# SSH into the worker node
ssh node01

# check CPU and memory usage
top

# check memory in human readable format
free -h

# check disk space
df -h

# check running processes
ps aux
```

!!! tip "Resource pressure causes"
    - `MemoryPressure` → `free -h` shows very low available memory
    - `DiskPressure` → `df -h` shows disk at 90%+ usage
    - `PIDPressure` → `ps aux | wc -l` shows too many processes

---

## ⚙️ Step 4 — Check Kubelet Service

Kubelet is the **only** control plane component that runs as a systemd service on worker nodes.

```bash
# is kubelet running?
systemctl status kubelet
```

**Output meanings:**

| Output | Meaning |
|---|---|
| `active (running)` | Kubelet is healthy ✅ |
| `failed` | Kubelet crashed ❌ |
| `activating` | Kubelet is starting up ⏳ |
| `inactive` | Kubelet is stopped ❌ |

### Restart kubelet

```bash
# ALWAYS reload daemon before restart
systemctl daemon-reload
systemctl restart kubelet

# verify it came back
systemctl status kubelet
```

!!! warning "daemon-reload is important"
    Always run `systemctl daemon-reload` before restarting kubelet.
    Without it, systemd uses the old config and your fix won't apply.

---

## 📋 Step 5 — Check Kubelet Logs

```bash
# last 50 lines of kubelet logs
journalctl -u kubelet | tail -50

# live follow logs
journalctl -u kubelet -f

# filter errors only
journalctl -u kubelet | grep -i error

# last 5 minutes of logs
journalctl -u kubelet --since "5m ago"

# search for specific text
journalctl -u kubelet | grep -i "failed"
```

!!! tip "journalctl is only for kubelet"
    `journalctl` only works for systemd services.
    For control plane components (API server, scheduler, etcd),
    use `kubectl logs` or `crictl logs` instead — they are static pods.

---

## 🔐 Step 6 — Check Kubelet Certificates

Expired or misconfigured certificates are a common cause of node failures.

```bash
# check certificate expiry dates
openssl x509 \
  -in /var/lib/kubelet/pki/kubelet-client-current.pem \
  -noout \
  -dates
```

**Output to look for:**
```
notBefore=Apr  1 00:00:00 2024 GMT
notAfter=Apr  1 00:00:00 2025 GMT   ← check this is in the future
```

```bash
# check certificate details (issuer, subject, group)
openssl x509 \
  -in /var/lib/kubelet/pki/kubelet-client-current.pem \
  -noout \
  -text | grep -A5 Subject
```

**Certificate checklist:**

| Check | Expected value |
|---|---|
| Not expired | `notAfter` date is in the future |
| Correct group | `Subject: O=system:nodes` |
| Correct CN | `Subject: CN=system:node:<nodename>` |
| Correct CA | Issued by Kubernetes CA |

---

## 🔧 Step 7 — Check Kubelet Config

```bash
# view kubelet config
cat /var/lib/kubelet/config.yaml

# view kubelet environment flags
cat /var/lib/kubelet/kubeadm-flags.env

# check where kubelet is looking for config
systemctl cat kubelet
```

---

## 🕵️ Step 8 — Check Static Pod Manifests (Control Plane Node Only)

If troubleshooting the control plane node, also check:

```bash
# list static pod manifests
ls /etc/kubernetes/manifests/

# check a specific manifest
cat /etc/kubernetes/manifests/kube-apiserver.yaml
cat /etc/kubernetes/manifests/kube-scheduler.yaml
cat /etc/kubernetes/manifests/kube-controller-manager.yaml
cat /etc/kubernetes/manifests/etcd.yaml
```

!!! info "Static pods vs worker nodes"
    Static pods only exist on the **control plane node**.
    Worker nodes do NOT have `/etc/kubernetes/manifests/` by default.

---

## 🌐 Step 9 — Check Network Connectivity

```bash
# can worker node reach control plane?
curl -k https://<control-plane-ip>:6443

# check if kubelet can reach API server
journalctl -u kubelet | grep -i "connection refused"
journalctl -u kubelet | grep -i "unreachable"

# check network interfaces
ip addr
ip route
```

---

## 🧪 Full Troubleshooting Scenario

**Scenario**: `node01` shows `NotReady` in `kubectl get nodes`

```bash
# Step 1 — from control plane
kubectl get nodes
# NAME     STATUS     ROLES
# node01   NotReady   <none>

# Step 2 — describe node
kubectl describe node node01 | grep -A10 Conditions
# MemoryPressure   False
# DiskPressure     False
# PIDPressure      False
# Ready            False   ← not ready

# check last heartbeat
kubectl describe node node01 | grep -i heartbeat
# LastHeartbeatTime: Mon, 05 Apr 2026 01:00:00

# Step 3 — SSH into node
ssh node01

# Step 4 — check resources
free -h
df -h

# Step 5 — check kubelet
systemctl status kubelet
# Active: failed ← problem found!

# Step 6 — check logs
journalctl -u kubelet | tail -30
# Error: failed to load config file "/var/lib/kubelet/config.yaml"

# Step 7 — fix the config
vi /var/lib/kubelet/config.yaml

# Step 8 — restart kubelet
systemctl daemon-reload
systemctl restart kubelet
systemctl status kubelet
# Active: active (running) ✅

# Step 9 — verify from control plane
kubectl get nodes
# NAME     STATUS   ROLES
# node01   Ready    <none>   ✅
```

---

## 📊 Quick Reference — All Commands

### From Control Plane
```bash
kubectl get nodes
kubectl get nodes -o wide
kubectl describe node <node-name>
kubectl describe node <node-name> | grep -A20 Conditions
kubectl describe node <node-name> | grep -i heartbeat
```

### On the Worker Node (after SSH)
```bash
# resources
top
free -h
df -h

# kubelet service
systemctl status kubelet
systemctl daemon-reload
systemctl restart kubelet
systemctl enable kubelet

# kubelet logs
journalctl -u kubelet -f
journalctl -u kubelet | tail -50
journalctl -u kubelet | grep -i error
journalctl -u kubelet --since "5m ago"

# certificates
openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -noout -dates
openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -noout -text

# config files
cat /var/lib/kubelet/config.yaml
cat /var/lib/kubelet/kubeadm-flags.env

# network
ip addr
ip route
curl -k https://<control-plane-ip>:6443

# search for text across files
grep -r "error-text" /etc/kubernetes/
grep -r "error-text" /var/lib/kubelet/
```

---

## 🔑 Key Decision Tree

```
Node NotReady?
    ↓
kubectl describe node → check Conditions
    ↓
Unknown status?        → node crashed → SSH and bring back up
MemoryPressure?        → free -h → kill processes or add RAM
DiskPressure?          → df -h → clean up disk space
Ready = False?         → check kubelet
    ↓
systemctl status kubelet
    ↓
Failed?                → journalctl -u kubelet → find error
Running but node bad?  → check certificates → openssl x509
Config wrong?          → vi /var/lib/kubelet/config.yaml
    ↓
systemctl daemon-reload && systemctl restart kubelet
    ↓
kubectl get nodes → verify Ready ✅
```

---

## ⚡ Exam Tips

!!! tip "Speed tips for CKA exam"
    1. Always check `kubectl describe node` **before** SSHing into the node
    2. `systemctl status kubelet` is your fastest diagnostic on the node
    3. Always run `daemon-reload` before `restart kubelet`
    4. Check `journalctl -u kubelet | tail -50` — the error is almost always in the last few lines
    5. Certificate issues → check `notAfter` date first

!!! warning "Common mistakes"
    - Forgetting `daemon-reload` before restart
    - Using `journalctl` for static pods (only works for kubelet)
    - Not checking `lastHeartbeatTime` to understand when node failed
    - Fixing the issue but forgetting to verify with `kubectl get nodes`
