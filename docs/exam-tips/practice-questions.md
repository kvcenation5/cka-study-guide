# CKA Practice Questions & Solutions

!!! tip "How to Use This Page"
    These are real exam-style questions collected from practice sessions.  
    **Try solving each one before expanding the solution.**  
    Target: **under 3 minutes per question** to match exam pace.

---

## Q1 — Cluster Upgrade (kubeadm)

!!! question "Task"
    Upgrade the current version of Kubernetes from `1.33.0` to `1.34.0` exactly using the `kubeadm` utility.
    Make sure the upgrade is carried out **one node at a time** starting with the controlplane node.
    To minimize downtime, the deployment `gold-nginx` should be rescheduled on an alternate node before upgrading each node.
    Upgrade `controlplane` node first and drain `node01` before upgrading it.
    Pods for `gold-nginx` should run on the `controlplane` node subsequently.

??? success "Step-by-Step Solution"

    ### Check current state first
    ```bash
    kubectl get nodes
    kubectl get pods -o wide | grep gold-nginx
    ```

    ---

    ### Phase 1 — Upgrade Controlplane Node

    **Step 1 — Drain controlplane (gold-nginx moves to node01)**
    ```bash
    kubectl drain controlplane --ignore-daemonsets --delete-emptydir-data
    ```

    **Step 2 — Upgrade kubeadm**
    ```bash
    apt-mark unhold kubeadm
    apt-get update
    apt-get install -y kubeadm=1.34.0-1.1
    apt-mark hold kubeadm
    kubeadm version
    ```

    **Step 3 — Plan and apply the upgrade**
    ```bash
    kubeadm upgrade plan v1.34.0
    kubeadm upgrade apply v1.34.0
    ```

    **Step 4 — Upgrade kubelet and kubectl**
    ```bash
    apt-mark unhold kubelet kubectl
    apt-get install -y kubelet=1.34.0-1.1 kubectl=1.34.0-1.1
    apt-mark hold kubelet kubectl
    systemctl daemon-reload
    systemctl restart kubelet
    ```

    **Step 5 — Uncordon controlplane**
    ```bash
    kubectl uncordon controlplane
    kubectl get nodes
    # controlplane should show v1.34.0 and Ready
    ```

    ---

    ### Phase 2 — Upgrade node01

    **Step 6 — Drain node01 from controlplane (gold-nginx moves back to controlplane ✅)**
    ```bash
    kubectl drain node01 --ignore-daemonsets --delete-emptydir-data
    ```

    **Step 7 — SSH into node01 and upgrade kubeadm**
    ```bash
    ssh node01

    apt-mark unhold kubeadm
    apt-get update
    apt-get install -y kubeadm=1.34.0-1.1
    apt-mark hold kubeadm

    kubeadm upgrade node        # NOTE: 'node' not 'apply' on worker nodes
    ```

    **Step 8 — Upgrade kubelet and kubectl on node01**
    ```bash
    apt-mark unhold kubelet kubectl
    apt-get install -y kubelet=1.34.0-1.1 kubectl=1.34.0-1.1
    apt-mark hold kubelet kubectl
    systemctl daemon-reload
    systemctl restart kubelet
    exit
    ```

    **Step 9 — Uncordon node01**
    ```bash
    kubectl uncordon node01
    ```

    ---

    ### Verify everything
    ```bash
    kubectl get nodes
    # Both nodes should show v1.34.0 and Ready

    kubectl get pods -o wide | grep gold-nginx
    # gold-nginx should be running on controlplane ✅
    ```

    ---

    ### Key Rules to Remember

    | Rule | Detail |
    |------|--------|
    | Worker nodes use `kubeadm upgrade node` | NOT `kubeadm upgrade apply` |
    | Always `apt-mark unhold` before install | Otherwise package is blocked |
    | Uncordon AFTER kubelet restart | Not before |
    | `kubectl` commands only from controlplane | Won't work inside SSH on worker |
    | Can only upgrade one minor version at a time | 1.30 → 1.31 → 1.32, not 1.30 → 1.32 |

---

## Q2 — Custom Column Output to File

!!! question "Task"
    Print the names of all deployments in the `admin2406` namespace in the following format:  
    `DEPLOYMENT CONTAINER_IMAGE READY_REPLICAS NAMESPACE`  
    The data should be sorted by **increasing order of deployment name**.  
    Write the result to the file `/opt/admin2406_data`.

    **Example output:**
    ```
    DEPLOYMENT   CONTAINER_IMAGE   READY_REPLICAS   NAMESPACE
    deploy0      nginx:alpine      1                admin2406
    ```

??? success "Step-by-Step Solution"

    ```bash
    kubectl get deployments -n admin2406 \
      -o custom-columns=\
    "DEPLOYMENT:.metadata.name,\
    CONTAINER_IMAGE:.spec.template.spec.containers[0].image,\
    READY_REPLICAS:.status.readyReplicas,\
    NAMESPACE:.metadata.namespace" \
      --sort-by=.metadata.name > /opt/admin2406_data
    ```

    ### Verify the output
    ```bash
    cat /opt/admin2406_data
    ```

    ---

    ### Command Breakdown

    | Part | What it does |
    |------|-------------|
    | `-n admin2406` | Target the right namespace |
    | `-o custom-columns` | Define your own output columns |
    | `:.metadata.name` | Deployment name |
    | `:.spec.template.spec.containers[0].image` | First container image |
    | `:.status.readyReplicas` | Ready replica count |
    | `:.metadata.namespace` | Namespace name |
    | `--sort-by=.metadata.name` | Sort alphabetically |
    | `> /opt/admin2406_data` | Write to required file |

    !!! tip "Exam Tip"
        `custom-columns` with `--sort-by` is a one-liner — no scripting, no loops, no `jq` needed. This is the cleanest approach for this type of question.

---

## Q3 — Fix Broken Kubeconfig

!!! question "Task"
    A kubeconfig file called `admin.kubeconfig` has been created in `/root/CKA`.  
    There is something wrong with the configuration. Troubleshoot and fix it.

??? success "Step-by-Step Solution"

    ### Step 1 — Compare against the working kubeconfig
    ```bash
    # Check the working kubeconfig (always correct)
    cat ~/.kube/config | grep server
    # server: https://controlplane:6443  ✅

    # Check the broken kubeconfig
    cat /root/CKA/admin.kubeconfig | grep server
    # server: https://controlplane:4380  ❌
    ```

    ### Step 2 — Fix the wrong port
    ```bash
    # Option A — kubectl command
    kubectl config set-cluster kubernetes \
      --server=https://controlplane:6443 \
      --kubeconfig=/root/CKA/admin.kubeconfig

    # Option B — sed (fastest in exam)
    sed -i 's/4380/6443/g' /root/CKA/admin.kubeconfig
    ```

    ### Step 3 — Verify the fix
    ```bash
    kubectl get nodes --kubeconfig=/root/CKA/admin.kubeconfig
    # Should return nodes successfully ✅
    ```

    ---

    ### What to Check in a Broken Kubeconfig

    | Field | Common Problem | Correct Value |
    |-------|---------------|---------------|
    | `server:` port | Wrong port (`4380`, `8080`) | `6443` |
    | `server:` hostname | Wrong host | `controlplane` |
    | `current-context` | Points to wrong context | Check with `kubectl config get-contexts` |
    | `certificate-authority-data` | Missing or empty | Must be present |

    !!! warning "Exam Trap"
        Always run `cat ~/.kube/config | grep server` first — it gives you the correct answer in 3 seconds. Never guess the port.

---

## Q4 — Rolling Update with Annotation

!!! question "Task"
    Create a new deployment called `nginx-deploy`, with image `nginx:1.16` and `1` replica.  
    Next, upgrade the deployment to version `1.17` using rolling update and add the annotation message `Updated nginx image to 1.17`.

??? success "Step-by-Step Solution"

    ### Step 1 — Create the deployment
    ```bash
    kubectl create deployment nginx-deploy --image=nginx:1.16 --replicas=1
    ```

    ### Step 2 — Verify it's running
    ```bash
    kubectl get deployment nginx-deploy
    ```

    ### Step 3 — Rolling update to nginx:1.17
    ```bash
    kubectl set image deployment/nginx-deploy nginx-deploy=nginx:1.17
    ```

    ### Step 4 — Add the annotation
    ```bash
    kubectl annotate deployment/nginx-deploy \
      kubernetes.io/change-cause="Updated nginx image to 1.17"
    ```

    ### Step 5 — Verify rollout and annotation
    ```bash
    kubectl rollout status deployment/nginx-deploy

    kubectl rollout history deployment/nginx-deploy
    # REVISION  CHANGE-CAUSE
    # 1         <none>
    # 2         Updated nginx image to 1.17  ✅
    ```

    ### Step 6 — Confirm image updated
    ```bash
    kubectl describe deployment nginx-deploy | grep Image
    # Image: nginx:1.17  ✅
    ```

    ---

    ### Key Commands Reference

    | Command | Purpose |
    |---------|---------|
    | `kubectl set image deployment/<name> <container>=<image>` | Trigger rolling update |
    | `kubectl annotate deployment/<name> kubernetes.io/change-cause="..."` | Add history message |
    | `kubectl rollout status` | Watch rollout complete |
    | `kubectl rollout history` | Verify annotation in revision |

    !!! tip "Container Name"
        The container name in `set image` must match the container name inside the deployment spec. When created with `kubectl create deployment`, the container name matches the deployment name by default.  
        Confirm with: `kubectl describe deployment nginx-deploy | grep -A2 Containers`

---

## Q5 — Troubleshoot Pending Deployment (PVC Issue)

!!! question "Task"
    A new deployment called `alpha-mysql` has been deployed in the `alpha` namespace. However, the pods are not running. Troubleshoot and fix the issue.  
    The deployment should make use of the persistent volume `alpha-pv` to be mounted at `/var/lib/mysql` and should use the environment variable `MYSQL_ALLOW_EMPTY_PASSWORD=1` to make use of an empty root password.

??? success "Step-by-Step Solution"

    ### Step 1 — Identify the problem
    ```bash
    kubectl get pods -n alpha
    # Pod is in Pending state

    kubectl describe pod <alpha-mysql-pod-name> -n alpha
    # Events will show: persistentvolumeclaim "mysql-alpha-pvc" not found
    ```

    ### Step 2 — Check existing PVCs and PVs
    ```bash
    kubectl get pvc -n alpha
    # alpha-claim   Pending   (wrong storageClassName!)

    kubectl get pv
    # alpha-pv   1Gi   RWO   Retain   Available   slow

    kubectl get storageclass
    # NAME   PROVISIONER                    
    # slow   kubernetes.io/no-provisioner
    ```

    ### Step 3 — Fix alpha-claim (wrong storageClassName)
    ```bash
    # PVC had storageClassName: slow-storage (wrong)
    # Correct name is: slow

    kubectl delete pvc alpha-claim -n alpha

    kubectl apply -f - <<EOF
    apiVersion: v1
    kind: PersistentVolumeClaim
    metadata:
      name: alpha-claim
      namespace: alpha
    spec:
      accessModes:
        - ReadWriteOnce
      resources:
        requests:
          storage: 1Gi
      storageClassName: slow
    EOF
    ```

    ### Step 4 — Create the missing mysql-alpha-pvc
    ```bash
    # Pod needs mysql-alpha-pvc but it doesn't exist
    # Must match the PV: 1Gi, RWO, storageClass: slow

    kubectl apply -f - <<EOF
    apiVersion: v1
    kind: PersistentVolumeClaim
    metadata:
      name: mysql-alpha-pvc
      namespace: alpha
    spec:
      accessModes:
        - ReadWriteOnce
      resources:
        requests:
          storage: 1Gi
      storageClassName: slow
    EOF
    ```

    ### Step 5 — Verify full chain
    ```bash
    # PV should be Bound
    kubectl get pv
    # alpha-pv   Bound   alpha/mysql-alpha-pvc ✅

    # Both PVCs should be Bound
    kubectl get pvc -n alpha
    # alpha-claim       Bound ✅
    # mysql-alpha-pvc   Bound ✅

    # Pod should now be Running
    kubectl get pods -n alpha
    # alpha-mysql-xxx   Running ✅
    ```

    ---

    ### Troubleshooting Decision Tree

    ```
    Pod Pending → kubectl describe pod → check Events
        │
        └── "pvc not found"
                │
                ├── PVC doesn't exist → create it matching PV specs
                │
                └── PVC exists but Pending
                        │
                        └── "storageclass not found"
                                │
                                ├── kubectl get storageclass
                                └── fix storageClassName in PVC (delete + recreate)
    ```

    !!! warning "Common Exam Trap"
        `0/2 nodes are available` sounds like a node problem — it's NOT. Always read the **full reason** in FailedScheduling. The real clue is the PVC error after it.

---

## Q6 — ETCD Backup

!!! question "Task"
    Take the backup of ETCD at the location `/opt/etcd-backup.db` on the `controlplane` node.

??? success "Step-by-Step Solution"

    ### Step 1 — Get all cert paths from etcd manifest (do this first, always)
    ```bash
    grep -E "listen-client|cert-file|key-file|trusted-ca" \
      /etc/kubernetes/manifests/etcd.yaml
    ```

    This gives you the exact paths to paste — never type them from memory.

    ### Step 2 — Take the backup
    ```bash
    ETCDCTL_API=3 etcdctl snapshot save /opt/etcd-backup.db \
      --endpoints=https://127.0.0.1:2379 \
      --cacert=/etc/kubernetes/pki/etcd/ca.crt \
      --cert=/etc/kubernetes/pki/etcd/server.crt \
      --key=/etc/kubernetes/pki/etcd/server.key
    ```

    ### Step 3 — Verify the backup
    ```bash
    ETCDCTL_API=3 etcdctl snapshot status /opt/etcd-backup.db \
      --write-out=table
    ```

    Expected output:
    ```
    +----------+----------+------------+------------+
    |   HASH   | REVISION | TOTAL KEYS | TOTAL SIZE |
    +----------+----------+------------+------------+
    | xxxxxxxx |    12345 |       1234 |     3.2 MB |
    +----------+----------+------------+------------+
    ```

    ---

    ### The 3 Cert Files Explained

    | Flag | File | Purpose |
    |------|------|---------|
    | `--cacert` | `etcd/ca.crt` | Verifies etcd server identity |
    | `--cert` | `etcd/server.crt` | Client certificate to authenticate |
    | `--key` | `etcd/server.key` | Private key for client cert |

    !!! tip "Exam Tip"
        Run the `grep` command first, copy the cert paths from output, then build the `etcdctl` command. Saves 2 minutes vs typing paths from memory. One wrong character fails the backup silently.

---

## Q7 — Pod with Secret Volume Mount

!!! question "Task"
    Create a pod called `secret-1401` in the `admin1401` namespace using the `busybox` image.  
    The container within the pod should be called `secret-admin` and should sleep for `4800` seconds.  
    The container should mount a **read-only** secret volume called `secret-volume` at the path `/etc/secret-volume`.  
    The secret being mounted has already been created and is called `dotfile-secret`.

??? success "Step-by-Step Solution"

    ```bash
    kubectl apply -f - <<EOF
    apiVersion: v1
    kind: Pod
    metadata:
      name: secret-1401
      namespace: admin1401
    spec:
      containers:
      - name: secret-admin
        image: busybox
        command: ["sleep", "4800"]
        volumeMounts:
        - name: secret-volume
          mountPath: /etc/secret-volume
          readOnly: true
      volumes:
      - name: secret-volume
        secret:
          secretName: dotfile-secret
    EOF
    ```

    ### Verify
    ```bash
    # Pod is running
    kubectl get pod secret-1401 -n admin1401

    # Volume mounted correctly with readOnly
    kubectl describe pod secret-1401 -n admin1401 | grep -A5 Mounts
    # /etc/secret-volume from secret-volume (ro) ✅
    ```

    ---

    ### Requirements Checklist

    | Requirement | Field in YAML |
    |-------------|--------------|
    | Pod name `secret-1401` | `metadata.name` |
    | Namespace `admin1401` | `metadata.namespace` |
    | Container name `secret-admin` | `containers[0].name` |
    | Sleep `4800` seconds | `command: ["sleep", "4800"]` |
    | Volume name `secret-volume` | `volumes[0].name` AND `volumeMounts[0].name` must match |
    | Mount path `/etc/secret-volume` | `volumeMounts[0].mountPath` |
    | `readOnly: true` | `volumeMounts[0].readOnly` |
    | Secret name `dotfile-secret` | `volumes[0].secret.secretName` |

    !!! warning "Critical Mistake to Avoid"
        `readOnly: true` must be on the **`volumeMounts`** entry inside the container — NOT on the volume definition. This is the most common mistake for this type of question.

---

## Quick Reference — Exam Speed Tips

### Set these aliases at the START of every exam session
```bash
alias k=kubectl
export do="--dry-run=client -o yaml"
export now="--force --grace-period 0"
```

### Generate YAML fast instead of writing from scratch
```bash
k run nginx --image=nginx $do > pod.yaml
k create deploy my-deploy --image=nginx $do > deploy.yaml
k create secret generic my-secret --from-literal=key=value $do > secret.yaml
```

### The 2-minute rule
If stuck on a question for 2 minutes → **flag and move on**. Come back at the end.

### Always know where you are
```bash
hostname        # confirm you're on the right node
kubectl config current-context   # confirm the right cluster
```
