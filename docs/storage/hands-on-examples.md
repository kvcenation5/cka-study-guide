# Hands-on Storage Examples

This page provides practical YAML examples for common storage scenarios in Kubernetes.

---

## 🎲 1. Random Number Generator (emptyDir)

This example demonstrates how two containers in the same Pod can share data using an `emptyDir` volume.

*   **Generator Container**: Writes a random number between 1-100 to `/opt/data/number.txt` every 5 seconds.
*   **Logger Container (Sidecar)**: Reads the number from the same file and prints it to its logs.

### The YAML (`random-generator.yaml`)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: random-generator
spec:
  containers:
  - name: generator
    image: alpine
    command: ["/bin/sh", "-c"]
    args:
    - while true; do
        shuf -i 1-100 -n 1 > /opt/data/number.txt;
        echo "Generated number: $(cat /opt/data/number.txt)";
        sleep 5;
      done
    volumeMounts:
    - name: shared-data
      mountPath: /opt/data
  
  - name: logger
    image: alpine
    command: ["/bin/sh", "-c"]
    args:
    - while true; do
        if [ -f /opt/data/number.txt ]; then
          echo "Sidecar reading number: $(cat /opt/data/number.txt)";
        fi;
        sleep 5;
      done
    volumeMounts:
    - name: shared-data
      mountPath: /opt/data

  volumes:
  - name: shared-data
    emptyDir: {}
```

### How to test:
1.  Apply the pod: `kubectl apply -f random-generator.yaml`
2.  Check the logs of the generator: `kubectl logs random-generator -c generator`
3.  Check the logs of the sidecar: `kubectl logs random-generator -c logger`

---

## 💾 2. Persistent Storage with HostPath

This is useful for local testing or when you need to access files from the underlying node.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: hostpath-pod
spec:
  containers:
  - name: web
    image: nginx
    volumeMounts:
    - name: node-log
      mountPath: /var/log/host-node
  volumes:
  - name: node-log
    hostPath:
      path: /var/log
      type: Directory
```

---

## 🔗 3. Manual PV & PVC Binding

This example shows how to manually create a PersistentVolume and a PersistentVolumeClaim that bind together based on their `storageClassName`, `accessModes`, and `capacity`.

### The YAML (`pv-pvc-manual.yaml`)

```yaml
# 1. The PersistentVolume (Cluster-wide resource)
apiVersion: v1
kind: PersistentVolume
metadata:
  name: manual-pv
  labels:
    type: local
spec:
  storageClassName: manual
  capacity:
    storage: 2Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/mnt/data/manual-storage"

---

# 2. The PersistentVolumeClaim (Namespaced resource)
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: manual-pvc
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

### Key Binding Rules:
1.  **StorageClassName**: Both must match (in this case, `manual`).
2.  **AccessModes**: The PV must support at least the access mode requested by the PVC.
3.  **Capacity**: The PV capacity must be greater than or equal to the PVC request.

### How to test:
1.  Create the resources: `kubectl apply -f pv-pvc-manual.yaml`
2.  Check the PV status: `kubectl get pv manual-pv` (Should be **Bound**)
3.  Check the PVC status: `kubectl get pvc manual-pvc` (Should be **Bound**)

---

> [!TIP]
> **Dynamic vs Manual**: In production, you'll likely use a **StorageClass** to automate this (Dynamic Provisioning). In the CKA exam, you will often be asked to perform a **Manual binding** like this example.
