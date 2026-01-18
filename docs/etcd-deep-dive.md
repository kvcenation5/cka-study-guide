# ETCD Deep Dive & Backup Guide

**ETCD** is the brain of your Kubernetes cluster. It is a consistent and highly-available key value store used as Kubernetes' backing store for all cluster data.

If you lose ETCD, you lose your cluster. That is why **Backup & Restore** is a critical CKA competency.

---

## 1. Exploring ETCD (The "Hidden" Database)

Kubernetes stores every resource (Pods, Services, Secrets) as a key-value pair in ETCD.

### Accessing ETCD
ETCD is secured by Mutual TLS (mTLS). You cannot just access it without the correct certificates.

**Common Certificate Locations (Kubeadm/Standard):**
- CA Cert: `/etc/kubernetes/pki/etcd/ca.crt`
- Server Cert: `/etc/kubernetes/pki/etcd/server.crt`
- Server Key: `/etc/kubernetes/pki/etcd/server.key`

**Minikube Locations:**
- CA Cert: `/var/lib/minikube/certs/etcd/ca.crt`
- Server Cert: `/var/lib/minikube/certs/etcd/server.crt`
- Server Key: `/var/lib/minikube/certs/etcd/server.key`

### ETCDCTL Utility Versions & Usage

The `etcdctl` CLI tool interacts with the ETCD Server using **2 API versions**: Version 2 and Version 3.

*   By default, it is often set to use **Version 2**.
*   Each version has completely different commands.

**Version 2 Commands (Old/Default)**:
*   `etcdctl backup`
*   `etcdctl cluster-health`
*   `etcdctl mk`
*   `etcdctl mkdir`
*   `etcdctl set`

**Version 3 Commands (Used in Kubernetes)**:
*   `etcdctl snapshot save`
*   `etcdctl endpoint health`
*   `etcdctl get`
*   `etcdctl put`

**How to set the right version:**
To use version 3 commands (which are required for Kubernetes/CKA), you MUST set the environment variable:

```bash
export ETCDCTL_API=3
```

**Note:** If the API version is not set, it defaults to version 2, and version 3 commands (like `snapshot save`) will fail. Conversely, if set to version 3, version 2 commands (like `mkdir`) will fail.

### Specifying Certificates (Authentication)
Apart from setting the API version, you must specify the path to certificate files so that `etcdctl` can authenticate to the ETCD API Server.

Standard locations (kubeadm/master node):
*   `--cacert /etc/kubernetes/pki/etcd/ca.crt`
*   `--cert /etc/kubernetes/pki/etcd/server.crt`
*   `--key /etc/kubernetes/pki/etcd/server.key`

### Master Command Example
Here is the full command that combines API versioning, certificate paths, and execution inside a pod:

```bash
kubectl exec etcd-master -n kube-system -- sh -c "ETCDCTL_API=3 etcdctl get / --prefix --keys-only --limit=10 --cacert /etc/kubernetes/pki/etcd/ca.crt --cert /etc/kubernetes/pki/etcd/server.crt  --key /etc/kubernetes/pki/etcd/server.key"
```

### The "Magic" Command
To see what resides in your cluster's brain, run this from inside the etcd pod (or a node with `etcdctl` installed):

```bash
# General Syntax
ETCDCTL_API=3 etcdctl \
  --cacert=<path-to-ca> \
  --cert=<path-to-cert> \
  --key=<path-to-key> \
  get / --prefix --keys-only
```

**Example (Minikube):**
```bash
kubectl exec etcd-minikube -n kube-system -- etcdctl \
  --cacert=/var/lib/minikube/certs/etcd/ca.crt \
  --cert=/var/lib/minikube/certs/etcd/server.crt \
  --key=/var/lib/minikube/certs/etcd/server.key \
  get /registry/pods --prefix --keys-only
```

**Sample Output:**
```
/registry/pods/default/my-web-app
/registry/pods/kube-system/coredns-66bc5c9577-6xrr6
/registry/pods/kube-system/etcd-minikube
```

---

## 2. ETCD Backup (CKA Must-Know)

You MUST know how to take a snapshot of the ETCD database.

### Step 1: Log in to the Control Plane Node
In the exam, you will likely run this directly on the master node where `etcdctl` is installed.

### Step 2: Run the Snapshot Command
Use the `snapshot save` command.

```bash
ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /tmp/etcd-backup.db
```

**Success Output:**
```
Snapshot saved at /tmp/etcd-backup.db
```

### Step 3: Verify the Snapshot
Always verify your backup was successful.

```bash
ETCDCTL_API=3 etcdctl --write-out=table snapshot status /tmp/etcd-backup.db
```

---

## 3. ETCD Restore (Disaster Recovery)

If your cluster data is corrupted or deleted, you restore from the snapshot.

### Criticial Concept: The Restore Process
Restoring doesn't just "overwrite" the running database. It creates a **new data directory**. You then have to tell the ETCD pod to use this new directory.

### Step 1: Restore the Snapshot
This command extracts the backup file into a new directory path.

```bash
# directory where the new data will be extracted
ETCDCTL_API=3 etcdctl snapshot restore /tmp/etcd-backup.db \
  --data-dir /var/lib/etcd-restore-new
```

### Step 2: Update the ETCD Static Pod Manifest
You need to point the running ETCD pod to this new directory.

1.  **Edit the manifest:** `/etc/kubernetes/manifests/etcd.yaml`
2.  **Update `hostPath`:** look for the volume mount for `etcd-data`.

**Before:**
```yaml
  volumes:
  - hostPath:
      path: /var/lib/etcd
      type: DirectoryOrCreate
    name: etcd-data
```

**After:**
```yaml
  volumes:
  - hostPath:
      path: /var/lib/etcd-restore-new  # <--- CHANGED THIS
      type: DirectoryOrCreate
    name: etcd-data
```

### Step 3: Wait for Restart
Kubernetes will detect the file change and restart the ETCD pod automatically. It might take a minute.

---

## 4. Cheat Sheet Summary

| Task | Command / Flag |
| :--- | :--- |
| **API Version** | `export ETCDCTL_API=3` (Always set this!) |
| **Endpoint** | `--endpoints=https://127.0.0.1:2379` |
| **Cert Flags** | `--cacert`, `--cert`, `--key` |
| **Backup** | `snapshot save <filename>` |
| **Verify** | `snapshot status <filename>` |
| **Restore** | `snapshot restore <filename> --data-dir <new-path>` |

