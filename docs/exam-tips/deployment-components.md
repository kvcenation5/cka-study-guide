# Minimum Components for a Deployment on Kubernetes Cluster

## Overview

This guide explains the **minimum components** needed to create and run a deployment on a Kubernetes cluster. Understanding these essential building blocks will help you deploy applications efficiently without unnecessary complexity.

---

## The Minimum Components

To run a deployment on Kubernetes, you need to understand these **essential building blocks**. We'll start with the absolute minimum and build up to recommended configurations.

### Quick Summary: What Do You Actually Need?

| Scenario | Required Components | Result |
|----------|-------------------|---------|
| **Absolute Minimum** | Deployment only | Pods run, but no network access |
| **Practical Minimum** | Deployment + Service | Running app with network access |
| **Recommended Minimum** | Namespace + Deployment + Service | Organized, accessible app |
| **Production Ready** | Namespace + Deployment + Service + HPA | Auto-scaling production app |

---

## 1. Namespace (Optional but Recommended)

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: autoscale
```

### What it does

- Logical separation/grouping of resources
- Isolation between different apps/teams
- Not strictly required (can use `default` namespace)

### Why you need it

- **Organization**: Keep related resources together
- **Access control**: Apply RBAC policies per namespace
- **Resource quotas**: Limit resource usage per namespace

!!! tip
    While not required, using namespaces is a best practice for organizing your applications, especially in multi-team environments.

---

## 2. Deployment (REQUIRED - Core Component)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: apache-server
  namespace: autoscale
spec:
  replicas: 1
  selector:
    matchLabels:
      app: apache-server
  template:
    metadata:
      labels:
        app: apache-server
    spec:
      containers:
      - name: apache-server
        image: httpd:latest
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
```

### What it does

- Creates and manages **Pods** (running containers)
- Ensures desired number of replicas are running
- Handles updates and rollbacks
- Self-healing (restarts failed pods)

### Why you need it

!!! warning
    Without this, you have no running application! The Deployment is the core component that actually runs your containerized application.

---

## 3. Service (Required for Networking)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: apache-server
  namespace: autoscale
spec:
  selector:
    app: apache-server
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
```

### What it does

- Provides stable network endpoint to access pods
- Load balances between multiple pod replicas
- Gives pods a DNS name (`apache-server.autoscale.svc.cluster.local`)

### Why you need it

- Pods have dynamic IPs that change when they restart
- Service provides a stable way to reach your app
- Enables load balancing across multiple replicas

### Service Types

| Type | Description | Use Case |
|------|-------------|----------|
| `ClusterIP` | Internal only (default) | Internal microservices |
| `NodePort` | Exposes on node's IP | Development/testing |
| `LoadBalancer` | Cloud load balancer | Production external access |
| `ExternalName` | DNS alias | External service integration |

---

## 4. HPA - Horizontal Pod Autoscaler (Optional - for Autoscaling)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: apache-server
  namespace: autoscale
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: apache-server
  minReplicas: 1
  maxReplicas: 4
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
```

### What it does

- Automatically scales pods based on CPU/memory
- Increases replicas under load
- Decreases replicas when idle

### Why you need it

- Only if you want autoscaling
- Requires metrics-server to be installed in cluster

!!! info "Prerequisites"
    For HPA to work, you must have:
    
    1. Metrics Server installed in your cluster
    2. Resource requests defined in your Deployment

---

## Component Hierarchy

```
Namespace (autoscale)
  └── Deployment (apache-server)
        ├── ReplicaSet (created automatically)
        │     ├── Pod 1 (apache container)
        │     └── Pod 2 (if scaled)
        │
        ├── Service (apache-server)
        │     └── Exposes pods via stable IP/DNS
        │
        └── HPA (apache-server) [optional]
              └── Watches and scales deployment
```

---

## Minimum Configurations

### Absolute Minimum (1 Component)

Just a Deployment - bare minimum to run an application:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: apache-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: apache-server
  template:
    metadata:
      labels:
        app: apache-server
    spec:
      containers:
      - name: apache-server
        image: httpd:latest
```

**This alone will:**

- ✅ Create pods
- ✅ Keep them running
- ❌ But you can't access them easily (no Service)
- ❌ No autoscaling (no HPA)

---

### Practical Minimum (2 Components)

Deployment + Service for a working, accessible application:

```yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: apache-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: apache-server
  template:
    metadata:
      labels:
        app: apache-server
    spec:
      containers:
      - name: apache-server
        image: httpd:latest
        ports:
        - containerPort: 80

---
apiVersion: v1
kind: Service
metadata:
  name: apache-server
spec:
  selector:
    app: apache-server
  ports:
  - port: 80
    targetPort: 80
```

**This gives you:**

- ✅ Running pods
- ✅ Network access to pods
- ✅ Load balancing
- ❌ No autoscaling

---

### Production Ready (All 4 Components)

For production deployments, include all components:

1. **Namespace** - Organization
2. **Deployment** - Runs the app
3. **Service** - Provides access
4. **HPA** - Handles scaling

---

## Component Roles Summary

| Component | Purpose | Required? | What Happens Without It |
|-----------|---------|-----------|------------------------|
| **Namespace** | Organization/isolation | No (uses `default`) | Everything goes in `default` namespace |
| **Deployment** | Runs containers | **YES** | No application running! |
| **Service** | Network access | Recommended | Can't easily access pods |
| **HPA** | Autoscaling | No | Manual scaling only |
| **ConfigMap** | Configuration data | No | Hard-code configs in container |
| **Secret** | Sensitive data | No | Hard-code secrets (bad practice!) |
| **PersistentVolume** | Storage | No | Data lost when pod dies |
| **Ingress** | External HTTP access | No | Only internal or NodePort |

---

## Additional Common Components

Beyond the basic components, you may need these for more advanced use cases:

### ConfigMap (for Configuration)

Store non-sensitive configuration data:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: apache-config
  namespace: autoscale
data:
  httpd.conf: |
    ServerName localhost
    Listen 80
```

**Use Case:** Application configuration files, environment variables

---

### Secret (for Passwords/Keys)

Store sensitive information:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-password
  namespace: autoscale
type: Opaque
data:
  password: cGFzc3dvcmQxMjM=  # base64 encoded
```

**Use Case:** Database passwords, API keys, TLS certificates

!!! warning "Security Note"
    Always base64 encode secret values and never commit unencrypted secrets to version control.

---

### PersistentVolumeClaim (for Storage)

Request persistent storage:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: apache-data
  namespace: autoscale
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
```

**Use Case:** Database storage, file uploads, application state

---

### Ingress (for External Access)

Expose HTTP/HTTPS routes to services:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: apache-ingress
  namespace: autoscale
spec:
  rules:
  - host: apache.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: apache-server
            port:
              number: 80
```

**Use Case:** Production external access with domain names, SSL termination, path-based routing

!!! info "Ingress Controller Required"
    Ingress resources require an Ingress Controller (like NGINX Ingress Controller) to be installed in your cluster.

---

## Complete Example

Here's a complete, production-ready deployment with all recommended components:

```yaml
---
# Namespace
apiVersion: v1
kind: Namespace
metadata:
  name: autoscale

---
# Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: apache-server
  namespace: autoscale
  labels:
    app: apache-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: apache-server
  template:
    metadata:
      labels:
        app: apache-server
    spec:
      containers:
      - name: apache-server
        image: httpd:latest
        ports:
        - containerPort: 80
          name: http
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi

---
# Service
apiVersion: v1
kind: Service
metadata:
  name: apache-server
  namespace: autoscale
spec:
  selector:
    app: apache-server
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
  type: ClusterIP

---
# Horizontal Pod Autoscaler
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: apache-server
  namespace: autoscale
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: apache-server
  minReplicas: 1
  maxReplicas: 4
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 30
```

---

## Deployment Checklist

Before deploying to production, ensure you have:

- [ ] Namespace created for organization
- [ ] Deployment with proper resource requests/limits
- [ ] Service to expose your application
- [ ] HPA configured if autoscaling is needed
- [ ] Metrics Server installed (for HPA)
- [ ] ConfigMaps for configuration data
- [ ] Secrets for sensitive information
- [ ] PersistentVolumes if storage is needed
- [ ] Ingress for external HTTP/HTTPS access
- [ ] Resource quotas and limits configured
- [ ] Labels and selectors properly defined

---

## Quick Reference

### Minimum to Run a Deployment

**Required:**
1. Deployment

### Minimum to Run and Access a Deployment

**Recommended:**
1. Deployment (required)
2. Service (recommended)

### Production-Ready Setup

**Recommended:**
1. Namespace
2. Deployment
3. Service
4. HPA (if autoscaling needed)
5. ConfigMap/Secret (if configuration needed)
6. PersistentVolume (if storage needed)
7. Ingress (if external access needed)

---

## Next Steps

After understanding these components:

1. **Deploy a test application** using the complete example above
2. **Monitor your deployment** using `kubectl get` commands
3. **Scale your application** manually or with HPA
4. **Add persistent storage** if your app needs it
5. **Configure external access** using Ingress
6. **Implement CI/CD** to automate deployments

---

## Additional Resources

- [Kubernetes Official Documentation](https://kubernetes.io/docs/)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
