# CKA Exam Tips: kubectl Commands

This guide contains essential `kubectl` command patterns and time-saving tricks for the CKA exam.

---

## ⚡ Important Exam Tip: Avoid Writing YAML Files!

**Here's the reality of the CKA exam:**

Creating and editing YAML files in the CLI is **difficult and time-consuming**. During the exam:
- ❌ Copying/pasting YAML from browser to terminal is awkward
- ❌ Manual indentation errors waste precious time
- ❌ Typos in `apiVersion` or `kind` cause frustrating failures

**The Solution:** Use `kubectl run` and `kubectl create` commands to generate YAML templates automatically!

### The Exam Strategy

**Instead of writing YAML from scratch:**
```bash
# ❌ Don't do this (slow, error-prone)
vim pod.yaml
# Type everything manually...
```

**Do this instead:**
```bash
# ✅ Generate the YAML automatically
kubectl run nginx --image=nginx --dry-run=client -o yaml > pod.yaml
vim pod.yaml  # Make minor edits if needed
kubectl apply -f pod.yaml
```

**Or even better, skip the YAML file entirely:**
```bash
# ✅ Create directly (fastest)
kubectl run nginx --image=nginx
kubectl create deployment nginx --image=nginx --replicas=4
```

### Official Reference
**Bookmark this page for the exam:** [kubectl Conventions](https://kubernetes.io/docs/reference/kubectl/conventions/)

---

## The Golden Rule: --dry-run + -o yaml

**The #1 time-saving trick for the exam:**

```bash
kubectl create <resource> <name> <options> --dry-run=client -o yaml > file.yaml
```

**What this does:**
1. Generates a perfect YAML template
2. Doesn't create anything in the cluster
3. Saves you from typing YAML from scratch
4. Eliminates typos and indentation errors

**Example:**
```bash
kubectl create deployment nginx --image=nginx --replicas=3 --dry-run=client -o yaml > deploy.yaml
vim deploy.yaml  # Make any edits
kubectl apply -f deploy.yaml
```

---

## kubectl create vs kubectl apply

| Command | When to Use | Behavior if Resource Exists |
| :--- | :--- | :--- |
| `kubectl create` | Quick one-time tasks, generating templates | ❌ Fails with error |
| `kubectl apply` | Production, updates, repeatable deployments | ✅ Updates the resource |

### Exam Strategy
1. **Use `create` for speed:**
   ```bash
   kubectl create deployment nginx --image=nginx --replicas=3
   ```

2. **Use `create --dry-run` to generate YAML:**
   ```bash
   kubectl create deployment nginx --image=nginx --dry-run=client -o yaml > deploy.yaml
   ```

3. **Use `apply` when updating:**
   ```bash
   kubectl apply -f deploy.yaml
   vim deploy.yaml  # Make changes
   kubectl apply -f deploy.yaml  # Update
   ```

---

## --dry-run Explained

### What It Does
**Simulates the command without actually creating anything.**

```bash
# Without dry-run (creates the resource)
kubectl create deployment nginx --image=nginx

# With dry-run (just shows what would happen)
kubectl create deployment nginx --image=nginx --dry-run=client
```

### client vs server

| Flag | Where Validation Happens | Use Case |
| :--- | :--- | :--- |
| `--dry-run=client` | Your machine (kubectl) | **Exam default** - Fast, generates templates |
| `--dry-run=server` | API Server (cluster) | Full validation, checks quotas |

**For CKA:** Always use `--dry-run=client` (faster).

---

## Quick Reference: Essential Commands

These are the **most common commands** you'll use in the exam. Memorize these patterns!

### Create an NGINX Pod
```bash
kubectl run nginx --image=nginx
```

### Generate Pod Manifest YAML file (don't create it)
```bash
kubectl run nginx --image=nginx --dry-run=client -o yaml
```

### Create a Deployment
```bash
kubectl create deployment nginx --image=nginx
```

### Generate Deployment YAML file (don't create it)
```bash
kubectl create deployment nginx --image=nginx --dry-run=client -o yaml
```

### Generate Deployment YAML and save to file
```bash
kubectl create deployment nginx --image=nginx --dry-run=client -o yaml > nginx-deployment.yaml
```

Then make necessary changes to the file (e.g., adding more replicas) and create the deployment:
```bash
kubectl create -f nginx-deployment.yaml
```

### Create Deployment with Replicas (Kubernetes 1.19+)
```bash
kubectl create deployment nginx --image=nginx --replicas=4 --dry-run=client -o yaml > nginx-deployment.yaml
```

---

## Essential kubectl create Commands

### 1. Deployment
```bash
# Basic
kubectl create deployment nginx --image=nginx

# With replicas
kubectl create deployment nginx --image=nginx --replicas=3

# Generate YAML
kubectl create deployment nginx --image=nginx --replicas=3 --dry-run=client -o yaml > deploy.yaml
```

### 2. Pod
```bash
# Basic
kubectl run nginx --image=nginx

# With port
kubectl run nginx --image=nginx --port=80

# With labels
kubectl run nginx --image=nginx --labels="app=web,tier=frontend"

# Generate YAML
kubectl run nginx --image=nginx --dry-run=client -o yaml > pod.yaml
```

### 3. Service
```bash
# ClusterIP
kubectl create service clusterip my-svc --tcp=80:8080

# NodePort
kubectl create service nodeport my-svc --tcp=80:8080 --node-port=30080

# LoadBalancer
kubectl create service loadbalancer my-svc --tcp=80:8080

# Expose a deployment
kubectl expose deployment nginx --port=80 --target-port=8080

# Generate YAML
kubectl create service clusterip my-svc --tcp=80:8080 --dry-run=client -o yaml > svc.yaml
```

### 4. ConfigMap
```bash
# From literal values
kubectl create configmap my-config --from-literal=key1=value1 --from-literal=key2=value2

# From file
kubectl create configmap my-config --from-file=config.txt

# From directory
kubectl create configmap my-config --from-file=./config-dir/

# Generate YAML
kubectl create configmap my-config --from-literal=key=value --dry-run=client -o yaml > cm.yaml
```

### 5. Secret
```bash
# Generic secret
kubectl create secret generic my-secret --from-literal=password=supersecret

# Docker registry secret
kubectl create secret docker-registry my-registry \
  --docker-server=registry.example.com \
  --docker-username=user \
  --docker-password=pass

# TLS secret
kubectl create secret tls my-tls --cert=cert.pem --key=key.pem

# Generate YAML
kubectl create secret generic my-secret --from-literal=password=secret --dry-run=client -o yaml > secret.yaml
```

### 6. Namespace
```bash
kubectl create namespace dev
kubectl create namespace production
```

### 7. ServiceAccount
```bash
kubectl create serviceaccount my-sa
```

### 8. Job
```bash
kubectl create job my-job --image=busybox -- echo "Hello World"

# Generate YAML
kubectl create job my-job --image=busybox --dry-run=client -o yaml > job.yaml -- echo "Hello"
```

### 9. CronJob
```bash
kubectl create cronjob my-cronjob --image=busybox --schedule="*/5 * * * *" -- echo "Hello"

# Generate YAML
kubectl create cronjob my-cronjob --image=busybox --schedule="*/5 * * * *" --dry-run=client -o yaml > cronjob.yaml
```

### 10. Role (RBAC)
```bash
kubectl create role pod-reader --verb=get,list,watch --resource=pods

# Generate YAML
kubectl create role pod-reader --verb=get,list --resource=pods --dry-run=client -o yaml > role.yaml
```

### 11. RoleBinding (RBAC)
```bash
kubectl create rolebinding read-pods --role=pod-reader --user=jane

# Generate YAML
kubectl create rolebinding read-pods --role=pod-reader --user=jane --dry-run=client -o yaml > rb.yaml
```

### 12. ClusterRole (RBAC)
```bash
kubectl create clusterrole pod-reader --verb=get,list,watch --resource=pods
```

### 13. ClusterRoleBinding (RBAC)
```bash
kubectl create clusterrolebinding read-pods --clusterrole=pod-reader --user=jane
```

---

## Quick Reference: Common Tasks

### Scale a Deployment
```bash
kubectl scale deployment nginx --replicas=5
```

### Update Image
```bash
kubectl set image deployment/nginx nginx=nginx:1.21
```

### Rollout Commands
```bash
# Check rollout status
kubectl rollout status deployment nginx

# View rollout history
kubectl rollout history deployment nginx

# Undo rollout
kubectl rollout undo deployment nginx

# Undo to specific revision
kubectl rollout undo deployment nginx --to-revision=2

# Restart deployment (recreate all pods)
kubectl rollout restart deployment nginx
```

### Get Resources
```bash
# All resources in namespace
kubectl get all

# Specific resource types
kubectl get pods
kubectl get deployments
kubectl get services
kubectl get configmaps
kubectl get secrets

# All namespaces
kubectl get pods --all-namespaces
kubectl get pods -A  # Short form

# With labels
kubectl get pods -l app=nginx
kubectl get pods -l app=nginx,tier=frontend

# Show labels
kubectl get pods --show-labels

# Wide output (more details)
kubectl get pods -o wide
```

### Describe Resources
```bash
kubectl describe pod nginx
kubectl describe deployment nginx
kubectl describe service nginx
```

### Logs
```bash
# Current logs
kubectl logs nginx

# Previous container logs (after crash)
kubectl logs nginx --previous

# Follow logs (tail -f)
kubectl logs -f nginx

# Multiple containers in pod
kubectl logs nginx -c container-name
```

### Execute Commands
```bash
# Interactive shell
kubectl exec -it nginx -- /bin/bash
kubectl exec -it nginx -- sh

# Run single command
kubectl exec nginx -- ls /
kubectl exec nginx -- env
```

### Delete Resources
```bash
# Delete by name
kubectl delete pod nginx
kubectl delete deployment nginx

# Delete by label
kubectl delete pods -l app=nginx

# Delete all pods in namespace
kubectl delete pods --all

# Force delete (stuck pod)
kubectl delete pod nginx --force --grace-period=0
```

---

## Time-Saving Aliases

Add these to your `~/.bashrc` or `~/.zshrc`:

```bash
alias k=kubectl
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgd='kubectl get deployments'
alias kd='kubectl describe'
alias kdp='kubectl describe pod'
alias kl='kubectl logs'
alias kex='kubectl exec -it'
alias ka='kubectl apply -f'
alias kdel='kubectl delete'
```

**In the exam, you can set these up at the start:**
```bash
alias k=kubectl
complete -F __start_kubectl k  # Enable autocomplete for 'k'
```

---

## Exam Workflow Example

**Task:** Create a Deployment with 3 replicas, expose it as a Service, and create a ConfigMap.

### Step 1: Generate YAML templates
```bash
# Deployment
kubectl create deployment web --image=nginx --replicas=3 --dry-run=client -o yaml > deploy.yaml

# Service
kubectl expose deployment web --port=80 --dry-run=client -o yaml > svc.yaml

# ConfigMap
kubectl create configmap web-config --from-literal=env=prod --dry-run=client -o yaml > cm.yaml
```

### Step 2: Edit if needed
```bash
vim deploy.yaml  # Add labels, resource limits, etc.
vim svc.yaml     # Change service type if needed
vim cm.yaml      # Add more config keys
```

### Step 3: Apply all
```bash
kubectl apply -f deploy.yaml
kubectl apply -f svc.yaml
kubectl apply -f cm.yaml

# Or apply entire directory
kubectl apply -f .
```

### Step 4: Verify
```bash
kubectl get all
kubectl get configmap
kubectl describe deployment web
```

---

## Common Exam Scenarios

### Scenario 1: "Create 3 replicas of nginx"
```bash
kubectl create deployment nginx --image=nginx --replicas=3
```

### Scenario 2: "Expose the deployment on port 80"
```bash
kubectl expose deployment nginx --port=80 --target-port=80
```

### Scenario 3: "Scale to 5 replicas"
```bash
kubectl scale deployment nginx --replicas=5
```

### Scenario 4: "Update image to nginx:1.21"
```bash
kubectl set image deployment/nginx nginx=nginx:1.21
```

### Scenario 5: "Create a ConfigMap from file"
```bash
kubectl create configmap app-config --from-file=config.properties
```

### Scenario 6: "Create a Secret"
```bash
kubectl create secret generic db-creds --from-literal=username=admin --from-literal=password=secret
```

### Scenario 7: "Create a Pod with specific labels"
```bash
kubectl run nginx --image=nginx --labels="app=web,tier=frontend" --dry-run=client -o yaml > pod.yaml
kubectl apply -f pod.yaml
```

### Scenario 8: "Rollback a Deployment"
```bash
kubectl rollout undo deployment nginx
```

---

## Summary: Exam Cheat Sheet

| Task | Command |
| :--- | :--- |
| **Generate YAML** | `kubectl create ... --dry-run=client -o yaml > file.yaml` |
| **Create Deployment** | `kubectl create deployment nginx --image=nginx --replicas=3` |
| **Create Pod** | `kubectl run nginx --image=nginx` |
| **Create Service** | `kubectl expose deployment nginx --port=80` |
| **Create ConfigMap** | `kubectl create configmap my-config --from-literal=key=value` |
| **Create Secret** | `kubectl create secret generic my-secret --from-literal=password=secret` |
| **Scale** | `kubectl scale deployment nginx --replicas=5` |
| **Update Image** | `kubectl set image deployment/nginx nginx=nginx:1.21` |
| **Rollback** | `kubectl rollout undo deployment nginx` |
| **Get Resources** | `kubectl get pods -o wide` |
| **Describe** | `kubectl describe pod nginx` |
| **Logs** | `kubectl logs nginx` |
| **Exec** | `kubectl exec -it nginx -- /bin/bash` |
| **Delete** | `kubectl delete pod nginx` |

**Remember:** Speed is critical in the exam. Master `--dry-run=client -o yaml` to save time!
