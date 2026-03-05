# StatefulSet & PersistentVolume Architecture

This diagram shows how StatefulSets work with PersistentVolumes in Kubernetes.

![StatefulSet PV Architecture](statefulset-pv-architecture-detailed.png)

## Key Components

### StatefulSet
- Manages stateful applications with stable pod identities
- Each pod gets a unique, persistent identifier (e.g., web-0, web-1, web-2)
- Pods are created and deleted in order

### VolumeClaimTemplates
- Automatically creates a PVC for each pod replica
- Each pod gets its own unique PVC
- PVCs persist even when pods are deleted

### PersistentVolume (PV)
- Actual storage resource in the cluster
- Can be provisioned statically or dynamically via StorageClass
- Independent lifecycle from pods

### Access Modes
- **ReadWriteOnce (RWO)**: Volume mounted by single node
- **ReadWriteMany (RWX)**: Volume mounted by multiple nodes (requires NFS/EFS)
- **ReadOnlyMany (ROX)**: Read-only by multiple nodes