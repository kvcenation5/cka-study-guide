# Storage Deep Dive

Storage in Kubernetes allows stateful applications to persist data beyond the lifecycle of a Pod. For the CKA exam, you must understand the relationship between PersistentVolumes (PV), PersistentVolumeClaims (PVC), and StorageClasses (SC).

---

## 🏗️ 1. Core Storage Components

### PersistentVolume (PV)
A piece of storage in the cluster that has been provisioned by an administrator or dynamically provisioned using a StorageClass.
*   **Scope**: Cluster-wide (not namespaced).
*   **Resources**: Physical disks, NFS, cloud storage (EBS/GCP PD), or local storage.

### PersistentVolumeClaim (PVC)
A request for storage by a user. It is similar to a Pod; Pods consume Node resources, and PVCs consume PV resources.
*   **Scope**: Namespaced.
*   **Match**: K8s matches a PVC to a PV based on size, access modes, and StorageClass.

### StorageClass (SC)
Defines "classes" of storage (e.g., "fast-ssd", "slow-hdd"). It enables **Dynamic Provisioning**, so you don't have to manually create PVs.

---

## 🔍 2. Access Modes & Reclaim Policies

### Access Modes
| Mode | Short | Description |
| :--- | :--- | :--- |
| **ReadWriteOnce** | `RWO` | Mounted as read-write by a single Node. |
| **ReadOnlyMany** | `ROX` | Mounted as read-only by many Nodes. |
| **ReadWriteMany** | `RWX` | Mounted as read-write by many Nodes (requires NFS/EFS/AzureFiles). |
| **ReadWriteOncePod** | `RWOP` | Mounted as read-write by a single Pod (K8s v1.22+). |

### Reclaim Policies (What happens to PV when PVC is deleted)
1.  **Retain**: PV is kept. Administrator must manually clean up/reclaim data.
2.  **Delete**: Physical storage (e.g., AWS EBS) is deleted immediately.
3.  **Recycle**: (Deprecated) Performs a basic `rm -rf /` on the volume.

---

## 🛠️ 3. Dynamic Provisioning Workflow

1.  **Create StorageClass**: Define the provisioner (e.g., `kubernetes.io/aws-ebs`).
2.  **Create PVC**: Reference the `storageClassName`.
3.  **Automatic PV Creation**: Kubernetes automatically creates a PV that matches the PVC.
4.  **Pod Usage**: Reference the PVC in the Pod spec under `volumes`.

```yaml
# Pod using a PVC
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: storage-vol
      mountPath: /data
  volumes:
  - name: storage-vol
    persistentVolumeClaim:
      claimName: my-pvc
```

---

## 🔧 4. Troubleshooting Storage Issues

### PVC stuck in "Pending"
*   **No matching PV**: If using static provisioning, check if a PV exists with enough capacity and matching AccessModes.
*   **StorageClass Issues**: Check if the provisioner is running or if the `storageClassName` is misspelled.
*   **WaitForFirstConsumer**: If the SC uses `volumeBindingMode: WaitForFirstConsumer`, the PVC will stay Pending until a **Pod** is created that uses it.

### Pod stuck in "ContainerCreating"
*   **Multi-Attach Error**: A `ReadWriteOnce` volume is already attached to another Node.
*   **Mount Failures**: Check `kubectl describe pod` for specific mount errors (permissions, network path etc).

---

## 🎯 5. Exam Tips (CKA)

1.  **Check Capacity**: PV capacity must be $\ge$ PVC request.
2.  **Matching Labels**: PVs and PVCs can use labels/selectors to bind to specific volumes.
3.  **Resizing**: Some StorageClasses allow `allowVolumeExpansion: true`. You can edit the PVC size, but the volume usually won't shrink.
4.  **HostPath**: For local lab environments, `hostPath` is often used. Remember it only works on the specific node where the pod is scheduled!

---

> [!IMPORTANT]
> **Check your spelling**: Kubernetes is strict. `ReadWriteOnce` is NOT the same as `Readwriteonce`. Always use the official Case-Sensitive strings.
