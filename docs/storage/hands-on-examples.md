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

> [!WARNING]
> Remember that `emptyDir` data is wiped if the Pod is deleted. If you need data to survive Pod restarts/deletions, use **PV and PVC**.
