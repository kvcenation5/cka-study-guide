# CKA Mock Test 2

This is your second practice test for the Certified Kubernetes Administrator exam.

## Questions

### Question 1: Create User with CSR and RBAC Role
**Scenario**: Create a new user "john" with certificate-based authentication and grant specific permissions.

**Given**:
- Private key: `/root/CKA/john.key`
- CSR file: `/root/CKA/john.csr`

**Task**:
1. Create a CertificateSigningRequest (CSR) named `john-developer` for user john
2. Approve the CSR
3. Create a Role named `developer` in `development` namespace
4. Grant permissions: create, list, get, update, delete pods
5. Create RoleBinding to bind john to the developer role

**Note**: As of kubernetes 1.19, the CertificateSigningRequest object expects a signerName.

**Answer**:
```bash
# Step 1: Create the CSR
# Read the CSR file and encode it in base64
CSR=$(cat /root/CKA/john.csr | base64 | tr -d '\n')

# Create the CertificateSigningRequest
kubectl create -f - <<EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: john-developer
spec:
  request: $CSR
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - client auth
  expirationSeconds: 86400
EOF

# Step 2: Approve the CSR
kubectl certificate approve john-developer

# Step 3: Extract the signed certificate (optional - for john's kubeconfig)
kubectl get csr john-developer -o jsonpath='{.status.certificate}' | base64 -d > /root/CKA/john.crt

# Step 4: Ensure development namespace exists
kubectl create namespace development --dry-run=client -o yaml | kubectl apply -f -

# Step 5: Create the developer role
kubectl create role developer \
  --verb=create,list,get,update,delete \
  --resource=pods \
  -n development

# Step 6: Create RoleBinding for john
kubectl create rolebinding john-developer-binding \
  --role=developer \
  --user=john \
  -n development
```

**Verification Commands**:
```bash
# Check CSR status
kubectl get csr john-developer
# Expected: Approved,Issued

# Check Role
kubectl get role developer -n development
kubectl describe role developer -n development

# Check RoleBinding
kubectl get rolebinding john-developer-binding -n development

# Test john's permissions
kubectl auth can-i create pods --as=john -n development
kubectl auth can-i list pods --as=john -n development
kubectl auth can-i get pods --as=john -n development
kubectl auth can-i update pods --as=john -n development
kubectl auth can-i delete pods --as=john -n development
# All should return: yes
```

**Verification Checklist**:
- ✅ CSR john-developer created and Approved
- ✅ Role developer created in development namespace
- ✅ Role has permissions: create, list, get, update, delete pods
- ✅ RoleBinding connects user john to developer role
- ✅ User john has appropriate permissions in development namespace

---

### Question 2: DNS Resolution and Network Troubleshooting
**Task**: Create an nginx pod and verify DNS resolution and network reachability.

**Requirements**:
1. Create an nginx pod named `nginx-resolver` using the nginx image
2. Expose it internally using a ClusterIP service called `nginx-resolver-service`
3. Verify DNS resolution of the service name
4. Verify network reachability of the pod using its IP address
5. Use busybox:1.28 image to perform the lookups

**Output Files**:
- Save service DNS lookup to: `/root/CKA/nginx.svc`
- Save pod IP lookup to: `/root/CKA/nginx.pod`

**Answer**:
```bash
# Step 1: Create the nginx pod
kubectl run nginx-resolver --image=nginx

# Step 2: Create ClusterIP service
kubectl expose pod nginx-resolver --name=nginx-resolver-service --port=80 --target-port=80

# Step 3: Get pod IP
POD_IP=$(kubectl get pod nginx-resolver -o jsonpath='{.status.podIP}')

# Step 4: Create busybox pod and test DNS
kubectl run busybox-dns --image=busybox:1.28 -- sleep 3600
kubectl wait --for=condition=Ready pod/busybox-dns --timeout=60s

# Step 5: Test service DNS and save
kubectl exec busybox-dns -- nslookup nginx-resolver-service > /root/CKA/nginx.svc

# Step 6: Save pod IP
echo $POD_IP > /root/CKA/nginx.pod

# Clean up
kubectl delete pod busybox-dns
```

**Verification Commands**:
```bash
# Verify pod is running
kubectl get pod nginx-resolver

# Verify service exists
kubectl get service nginx-resolver-service

# Check service endpoints
kubectl get endpoints nginx-resolver-service

# Verify output files
cat /root/CKA/nginx.svc
cat /root/CKA/nginx.pod
```

**Verification Checklist**:
- ✅ Pod nginx-resolver created with nginx image
- ✅ ClusterIP service nginx-resolver-service created
- ✅ Service DNS resolution verified and saved to /root/CKA/nginx.svc
- ✅ Pod IP resolution verified and saved to /root/CKA/nginx.pod
- ✅ busybox:1.28 image used for DNS lookups

---

### Question 3: Create Static Pod
**Scenario**: Create a static pod on node01 that runs independently of the Kubernetes API server and auto-restarts on failure.

**What is a Static Pod?**
- A pod managed directly by the kubelet on a specific node, NOT by the Kubernetes API server
- Defined by manifest files placed in `/etc/kubernetes/manifests` directory
- Automatically recreated if deleted or crashes

**Task**: Create a static pod on node01 called `nginx-critical` with image `nginx`.

**Answer**:
```bash
# SSH to node01
ssh node01

# Create static pod manifest file
sudo tee /etc/kubernetes/manifests/nginx-critical.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: nginx-critical-node01
spec:
  containers:
  - name: nginx
    image: nginx
    ports:
    - containerPort: 80
EOF

# Exit back to controlplane
exit

# Verify from control plane
kubectl get pods -o wide | grep nginx-critical
```

**Verification Commands**:
```bash
# Verify manifest file exists on node01
ssh node01 "sudo ls -la /etc/kubernetes/manifests/nginx-critical.yaml"

# Verify pod is running
kubectl get pod nginx-critical-node01-node01

# Test auto-restart by deleting pod
kubectl delete pod nginx-critical-node01-node01
kubectl get pods | grep nginx-critical  # Should show recreated
```

**Verification Checklist**:
- ✅ Static pod manifest configured under `/etc/kubernetes/manifests`
- ✅ Pod nginx-critical-node01 running on node01
- ✅ Pod auto-restarts when deleted (kubelet manages it)
- ✅ Pod visible via kubectl from control plane

---

### Question 4: Create HPA with Memory Utilization
**Task**: Create a Horizontal Pod Autoscaler that scales based on memory usage.

**Requirements**:
- HPA name: `backend-hpa`
- Target deployment: `backend-deployment` in `backend` namespace
- Metric: Memory utilization at 65% average
- Min replicas: 3, Max replicas: 15
- Save to file: `/root/webapp-hpa.yaml`

**Answer**:
```bash
cat > /root/webapp-hpa.yaml << EOF
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: backend-hpa
  namespace: backend
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: backend-deployment
  minReplicas: 3
  maxReplicas: 15
  metrics:
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 65
EOF

kubectl apply -f /root/webapp-hpa.yaml
```

**Verification Commands**:
```bash
kubectl get hpa backend-hpa -n backend
kubectl describe hpa backend-hpa -n backend
kubectl get hpa backend-hpa -n backend -o yaml | grep -A 5 "metrics:"
```

**Verification Checklist**:
- ✅ HPA backend-hpa deployed in backend namespace
- ✅ Deployment configured for memory utilization (65%)
- ✅ Min replicas: 3, Max replicas: 15
- ✅ HPA saved to /root/webapp-hpa.yaml

---

### Question 5: Gateway API with HTTPS/TLS
**Task**: Modify existing Gateway to handle HTTPS traffic with TLS certificate.

**Requirements**:
- Gateway name: `web-gateway`
- Namespace: `cka5673`
- Hostname: `kodekloud.com`
- Port: 443 (HTTPS)
- TLS certificate from secret: `kodekloud-tls`

**Answer**:
```bash
cat > web-gateway.yaml << EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: web-gateway
  namespace: cka5673
spec:
  gatewayClassName: nginx
  listeners:
  - name: https
    protocol: HTTPS
    port: 443
    hostname: kodekloud.com
    tls:
      mode: Terminate
      certificateRefs:
      - kind: Secret
        name: kodekloud-tls
EOF

kubectl apply -f web-gateway.yaml
```

**Verification Commands**:
```bash
kubectl get gateway web-gateway -n cka5673
kubectl describe gateway web-gateway -n cka5673 | grep -A 10 "Listeners"
kubectl get gateway web-gateway -n cka5673 -o yaml | grep -A 5 "tls:"
```

**Verification Checklist**:
- ✅ Gateway configured to listen on hostname kodekloud.com
- ✅ HTTPS listener configured on port 443
- ✅ TLS certificate from secret kodekloud-tls attached

---

### Question 6: Find and Uninstall Helm Release with Vulnerable Image
**Task**: Find helm release using vulnerable image and uninstall it.

**Given**:
- Vulnerable image: `kodekloud/webapp-color:v1`

**Answer**:
```bash
# List all helm releases
helm list --all-namespaces

# Find release with vulnerable image
kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.spec.containers[*].image}{"\n"}{end}' | grep kodekloud/webapp-color:v1

# Uninstall the release
helm uninstall <release-name> -n <namespace>
```

**Verification Commands**:
```bash
helm list --all-namespaces | grep <release-name>
kubectl get pods --all-namespaces | grep webapp-color
```

**Verification Checklist**:
- ✅ Helm release with vulnerable image identified
- ✅ Helm release uninstalled
- ✅ No pods with kodekloud/webapp-color:v1 remaining

---

### Question 7: NetworkPolicy - Allow Frontend to Backend, Block Databases
**Task**: Create NetworkPolicy to allow traffic from frontend to backend, but block from databases namespace.

**Answer**:
```bash
cat > /root/correct-policy.yaml << EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-network-policy
  namespace: backend
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: frontend
EOF

kubectl apply -f /root/correct-policy.yaml
```

**Verification Commands**:
```bash
kubectl get networkpolicy -n backend
kubectl describe networkpolicy backend-network-policy -n backend
```

**Verification Checklist**:
- ✅ Correct NetworkPolicy applied to backend namespace
- ✅ Allows traffic from frontend namespace
- ✅ Blocks traffic from databases namespace

---

### Question 8: Create StorageClass with Default Setting
**Task**: Create a StorageClass named local-sc with specific settings.

**Requirements**:
- Provisioner: kubernetes.io/no-provisioner
- Volume binding mode: WaitForFirstConsumer
- Volume expansion: enabled
- Mark as default storage class

**Answer**:
```bash
kubectl create -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-sc
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
EOF
```

**Verification Commands**:
```bash
kubectl get storageclass local-sc
kubectl get storageclass  # Check for (default) marker
```

**Verification Checklist**:
- ✅ StorageClass local-sc created
- ✅ Provisioner is kubernetes.io/no-provisioner
- ✅ Volume binding mode is WaitForFirstConsumer
- ✅ Volume expansion is enabled
- ✅ Set as default storage class

---

### Question 9: Deployment with Sidecar Container
**Task**: Create deployment with sidecar for log aggregation.

**Main Container**:
- Image: busybox
- Command: `sh -c "while true; do echo 'Log entry' >> /var/log/app/app.log; sleep 5; done"`

**Sidecar Container** (log-agent):
- Image: busybox
- Command: `tail -f /var/log/app/app.log`

**Answer**:
```bash
kubectl create namespace logging-ns

cat > logging-deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: logging-deployment
  namespace: logging-ns
spec:
  replicas: 1
  selector:
    matchLabels:
      app: logging
  template:
    metadata:
      labels:
        app: logging
    spec:
      containers:
      - name: app-container
        image: busybox
        command: ["sh", "-c", "while true; do echo 'Log entry' >> /var/log/app/app.log; sleep 5; done"]
        volumeMounts:
        - name: log-volume
          mountPath: /var/log/app
      - name: log-agent
        image: busybox
        command: ["tail", "-f", "/var/log/app/app.log"]
        volumeMounts:
        - name: log-volume
          mountPath: /var/log/app
      volumes:
      - name: log-volume
        emptyDir: {}
EOF

kubectl apply -f logging-deployment.yaml
```

**Verification Commands**:
```bash
kubectl get deployment logging-deployment -n logging-ns
kubectl get pods -n logging-ns
kubectl logs -n logging-ns <pod-name> -c log-agent
```

**Verification Checklist**:
- ✅ Deployment logging-deployment created in logging-ns namespace
- ✅ Main container writes logs to shared volume
- ✅ Sidecar container reads logs from same volume
- ✅ Shared emptyDir volume mounted at /var/log/app

---

### Question 10: View Sidecar Container Logs
**Scenario**: View logs from sidecar container specifically.

**Answer**:
```bash
# View logs from specific sidecar container
kubectl logs <pod-name> -n logging-ns -c log-agent

# Follow logs in real-time
kubectl logs <pod-name> -n logging-ns -c log-agent -f

# View logs from all containers
kubectl logs <pod-name> -n logging-ns --all-containers=true
```

**Verification Checklist**:
- ✅ Can view logs from specific sidecar container using `-c` flag
- ✅ Can follow logs in real-time with `-f` flag

---

### Question 11: Create Ingress Resource
**Task**: Create Ingress for routing traffic to backend service.

**Requirements**:
- Ingress name: webapp-ingress
- Namespace: ingress-ns
- Host: kodekloud-ingress.app
- Path: / with pathType: Prefix
- Backend: webapp-svc:80
- Ingress class: nginx

**Answer**:
```bash
kubectl create -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: webapp-ingress
  namespace: ingress-ns
  annotations:
    kubernetes.io/ingress.class: "nginx"
spec:
  rules:
  - host: kodekloud-ingress.app
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: webapp-svc
            port:
              number: 80
EOF
```

**Verification Commands**:
```bash
kubectl get ingress webapp-ingress -n ingress-ns
curl -s http://kodekloud-ingress.app/
```

**Verification Checklist**:
- ✅ Ingress webapp-ingress created in ingress-ns namespace
- ✅ pathType set to Prefix
- ✅ Backend service webapp-svc on port 80
- ✅ Host configured as kodekloud-ingress.app
- ✅ Ingress class annotation added

---

### Question 12: CSR and RBAC with Extended Verification
**Scenario**: Complete CSR/RBAC workflow with kubectl context setup.

**Given**:
- CSR file: `/root/CKA/john.csr`

**Task**: Create user john with full pod permissions in development namespace.

**Answer**:
```bash
# Create CSR
CSR=$(cat /root/CKA/john.csr | base64 | tr -d '\n')
kubectl create -f - <<EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: john-developer
spec:
  request: $CSR
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - client auth
EOF

# Approve CSR
kubectl certificate approve john-developer

# Extract certificate
kubectl get csr john-developer -o jsonpath='{.status.certificate}' | base64 -d > /root/CKA/john.crt

# Create role and binding
kubectl create role developer --verb=create,list,get,update,delete --resource=pods -n development
kubectl create rolebinding john-developer-binding --role=developer --user=john -n development

# Configure kubectl context for john
kubectl config set-credentials john --client-certificate=/root/CKA/john.crt --client-key=/root/CKA/john.key
kubectl config set-context john-context --cluster=$(kubectl config current-context | cut -d/ -f2) --namespace=development --user=john
```

**Verification Commands**:
```bash
kubectl get csr john-developer
kubectl get role developer -n development
kubectl auth can-i create pods --as=john -n development
kubectl --context=john-context auth can-i delete pods -n development
```

**Verification Checklist**:
- ✅ CSR john-developer created and Approved
- ✅ Role developer created with pod permissions
- ✅ RoleBinding connects user john to developer role
- ✅ kubectl context configured for user john

---

### Question 13: ServiceAccount with ClusterRole for PersistentVolumes
**Scenario**: Create a ServiceAccount with cluster-wide permissions to list PersistentVolumes.

**Requirements**:
- ServiceAccount name: `pvviewer`
- ClusterRole name: `pvviewer-role`
- ClusterRoleBinding name: `pvviewer-role-binding`
- Permission: List all PersistentVolumes (cluster-scoped resource)
- Pod name: `pvviewer`
- Pod image: `redis`
- Pod namespace: `default`
- Pod must use ServiceAccount `pvviewer`

**Answer**:
```bash
# Step 1: Create ServiceAccount
kubectl create serviceaccount pvviewer -n default

# Step 2: Create ClusterRole for listing PersistentVolumes
cat > pvviewer-role.yaml << EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: pvviewer-role
rules:
- apiGroups: [""]
  resources: ["persistentvolumes"]
  verbs: ["list", "get"]
EOF

kubectl apply -f pvviewer-role.yaml

# Step 3: Create ClusterRoleBinding
kubectl create clusterrolebinding pvviewer-role-binding \
  --clusterrole=pvviewer-role \
  --serviceaccount=default:pvviewer

# Step 4: Create pod with ServiceAccount
kubectl run pvviewer --image=redis --serviceaccount=pvviewer -n default
```

**Verification Commands**:
```bash
# Verify ServiceAccount exists
kubectl get serviceaccount pvviewer -n default

# Verify ClusterRole exists
kubectl get clusterrole pvviewer-role
kubectl describe clusterrole pvviewer-role

# Verify ClusterRoleBinding exists
kubectl get clusterrolebinding pvviewer-role-binding
kubectl describe clusterrolebinding pvviewer-role-binding

# Verify pod is using correct ServiceAccount
kubectl get pod pvviewer -n default -o jsonpath='{.spec.serviceAccountName}'
# Should output: pvviewer

# Test permissions from inside pod (optional)
kubectl exec pvviewer -n default -- kubectl get pv
```

**Key Differences from Role/RoleBinding**:
- **ClusterRole**: Cluster-scoped (applies across all namespaces)
- **ClusterRoleBinding**: Binds ClusterRole to subjects cluster-wide
- **Role**: Namespace-scoped (applies only to specific namespace)
- **RoleBinding**: Binds Role to subjects within a namespace

**Verification Checklist**:
- ✅ ServiceAccount pvviewer created in default namespace
- ✅ ClusterRole pvviewer-role created with list/get permissions on PersistentVolumes
- ✅ ClusterRoleBinding pvviewer-role-binding connects SA to ClusterRole
- ✅ Pod pvviewer created with image redis
- ✅ Pod configured to use ServiceAccount pvviewer
- ✅ Pod can list PersistentVolumes

---

### Question 14: ConfigMap with Deployment Environment Variables
**Scenario**: Create a ConfigMap and configure a Deployment to use it for environment variables.

**Task**:
1. Create a ConfigMap named `app-config` in namespace `cm-namespace`
2. Add key-value pairs: `ENV=production` and `LOG_LEVEL=info`
3. Modify the existing Deployment `cm-webapp` to use the ConfigMap
4. Set environment variables `ENV` and `LOG_LEVEL` from the ConfigMap

**Answer**:

**Step 1: Create the ConfigMap**
```bash
# Create ConfigMap with literal values
kubectl create configmap app-config \
  --from-literal=ENV=production \
  --from-literal=LOG_LEVEL=info \
  -n cm-namespace

# Or using YAML
cat > app-config.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: cm-namespace
data:
  ENV: production
  LOG_LEVEL: info
EOF

kubectl apply -f app-config.yaml
```

**Step 2: Modify Deployment to use ConfigMap**

**Method 1: Using kubectl set env (quickest)**
```bash
kubectl set env deployment/cm-webapp \
  --from=configmap/app-config \
  -n cm-namespace
```

**Method 2: Using kubectl edit**
```bash
kubectl edit deployment cm-webapp -n cm-namespace
```

Add under the container spec:
```yaml
envFrom:
- configMapRef:
    name: app-config
```

**Method 3: Patch with YAML**
```bash
cat > patch.yaml << EOF
spec:
  template:
    spec:
      containers:
      - name: webapp
        envFrom:
        - configMapRef:
            name: app-config
EOF

kubectl patch deployment cm-webapp -n cm-namespace --patch-file patch.yaml
```

**Method 4: Specific env var mapping (more control)**
```bash
kubectl set env deployment/cm-webapp \
  ENV=production \
  LOG_LEVEL=info \
  -n cm-namespace
```

Or from ConfigMap specifically:
```bash
kubectl set env deployment/cm-webapp \
  --from=configmap/app-config \
  -n cm-namespace
```

**Verification Commands**:
```bash
# Verify ConfigMap exists with correct data
kubectl get configmap app-config -n cm-namespace -o yaml

# Check ConfigMap keys
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: config-test
  namespace: cm-namespace
spec:
  containers:
  - name: test
    image: busybox
    command: ['sh', '-c', 'env && sleep 3600']
    envFrom:
    - configMapRef:
        name: app-config
EOF

# Check environment variables in pod
kubectl exec config-test -n cm-namespace -- env | grep -E 'ENV|LOG_LEVEL'

# Verify Deployment uses ConfigMap
kubectl get deployment cm-webapp -n cm-namespace -o yaml | grep -A 10 "envFrom:"

# Check running pods have env vars
kubectl exec -it deployment/cm-webapp -n cm-namespace -- env | grep -E 'ENV|LOG_LEVEL'

# Clean up test pod
kubectl delete pod config-test -n cm-namespace
```

**Key Concepts**:
- `envFrom`: Injects all key-value pairs from ConfigMap as env vars
- `env`: Can reference specific ConfigMap keys or set literal values
- ConfigMaps can be mounted as files (volumes) or injected as env vars
- Changes to ConfigMap don't automatically restart pods; need to trigger rollout

**Verification Checklist**:
- ✅ ConfigMap app-config created in cm-namespace
- ✅ ConfigMap has ENV=production
- ✅ ConfigMap has LOG_LEVEL=info
- ✅ Deployment cm-webapp uses ConfigMap for environment variables
- ✅ Environment variables reflected in deployment pods
- ✅ Pod can access ENV and LOG_LEVEL from ConfigMap

---

### Question 15: Create and Assign PriorityClass
**Scenario**: Create a PriorityClass and assign it to an existing pod.

**Requirements**:
- PriorityClass name: `low-priority`
- PriorityClass value: `50000`
- Pod name: `lp-pod` in namespace `low-priority`
- Assign the PriorityClass to the pod

**Note**: PriorityClass is immutable on a pod. You must delete and recreate the pod.

**Answer**:

**Step 1: Create PriorityClass**
```bash
# Create PriorityClass with value 50000
kubectl create priorityclass low-priority --value=50000
```

**Step 2: Delete and Recreate Pod with PriorityClass**
```bash
# Save current pod spec
kubectl get pod lp-pod -n low-priority -o yaml > lp-pod-backup.yaml

# Delete existing pod
kubectl delete pod lp-pod -n low-priority

# Recreate with PriorityClass
kubectl run lp-pod --image=nginx -n low-priority \
  --overrides='{"spec":{"priorityClassName":"low-priority"}}'
```

**Verification**:
```bash
kubectl get priorityclass low-priority -o jsonpath='{.value}'
kubectl get pod lp-pod -n low-priority -o jsonpath='{.spec.priorityClassName}'
```

---

### Question 16: NetworkPolicy Allow All Ingress
**Scenario**: A default-deny NetworkPolicy is blocking all ingress. Create a policy to allow traffic to a specific pod.

**Given**:
- Pod: `np-test-1` in `default` namespace
- Service: `np-test-service` in `default` namespace
- Default-deny NetworkPolicy exists (do NOT delete it)

**Task**: Create NetworkPolicy `ingress-to-nptest` that:
- Allows ingress from **all sources** to `np-test-1` pod
- Allows port 80 only
- Does not affect existing default-deny policy

**Answer**:
```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ingress-to-nptest
  namespace: default
spec:
  podSelector:
    matchLabels:
      name: np-test-1
  policyTypes:
  - Ingress
  ingress:
  - from: []  # Empty = allow from ALL sources
    ports:
    - protocol: TCP
      port: 80
EOF
```

**Key Points**:
- `from: []` allows traffic from all sources (no restrictions)
- Only targets pod with label `name: np-test-1`
- Only allows port 80 TCP
- Coexists with default-deny (this policy takes precedence for the selected pod)

**Verification**:
```bash
kubectl get networkpolicy ingress-to-nptest -n default
kubectl describe networkpolicy ingress-to-nptest -n default

# Test connectivity
curl http://<np-test-service-ip>:80
```

**Verification Checklist**:
- ✅ NetworkPolicy ingress-to-nptest created
- ✅ Allows ingress from all sources (not restricted)
- ✅ Applied to correct pod (np-test-1)
- ✅ Port is 80 (correct)
- ✅ Default-deny policy still exists
- ✅ Traffic to np-test-1 is now reachable on port 80

---

*Good luck with your practice!*
