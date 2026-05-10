# Lab 5: Challenges

## Objective

Test your understanding with hands-on challenges. Solutions are hidden - try to solve them yourself first!

---

## Challenge 1: Create a Frontend-Backend Architecture

**Scenario:**

Deploy a frontend service in mesh1 that calls a backend service. The backend should be available in both clusters.

**Requirements:**

- Frontend deployment in mesh1 only (namespace: `app`)
- Backend deployment in BOTH clusters (namespace: `app`)
- Frontend should be able to reach backend via service name
- Scale backend to 0 in mesh1 - frontend should still work

**Hints:**

- Use nginx as frontend, configure it to proxy to backend
- Use `hashicorp/http-echo` for backend
- Remember the global service annotation

??? success "Solution"
    **mesh2 (backend only):**
    ```bash
    kubectl config use-context kind-mesh2
    kubectl create namespace app

    kubectl apply -n app -f - <<EOF
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: backend
    spec:
      replicas: 2
      selector:
        matchLabels:
          app: backend
      template:
        metadata:
          labels:
            app: backend
        spec:
          containers:
          - name: backend
            image: hashicorp/http-echo
            args: ["-text=MESH2-BACKEND", "-listen=:8080"]
            ports:
            - containerPort: 8080
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: backend
      annotations:
        service.cilium.io/global: "true"
    spec:
      selector:
        app: backend
      ports:
      - port: 8080
    EOF
    ```

    **mesh1 (frontend + backend):**
    ```bash
    kubectl config use-context kind-mesh1
    kubectl create namespace app

    # Backend
    kubectl apply -n app -f - <<EOF
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: backend
    spec:
      replicas: 2
      selector:
        matchLabels:
          app: backend
      template:
        metadata:
          labels:
            app: backend
        spec:
          containers:
          - name: backend
            image: hashicorp/http-echo
            args: ["-text=MESH1-BACKEND", "-listen=:8080"]
            ports:
            - containerPort: 8080
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: backend
      annotations:
        service.cilium.io/global: "true"
    spec:
      selector:
        app: backend
      ports:
      - port: 8080
    EOF

    # Frontend (nginx reverse proxy)
    kubectl apply -n app -f - <<EOF
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: nginx-config
    data:
      default.conf: |
        server {
          listen 80;
          location / {
            proxy_pass http://backend:8080;
          }
        }
    ---
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: frontend
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: frontend
      template:
        metadata:
          labels:
            app: frontend
        spec:
          containers:
          - name: nginx
            image: nginx:alpine
            ports:
            - containerPort: 80
            volumeMounts:
            - name: config
              mountPath: /etc/nginx/conf.d
          volumes:
          - name: config
            configMap:
              name: nginx-config
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: frontend
    spec:
      selector:
        app: frontend
      ports:
      - port: 80
    EOF
    ```

    **Test:**
    ```bash
    kubectl run test --image=curlimages/curl -n app --rm -it -- curl frontend
    ```

    **Test failover:**
    ```bash
    kubectl scale deployment backend --replicas=0 -n app --context kind-mesh1
    kubectl run test --image=curlimages/curl -n app --rm -it -- curl frontend
    # Should show MESH2-BACKEND
    ```

---

## Challenge 2: Debug a Broken Global Service

**Scenario:**

A global service isn't working. The service exists in both clusters but cross-cluster calls fail.

**Setup the broken state:**

```bash
# Cluster 1
kubectl config use-context kind-mesh1
kubectl create namespace broken
kubectl apply -n broken -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: svc-a
spec:
  replicas: 1
  selector:
    matchLabels:
      app: svc-a
  template:
    metadata:
      labels:
        app: svc-a
    spec:
      containers:
      - name: app
        image: hashicorp/http-echo
        args: ["-text=CLUSTER1", "-listen=:8080"]
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: svc-a
  annotations:
    service.cilium.io/global: "true"
spec:
  selector:
    app: svc-a
  ports:
  - port: 8080
EOF

# Cluster 2 - INTENTIONALLY BROKEN
kubectl config use-context kind-mesh2
kubectl create namespace production  # Wrong namespace!
kubectl apply -n production -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: svc-a
spec:
  replicas: 1
  selector:
    matchLabels:
      app: svc-a
  template:
    metadata:
      labels:
        app: svc-a
    spec:
      containers:
      - name: app
        image: hashicorp/http-echo
        args: ["-text=CLUSTER2", "-listen=:8080"]
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: svc-a
spec:
  selector:
    app: svc-a
  ports:
  - port: 8080
EOF
```

**Your task:**

1. Identify why cross-cluster isn't working
2. Fix it so that calling svc-a from mesh1 can reach mesh2's backend

??? success "Solution"
    **Problem 1:** Service is in different namespaces (`broken` vs `production`)

    **Problem 2:** mesh2's service is missing the global annotation

    **Fix:**
    ```bash
    kubectl config use-context kind-mesh2
    kubectl delete namespace production
    kubectl create namespace broken
    kubectl apply -n broken -f - <<EOF
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: svc-a
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: svc-a
      template:
        metadata:
          labels:
            app: svc-a
        spec:
          containers:
          - name: app
            image: hashicorp/http-echo
            args: ["-text=CLUSTER2", "-listen=:8080"]
            ports:
            - containerPort: 8080
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: svc-a
      annotations:
        service.cilium.io/global: "true"
    spec:
      selector:
        app: svc-a
      ports:
      - port: 8080
    EOF
    ```

    **Verify:**
    ```bash
    kubectl run test --image=curlimages/curl -n broken --rm -it --context kind-mesh1 -- sh -c 'for i in 1 2 3 4 5; do curl -s svc-a:8080; done'
    ```

---

## Challenge 3: Implement Disaster Recovery

**Scenario:**

Create a DR setup where:

- Primary cluster (mesh1) handles all traffic normally
- DR cluster (mesh2) only receives traffic when mesh1 is down
- mesh2 should NOT receive traffic when mesh1 is healthy

**Hints:**

- Think about which cluster should share its backends
- Look at `service.cilium.io/shared` annotation

??? success "Solution"
    The key is that mesh2 should NOT advertise its backends globally while mesh1 is up.

    **mesh1 (Primary) - Shares backends globally:**
    ```bash
    kubectl config use-context kind-mesh1
    kubectl create namespace dr-demo
    kubectl apply -n dr-demo -f - <<EOF
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: api
    spec:
      replicas: 2
      selector:
        matchLabels:
          app: api
      template:
        metadata:
          labels:
            app: api
        spec:
          containers:
          - name: api
            image: hashicorp/http-echo
            args: ["-text=PRIMARY-CLUSTER", "-listen=:8080"]
            ports:
            - containerPort: 8080
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: api
      annotations:
        service.cilium.io/global: "true"
    spec:
      selector:
        app: api
      ports:
      - port: 8080
    EOF
    ```

    **mesh2 (DR) - Does NOT share backends:**
    ```bash
    kubectl config use-context kind-mesh2
    kubectl create namespace dr-demo
    kubectl apply -n dr-demo -f - <<EOF
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: api
    spec:
      replicas: 2
      selector:
        matchLabels:
          app: api
      template:
        metadata:
          labels:
            app: api
        spec:
          containers:
          - name: api
            image: hashicorp/http-echo
            args: ["-text=DR-CLUSTER", "-listen=:8080"]
            ports:
            - containerPort: 8080
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: api
      annotations:
        service.cilium.io/global: "true"
        service.cilium.io/shared: "false"
    spec:
      selector:
        app: api
      ports:
      - port: 8080
    EOF
    ```

    The `shared: "false"` means mesh2's backends are NOT advertised to other clusters, but mesh2 CAN access remote backends (from mesh1).

    **Test from mesh2 (should only hit PRIMARY):**
    ```bash
    kubectl run test --image=curlimages/curl -n dr-demo --rm -it --context kind-mesh2 -- sh -c 'for i in 1 2 3 4 5; do curl -s api:8080; done'
    # All responses: PRIMARY-CLUSTER
    ```

    **Simulate primary failure:**
    ```bash
    kubectl scale deployment api --replicas=0 -n dr-demo --context kind-mesh1
    ```

    **Test again (should hit DR):**
    ```bash
    kubectl run test --image=curlimages/curl -n dr-demo --rm -it --context kind-mesh2 -- sh -c 'for i in 1 2 3 4 5; do curl -s api:8080; done'
    # All responses: DR-CLUSTER
    ```

---

## Challenge 4: Add a Third Cluster

**Scenario:**

Add a third cluster (mesh3) to the existing mesh.

**Requirements:**

1. Create cluster mesh3 with appropriate CIDR (10.3.0.0/16, 172.20.3.0/24)
2. Install Cilium with cluster.id=3
3. Connect to the existing mesh
4. Verify all three clusters can communicate

??? success "Solution"
    ```bash
    # Create cluster config
    cat > /tmp/mesh3-config.yaml << 'EOF'
    kind: Cluster
    apiVersion: kind.x-k8s.io/v1alpha4
    name: mesh3
    networking:
      disableDefaultCNI: true
      podSubnet: "10.3.0.0/16"
      serviceSubnet: "172.20.3.0/24"
    nodes:
      - role: control-plane
      - role: worker
    EOF

    # Create cluster
    kind create cluster --config /tmp/mesh3-config.yaml

    # Install Cilium
    cilium install --context kind-mesh3 \
      --set cluster.id=3 \
      --set cluster.name=mesh3 \
      --set ipam.mode=kubernetes

    cilium status --wait --context kind-mesh3

    # Enable Cluster Mesh
    cilium clustermesh enable --context kind-mesh3 --service-type NodePort
    cilium clustermesh status --wait --context kind-mesh3

    # Connect to existing mesh (connect to both existing clusters)
    cilium clustermesh connect --context kind-mesh1 --destination-context kind-mesh3
    cilium clustermesh connect --context kind-mesh2 --destination-context kind-mesh3

    # Verify
    cilium clustermesh status --context kind-mesh1  # Should show mesh2 and mesh3
    cilium clustermesh status --context kind-mesh2  # Should show mesh1 and mesh3
    cilium clustermesh status --context kind-mesh3  # Should show mesh1 and mesh2
    ```

---

## Challenge 5: Network Policy Across Clusters

**Scenario:**

Create a network policy that allows frontend pods to reach backend, but blocks all other cross-cluster traffic.

**Requirements:**

- Frontend in mesh1 can reach backend in mesh2
- Random pods in mesh1 CANNOT reach backend in mesh2
- Use CiliumNetworkPolicy (not standard NetworkPolicy)

??? success "Solution"
    **Deploy backend in mesh2:**
    ```bash
    kubectl config use-context kind-mesh2
    kubectl create namespace secure
    kubectl apply -n secure -f - <<EOF
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: backend
    spec:
      replicas: 2
      selector:
        matchLabels:
          app: backend
      template:
        metadata:
          labels:
            app: backend
        spec:
          containers:
          - name: backend
            image: hashicorp/http-echo
            args: ["-text=SECURE-BACKEND", "-listen=:8080"]
            ports:
            - containerPort: 8080
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: backend
      annotations:
        service.cilium.io/global: "true"
    spec:
      selector:
        app: backend
      ports:
      - port: 8080
    EOF
    ```

    **Deploy frontend in mesh1:**
    ```bash
    kubectl config use-context kind-mesh1
    kubectl create namespace secure
    kubectl apply -n secure -f - <<EOF
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: frontend
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: frontend
      template:
        metadata:
          labels:
            app: frontend
        spec:
          containers:
          - name: frontend
            image: curlimages/curl
            command: [sleep, "3600"]
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: backend
      annotations:
        service.cilium.io/global: "true"
    spec:
      selector:
        app: backend
      ports:
      - port: 8080
    EOF
    ```

    **Apply CiliumNetworkPolicy on mesh2:**
    ```bash
    kubectl config use-context kind-mesh2
    kubectl apply -n secure -f - <<EOF
    apiVersion: cilium.io/v2
    kind: CiliumNetworkPolicy
    metadata:
      name: backend-policy
    spec:
      endpointSelector:
        matchLabels:
          app: backend
      ingress:
      - fromEndpoints:
        - matchLabels:
            app: frontend
        toPorts:
        - ports:
          - port: "8080"
            protocol: TCP
    EOF
    ```

    **Test (from frontend - should work):**
    ```bash
    kubectl config use-context kind-mesh1
    FRONTEND_POD=$(kubectl get pod -n secure -l app=frontend -o jsonpath='{.items[0].metadata.name}')
    kubectl exec -n secure $FRONTEND_POD -- curl -s backend:8080
    # Should work: SECURE-BACKEND
    ```

    **Test (from random pod - should fail):**
    ```bash
    kubectl run hacker --image=curlimages/curl -n secure --rm -it -- curl -s --connect-timeout 5 backend:8080
    # Should timeout or be blocked
    ```

---

## Final Challenge: Full Clean Up

**Task:** Remove everything you created and tear down all clusters.

```bash
# Delete all test namespaces
kubectl delete namespace app broken dr-demo secure --context kind-mesh1 --ignore-not-found
kubectl delete namespace app broken dr-demo secure --context kind-mesh2 --ignore-not-found
kubectl delete namespace app broken dr-demo secure --context kind-mesh3 --ignore-not-found

# Delete clusters
kind delete cluster --name mesh1
kind delete cluster --name mesh2
kind delete cluster --name mesh3

# Clean up temp files
rm -f /tmp/mesh1-config.yaml /tmp/mesh2-config.yaml /tmp/mesh3-config.yaml
```

---

## Congratulations!

You've completed the Cilium Cluster Mesh lab series. You now understand:

- Multi-cluster KinD setup with custom CIDRs
- Cilium CNI installation and verification
- Cluster Mesh architecture and connectivity
- Global services and cross-cluster load balancing
- Service affinity and failover patterns
- Cross-cluster network policies

**Next steps:**

- Try Hubble (Cilium's observability layer): `cilium hubble enable`
- Explore L7 network policies (HTTP-aware rules)
- Set up on real cloud clusters (EKS, GKE, AKS)
- Integrate with service meshes (Istio + Cilium)
