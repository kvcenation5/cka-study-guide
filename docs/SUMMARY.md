# Kubernetes Troubleshooting Zero to Hero - Complete Summary

## 01-ImagePullBackOff
**Problem:** Container image cannot be pulled from registry

**Common Causes:**
- **Invalid Image Name**
  - Typo in image name or tag
  - Non-existent image
  - Wrong registry path
- **Private Registry Without Credentials**
  - Missing imagePullSecret for private Docker Hub, ECR, or other registries
  - Expired or incorrect credentials

**Solution:**
- Verify image name and tag are correct
- Create docker-registry secret for private images:
  ```bash
  kubectl create secret docker-registry <name> \
    --docker-server=<registry> \
    --docker-username=<user> \
    --docker-password=<password>
  ```
- Reference secret in pod spec using `imagePullSecrets`

**Diagnosis:** `kubectl describe pod <name>` - check Events section

---

## 02-CrashLoopBackOff
**Problem:** Container starts, crashes, and enters restart loop

**Common Causes:**
- **Wrong Command/Misconfiguration**
  - Invalid command-line arguments
  - Missing environment variables
  - Wrong config file paths
- **Liveness Probe Failures**
  - Probe checking non-existent files or endpoints
  - initialDelaySeconds too short (app not ready yet)
  - Wrong URL/port in HTTP probes
- **Out of Memory (OOMKilled)**
  - Memory limits set too low for application needs
  - Exit code 137 indicates OOMKilled
- **Application Bugs**
  - Unhandled exceptions
  - Segmentation faults
  - Code errors causing immediate exit

**Solution:**
- Check logs: `kubectl logs <pod> --previous`
- Fix liveness probe configuration (increase initialDelaySeconds, fix paths)
- Increase memory limits in resource specifications
- Debug application code for bugs

**Diagnosis:**
- `kubectl describe pod <name>` - check restart count and exit codes
- `kubectl logs <pod> --previous` - view logs from crashed container

---

## 03-Pods-Not-Schedulable
**Problem:** Pods remain in Pending state, unable to be scheduled to nodes

**Common Causes:**
- **Node Selector Mismatch**
  - Pod requires node labels that don't exist
  - Simple key-value label matching
- **Node Affinity Rules**
  - Required affinity rules cannot be satisfied
  - More expressive than nodeSelector with operators (In, NotIn, Exists)
  - Two types: requiredDuringScheduling and preferredDuringScheduling
- **Taints on Nodes**
  - Nodes tainted to repel pods
  - Pod lacks matching tolerations
  - Effects: NoSchedule, PreferNoSchedule, NoExecute
- **Resource Constraints**
  - Insufficient CPU/memory available on nodes
  - Pod resource requests exceed node capacity

**Solution:**
- **NodeSelector:** Add required labels to nodes or fix pod nodeSelector
  ```yaml
  nodeSelector:
    disktype: ssd
  ```
- **Node Affinity:** Use for complex scheduling rules
  ```yaml
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: disktype
            operator: In
            values: [ssd]
  ```
- **Tolerations:** Add to pod spec to tolerate node taints
  ```yaml
  tolerations:
  - key: disktype
    operator: Equal
    value: ssd
    effect: NoSchedule
  ```

**Diagnosis:**
- `kubectl describe pod <name>` - check Events for scheduling failures
- `kubectl get nodes --show-labels` - verify node labels
- `kubectl describe node <name>` - check taints and available resources

---

## 04-StatefulSet-PV
**Problem:** StatefulSet pods failing due to Persistent Volume issues

**Key Concepts:**
- **StatefulSets** require stable, persistent storage
- **volumeClaimTemplates** automatically create PVCs for each pod replica
- Each pod gets its own unique PVC (e.g., www-web-0, www-web-1, www-web-2)
- PVCs persist even if pods are deleted

**Common Issues:**
- **No Available PersistentVolumes**
  - PVC remains in Pending state
  - No PV matches PVC requirements (size, access mode, storage class)
- **Storage Class Not Found**
  - Referenced storageClassName doesn't exist
  - No default storage class configured
- **Access Mode Mismatch**
  - PV has ReadWriteOnce but PVC requests ReadWriteMany
- **Volume Still Attached**
  - Previous pod termination didn't cleanly detach volume
  - Pod stuck in terminating state

**Solution:**
- Create PersistentVolumes with matching specifications
- Configure default StorageClass or specify storageClassName
- Ensure access modes match between PV and PVC
- Force delete stuck pods if necessary: `kubectl delete pod <name> --grace-period=0 --force`

**Diagnosis:**
- `kubectl get pvc` - check PVC status
- `kubectl describe pvc <name>` - see binding issues
- `kubectl get pv` - check available PersistentVolumes
- `kubectl get storageclass` - verify storage classes exist

---

## 05-NetworkPolicy
**Problem:** Pod network connectivity issues due to NetworkPolicy restrictions

**Key Concepts:**
- **NetworkPolicies** act as firewall rules for pods
- By default, pods accept traffic from any source
- Once a NetworkPolicy selects a pod, it becomes isolated
- Must explicitly allow desired traffic (whitelist approach)

**Common Issues:**
- **Pod Cannot Receive Traffic**
  - NetworkPolicy blocks ingress but doesn't allow required sources
  - Missing podSelector or namespaceSelector in ingress rules
- **Pod Cannot Send Traffic**
  - Egress rules too restrictive
  - DNS traffic blocked (needs port 53 UDP/TCP allowed)
- **Wrong Label Selectors**
  - podSelector doesn't match intended pods
  - Source pods lack required labels in ingress rules

**Solution:**
- **Allow Ingress Traffic:**
  ```yaml
  apiVersion: networking.k8s.io/v1
  kind: NetworkPolicy
  metadata:
    name: allow-specific-pods
  spec:
    podSelector:
      matchLabels:
        app: database
    policyTypes:
    - Ingress
    ingress:
    - from:
      - podSelector:
          matchLabels:
            role: backend
      ports:
      - protocol: TCP
        port: 3306
  ```
- **Allow Egress (including DNS):**
  ```yaml
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
  ```

**Diagnosis:**
- `kubectl get networkpolicy` - list policies in namespace
- `kubectl describe networkpolicy <name>` - see policy rules
- `kubectl get pods --show-labels` - verify pod labels match selectors
- Test connectivity: `kubectl exec <pod> -- curl <target>`
- Check if NetworkPolicy controller is running (Calico, Cilium, etc.)

---

## Quick Diagnosis Checklist

1. **Pod Status:** `kubectl get pods -o wide`
2. **Detailed Info:** `kubectl describe pod <name>`
3. **Logs:** `kubectl logs <name> [--previous]`
4. **Events:** `kubectl get events --sort-by='.lastTimestamp'`
5. **Node Info:** `kubectl describe node <name>`
6. **Resource Usage:** `kubectl top pods` / `kubectl top nodes`

---

## Real-World Troubleshooting Examples: StatefulSet & PV

Here are 3 common scenarios where storage fails in production.

### 1. The "Wrong Zone" Trap (Cloud/AWS/GCP)
**Scenario:** You request a 100GB EBS volume. The Pod is scheduled in `us-east-1a`, but the Volume is created in `us-east-1b`.
**Symptoms:** Pod stays in `ContainerCreating` forever.
**Events:** `FailedAttachVolume: Volume vol-123 is in us-east-1b, but node is in us-east-1a`.
**Fix:**
- Use **StorageClasses** with `volumeBindingMode: WaitForFirstConsumer`. This forces Kubernetes to wait until the Pod is scheduled (node selected) *before* creating the physical disk.

### 2. The "ReadWriteOnce" Lockout
**Scenario:** You have a Deployment with `replicas: 2` trying to share a single PVC (like a shared filestore).
**Symptoms:** Pod #1 starts fine. Pod #2 stays in `ContainerCreating`.
**Events:** `Multi-Attach error for volume "pvc-x": Volume is already exclusively attached to one node and cannot be attached to another`.
**Fix:**
- **Short term:** Change `accessModes` to `ReadWriteMany` (requires NFS/EFS, standard block storage doesn't support this).
- **Long term:** Use a **StatefulSet** so each pod gets its *own* unique volume.

### 3. The "Ghost Volume" (Stuck Terminating)
**Scenario:** You delete a pod, but it gets stuck in `Terminating`. You check the node and see the volume is still mounted by a zombie process.
**Symptoms:** New pod cannot start because the volume is "in use".
**Fix:**
- **Force Delete Pod:** `kubectl delete pod <pod-name> --grace-period=0 --force`
- **Manual Cleanup:** Log into the node and manually unmount the path (`umount /var/lib/kubelet/...`).

---

## Real-World Troubleshooting Examples: NetworkPolicy

Here are 3 scenarios where invisible firewall rules break apps.

### 1. The "Total Silence" (Implicit Default Deny)
**Scenario:** You add a NetworkPolicy to secure your Database. Suddenly, the API cannot talk to *anything* (DNS fails, external APIs fail).
**Why?** If you create a policy with `policyTypes: [Egress]` but don't list any rules, it defaults to **Blocking Everything**.
**Fix:** Always allow essential system traffic (like DNS):
```yaml
egress:
- to:
  - namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: kube-system
  ports:
  - port: 53
    protocol: UDP
```

### 2. The "Missing Label" (Typos)
**Scenario:** You create a rule allowing traffic from `role: api`. You label your pods `app: api`.
**Symptoms:** Connection Timeout. No logs in the app (traffic never reaches it).
**Fix:**
- Double-check labels: `kubectl get pods --show-labels`.
- Remember: `podSelector` is an **exact match**. It does not warn you if 0 pods match.

### 3. The "One-Way Street" (Ingress vs Egress)
**Scenario:** You allow the API to talk to Redis (Egress Allow). But Redis still blocks the connection.
**Why?** NetworkPolicies are one-way. Allowing the API to *send* (`Egress`) doesn't automatically mean Redis allows the *receipt* (`Ingress`).
**Fix:** You need **two** policies (or a matching rule on both sides):
1. **API Pod:** Needs `Egress` allows -> Redis.
2. **Redis Pod:** Needs `Ingress` allows <- API.

