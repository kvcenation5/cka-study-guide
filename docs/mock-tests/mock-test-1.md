# CKA Mock Test 1

This is your first practice test for the Certified Kubernetes Administrator exam. Read each question carefully and provide the best answer.

## Questions

### Question 1
You have a pod named `webapp` that is stuck in a `CrashLoopBackOff` state. What is the **first** command you should run to investigate this issue?

**Answer:** [Your answer here]

---

### Question 2
You need to scale a deployment named `api-server` from 3 replicas to 5 replicas. Which kubectl command would you use?

**Answer:** [Your answer here]

---

### Question 3
A pod named `database` is running on node `worker-1` and you need to drain that node for maintenance without disrupting other workloads. What command would you run?

**Answer:** [Your answer here]

---

### Question 4
You need to create a new namespace called `production` and set it as the current context's default namespace. What commands would you run?

**Answer:** [Your answer here]

---

### Question 5
A service named `frontend` is not accessible from within the cluster. The service exists but endpoints are empty. What is the most likely cause?

**Answer:** [Your answer here]

---

### Question 6
You need to check the resource usage (CPU and memory) of all pods in the `default` namespace. What kubectl command would you use?

**Answer:** [Your answer here]

---

### Question 7
A pod is stuck in `Pending` state. Which command would help you identify why the pod cannot be scheduled?

**Answer:** [Your answer here]

---

### Question 8
You need to create a ConfigMap named `app-config` with the following key-value pairs:
- `DATABASE_URL=mysql://localhost:3306/myapp`
- `LOG_LEVEL=info`

What command would you use?

**Answer:** [Your answer here]

---

### Question 9
You need to check the logs of a pod named `web-server` in the `production` namespace from the last hour. What command would you use?

**Answer:** [Your answer here]

---

### Question 10
A deployment is not rolling out the new replica set. The deployment status shows `ProgressDeadlineExceeded`. What would be your first troubleshooting step?

**Answer:** [Your answer here]

---

## Instructions

1. **Answer each question** in the provided [Answer] sections
2. **Be specific** with your commands and explanations
3. **Think through** the steps before providing your answer
4. **Save** this file when done to review your answers

## Tips

- Use `kubectl --help` if you're unsure about command syntax
- Remember that many kubectl commands have `--dry-run=client -o yaml` flags for testing
- Consider the context of each scenario (production vs development)
- Think about the most efficient approach for each task

---

### Question 11 (Advanced)
Create a Pod `mc-pod` in the `mc-namespace` namespace with three containers:
- **Container 1**: Name `mc-pod-1`, run `nginx:1-alpine`, set environment variable `NODE_NAME` to the node name
- **Container 2**: Name `mc-pod-2`, run `busybox:1`, continuously log date output to `/var/log/shared/date.log` every second
- **Container 3**: Name `mc-pod-3`, run `busybox:1`, print contents of `date.log` file to stdout
- **Requirement**: Use a shared, non-persistent volume

**Answer:**
```bash
cat > mc-pod.yaml << EOF
apiVersion: v1
kind: Pod
metadata:
  name: mc-pod
  namespace: mc-namespace
spec:
  containers:
  - name: mc-pod-1
    image: nginx:1-alpine
    env:
    - name: NODE_NAME
      valueFrom:
        fieldRef:
          fieldPath: spec.nodeName
  - name: mc-pod-2
    image: busybox:1
    command: ["/bin/sh", "-c"]
    args:
    - |
      while true; do
        date >> /var/log/shared/date.log
        sleep 1
      done
    volumeMounts:
    - name: shared-logs
      mountPath: /var/log/shared
  - name: mc-pod-3
    image: busybox:1
    command: ["/bin/sh", "-c"]
    args:
    - |
      while true; do
        cat /var/log/shared/date.log
        sleep 2
      done
    volumeMounts:
    - name: shared-logs
      mountPath: /var/log/shared
  volumes:
  - name: shared-logs
    emptyDir: {}
EOF

# Test with dry-run
kubectl apply -f mc-pod.yaml --dry-run=client -o yaml
```

---

## Practical CKA Exam Questions

### Question 12: Container Runtime Installation
**Scenario**: Prepare node01 for Kubernetes installation by installing a container runtime.

**Task**: Install the cri-docker_0.3.16.3-0.debian.deb package located in /root and ensure that the cri-docker service is running and enabled to start on boot.

**SSH Credentials**: username: bob, password: caleston123

**Answer**:
```bash
# SSH to node01
ssh bob@node01

# Switch to root
sudo -i

# Install the package
dpkg -i /root/cri-docker_0.3.16.3-0.debian.deb

# Start and enable the service
systemctl start cri-docker
systemctl enable cri-docker

# Verify
systemctl status cri-docker
systemctl is-enabled cri-docker
```

---

### Question 13: Find CRDs
**Scenario**: On controlplane node, identify all CRDs related to VerticalPodAutoscaler.

**Task**: Save their names into the file /root/vpa-crds.txt.

**Answer**:
```bash
# Find VPA-related CRDs
kubectl get crd | grep -i verticalpodautoscaler | awk '{print $1}' > /root/vpa-crds.txt

# Verify
cat /root/vpa-crds.txt
```

---

### Question 14: Create Service
**Scenario**: Expose the messaging pod within the cluster on port 6379.

**Task**: Create a service named messaging-service for the messaging pod running in the default namespace.

**Answer**:
```bash
kubectl expose pod messaging --name=messaging-service --port=6379 --target-port=6379 --namespace=default

# Verify
kubectl get service messaging-service
kubectl get endpoints messaging-service
```

---

### Question 15: Create NodePort Service
**Scenario**: Expose hr-web-app deployment externally via NodePort.

**Task**: Create a service named hr-web-app-service accessible on port 30082 on all cluster nodes. The web application listens on port 8080.

**Answer**:
```bash
kubectl expose deployment hr-web-app --name=hr-web-app-service --port=8080 --target-port=8080 --type=NodePort

# Edit to set specific node-port
kubectl edit service hr-web-app-service
# Add: nodePort: 30082

# Alternative: Use patch
kubectl patch service hr-web-app-service --type='merge' -p '{"spec":{"ports":[{"nodePort":30082,"port":8080,"protocol":"TCP","targetPort":8080}]}}'
```

---

### Question 16: Create PersistentVolume
**Task**: Create a Persistent Volume with these specifications:
- Volume name: pv-analytics
- Storage: 100Mi
- Access mode: ReadWriteMany
- Host path: /pv/data-analytics

**Answer**:
```bash
cat > pv-analytics.yaml << EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-analytics
spec:
  capacity:
    storage: 100Mi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /pv/data-analytics
EOF

kubectl apply -f pv-analytics.yaml
```

---

### Question 17: Create HPA
**Task**: Create a Horizontal Pod Autoscaler (HPA) with name webapp-hpa for deployment kkapp-deploy with:
- Target CPU utilization: 50%
- Scale-down stabilization window: 300 seconds
- Min replicas: 1, Max replicas: 10

**Answer**:
```bash
cat > webapp-hpa.yaml << EOF
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: webapp-hpa
  namespace: default
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: kkapp-deploy
  minReplicas: 1
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
EOF

kubectl apply -f webapp-hpa.yaml
```

---

### Question 18: Create VPA
**Task**: Deploy a Vertical Pod Autoscaler (VPA) with name analytics-vpa for deployment analytics-deployment in Recreate mode.

**Answer**:
```bash
cat > analytics-vpa.yaml << EOF
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: analytics-vpa
  namespace: default
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: analytics-deployment
  updatePolicy:
    updateMode: "Recreate"
EOF

kubectl apply -f analytics-vpa.yaml
```

---

### Question 19: Helm Chart Upgrade
**Scenario**: A co-worker deployed nginx helm chart kk-mock1 in kk-ns namespace. A new update is available.

**Task**: Update helm repository and upgrade the chart to version 18.1.15.

**Answer**:
```bash
# Update repository
helm repo update

# Check current deployment
helm list -n kk-ns

# Upgrade to specific version
helm upgrade kk-mock1 kk-mock1/nginx --version 18.1.15 -n kk-ns

# Verify
helm list -n kk-ns
kubectl get deployments -n kk-ns
kubectl get pods -n kk-ns
```

---

### Question 20: Create Kubernetes Gateway
**Task**: Create a Kubernetes Gateway resource with these specifications:
- Name: web-gateway
- Namespace: nginx-gateway
- Gateway Class Name: nginx
- Listeners: Protocol HTTP, Port 80, Name http

**Answer**:
```bash
kubectl create -n nginx-gateway -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: web-gateway
  namespace: nginx-gateway
spec:
  gatewayClassName: nginx
  listeners:
    - name: http
      protocol: HTTP
      port: 80
EOF

# Verify
kubectl get gateway web-gateway -n nginx-gateway
kubectl describe gateway web-gateway -n nginx-gateway
```

---

*Good luck with your practice!*
