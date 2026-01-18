# Kubeadm Join Command

This document contains the critical join command generated after the cluster was initialized on the control plane. This is needed to add worker nodes to the cluster.

---

## 🚀 The Join Command

**Control Plane IP:** `192.168.1.187`

Run this command on your **worker nodes** (node01, node02) with `sudo` to join them to the cluster:

```bash
sudo kubeadm join 192.168.1.187:6443 --token nzo4d6.0tt0bv01najwjkov \
	--discovery-token-ca-cert-hash sha256:415d9742be98a0b5f00a94d665578a480d90efb69f5858915282617c4b78d733 
```

---

## 💡 Important Notes for CKA

### 1. Token Lifespan
By default, this token is only valid for **24 hours**. If you try to join a node tomorrow and it fails, you'll need to generate a new token.

### 2. How to recover a lost join command
If you did not note down the join command on the controlplane node after running `kubeadm init`, you can recover it by running the following on **controlplane**:

```bash
kubeadm token create --print-join-command
```

This command generates a new token and prints the full `kubeadm join` string for you.

### 3. Verification
After running the join command on the workers, verify they have joined by running this on the **control plane**:
```bash
kubectl get nodes
```

### 4. What if I lose the CA Hash?
If you have a token but lost the hash, you can find it with this command:
```bash
openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | \
   openssl dgst -sha256 -hex | sed 's/^.* //'
```

---

## Troubleshooting "Join" Failures

*   **Connectivity:** Ensure the worker node can ping `192.168.1.187`.
*   **Firewall:** Port `6443` must be open on the control plane.
*   **Container Runtime:** `containerd` must be running on the worker node before joining.
*   **Swap:** Swap must be disabled on the worker node (`sudo swapoff -a`).
