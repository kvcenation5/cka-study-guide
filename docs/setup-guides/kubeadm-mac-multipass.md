# CKA Lab Setup: Kubeadm on macOS (via Multipass)

Minikube is great for deploying apps, but it **cannot** be used to practice cluster bootstrapping or upgrades (`kubeadm`). 

This guide allows you to run a full Linux VM on your Mac to practice the **"Cluster Installation"** portion of the CKA exam.

## 1. What is Multipass?

**Multipass** is an official tool from Canonical (the makers of Ubuntu) designed to create Ubuntu virtual machines instantly.

Think of it as "Docker for Virtual Machines."
*   **Docker** gives you a container (processes sharing a kernel).
*   **Multipass** gives you a full VM (its own kernel, systemd, and IP stack).

**Why use it for CKA?**
1.  **Native Hypervisor:** It uses `HyperKit` (on Intel Macs) or `Virtualization.framework` (on Apple Silicon M1/M2/M3), making it extremely fast compared to VirtualBox.
2.  **Clean Slate:** You get a fresh "server" in seconds. If you break the cluster (common when learning `kubeadm`), you just delete the VM and start a new one.
3.  **Real Linux:** `kubeadm` only runs on Linux. Multipass gives you that Linux environment on your Mac transparently.

## 2. Install Multipass 

Multipass behaves like a lightweight cloud on your local machine. It creates Ubuntu VMs instantly.

```bash
brew install --cask multipass
```

## 2. Launch a Master Node
Create a VM named `k8s-master` with enough resources (2 CPUs, 2GB RAM).

```bash
multipass launch --name k8s-master --cpus 2 --memory 2G --disk 10G
```

Log into the VM:
```bash
multipass shell k8s-master
```

### What to Expect Inside
When you first log in, the directory (`/home/ubuntu`) will be **empty**.
```bash
ubuntu@k8s-master:~$ ls -ltr
total 0
```
**This is normal!** You have launched a minimal "Cloud Image" (similar to an AWS EC2 instance). It is a clean slate without any pre-installed tools or GUI folders.

To see the Linux system files, check the root:
```bash
ls -F /
# Output: bin/ etc/ var/ usr/ ...
```

*(All subsequent commands are run INSIDE this shell)*

---

## 3. The "Standard" Installation (CKA Workflow)

In the exam, you must install a Container Runtime and the Kubernetes tools.

### Step A: Configure System Prerequisites
Disabling swap and loading kernel modules is mandatory.

```bash
# 1. Forward IPv4 and let iptables see bridged traffic
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# 2. Sysctl params required by setup
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system
```

### Step B: Install Container Runtime (Containerd)

```bash
# Update and install containerd
sudo apt-get update
sudo apt-get install -y containerd

# Create default config
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

# IMPORTANT for CKA: Set SystemdCgroup = true
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

# Restart containerd
sudo systemctl restart containerd
```

### Step C: Install Kubeadm, Kubelet, Kubectl

```bash
# 1. Install packages needed to use the Kubernetes apt repository
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

# 2. Download the public signing key for the Kubernetes packet repositories
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# 3. Add the K8s apt repository
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# 4. Install the tools
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

---

## 4. Initialize the Cluster (Bootstrapping)

Now you are ready to run the command you tried earlier.

```bash
# Using a specific pod network CIDR is usually required for CNI plugins
sudo kubeadm init --pod-network-cidr=192.168.0.0/16
```

Once this finishes, **Read the Output!** It tells you exactly what to do next:

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

## 5. Install Network Plugin (CNI)
Nodes will remain `NotReady` until you install networking. We will use Calico.

```bash
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/tigera-operator.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/custom-resources.yaml
```

Check your work:
```bash
kubectl get nodes
```

## 6. Cleanup (When finished)
To delete the VM from your Mac:
```bash
# On your Mac terminal
multipass delete k8s-master
multipass purge
```

