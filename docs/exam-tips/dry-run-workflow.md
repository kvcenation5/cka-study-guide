# CKA Exam: kubectl --dry-run=client Guide

## Overview

`--dry-run=client` is one of the **most useful flags** for the CKA exam. It simulates creating a resource **without actually creating it**. Combined with `-o yaml`, it generates YAML definitions that you can modify and apply.

!!! success "Time Savings"
    Using `--dry-run=client` can reduce YAML creation time from 3-5 minutes to just 30 seconds!

## What is --dry-run=client?

The flag simulates resource creation without actually creating the resource in the cluster. This allows you to:

- Generate valid YAML templates
- Validate commands before execution
- Preview what will be created
- Quickly modify configurations

## Key Use Cases in CKA Exam

### 1. Generate YAML Templates Quickly

Instead of writing YAML from scratch (time-consuming and error-prone), generate it with kubectl commands.

#### Pods

```bash
# Basic pod YAML
kubectl run nginx --image=nginx --dry-run=client -o yaml > pod.yaml

# Pod with labels
kubectl run nginx --image=nginx \
  --labels=app=web,tier=frontend \
  --dry-run=client -o yaml > pod.yaml

# Pod with resource limits
kubectl run nginx --image=nginx \
  --requests='cpu=100m,memory=256Mi' \
  --limits='cpu=200m,memory=512Mi' \
  --dry-run=client -o yaml > pod.yaml
```

#### Deployments

```bash
# Basic deployment
kubectl create deployment nginx --image=nginx --replicas=3 \
  --dry-run=client -o yaml > deployment.yaml

# Deployment with port exposed
kubectl create deployment nginx --image=nginx --port=80 \
  --dry-run=client -o yaml > deployment.yaml
```

#### Services

```bash
# ClusterIP service
kubectl expose pod nginx --port=80 --target-port=8080 \
  --dry-run=client -o yaml > service.yaml

# NodePort service
kubectl create service nodeport nginx --tcp=80:8080 \
  --dry-run=client -o yaml > service.yaml

# LoadBalancer from deployment
kubectl expose deployment nginx --port=80 --type=LoadBalancer \
  --dry-run=client -o yaml > service.yaml
```

#### ConfigMaps

```bash
# From literal values
kubectl create configmap app-config \
  --from-literal=key1=value1 \
  --from-literal=key2=value2 \
  --dry-run=client -o yaml > configmap.yaml

# From file
kubectl create configmap app-config --from-file=config.txt \
  --dry-run=client -o yaml > configmap.yaml
```

#### Secrets

```bash
# Generic secret
kubectl create secret generic db-secret \
  --from-literal=password=mypass123 \
  --dry-run=client -o yaml > secret.yaml

# TLS secret
kubectl create secret tls tls-secret \
  --cert=path/to/cert \
  --key=path/to/key \
  --dry-run=client -o yaml > secret.yaml
```

#### Jobs

```bash
kubectl create job test-job --image=busybox -- echo "Hello" \
  --dry-run=client -o yaml > job.yaml
```

#### CronJobs

```bash
kubectl create cronjob test-cron --image=busybox \
  --schedule="*/5 * * * *" -- echo "Hello" \
  --dry-run=client -o yaml > cronjob.yaml
```

#### ServiceAccounts

```bash
kubectl create serviceaccount my-sa \
  --dry-run=client -o yaml > sa.yaml
```

#### Roles

```bash
kubectl create role pod-reader \
  --verb=get,list,watch \
  --resource=pods \
  --dry-run=client -o yaml > role.yaml
```

#### RoleBindings

```bash
kubectl create rolebinding pod-reader-binding \
  --role=pod-reader \
  --serviceaccount=default:my-sa \
  --dry-run=client -o yaml > rolebinding.yaml
```

### 2. Modify and Apply Workflow

The typical CKA exam workflow for complex resources:

```bash
# Step 1: Generate YAML template
kubectl run nginx --image=nginx --dry-run=client -o yaml > pod.yaml

# Step 2: Edit the YAML
vim pod.yaml
# Add volumes, environment variables, security context, etc.

# Step 3: Apply the modified YAML
kubectl apply -f pod.yaml
```

!!! tip "Pro Workflow"
    This three-step process (Generate → Edit → Apply) is faster and less error-prone than writing YAML from scratch.

### 3. Validate Before Creating

Check if your command is correct without actually creating the resource:

```bash
# Test the command syntax
kubectl run test --image=nginx --port=80 --env=VAR=value --dry-run=client

# Output shows any errors in your command without creating anything
```

### 4. Quick Reference Generation

Generate a template when you forget the exact YAML structure:

```bash
# "How do I structure a Job again?"
kubectl create job example --image=busybox --dry-run=client -o yaml

# See the correct structure, then modify as needed
```

### 5. Combine Multiple Resources

```bash
# Generate multiple resources and combine into one file
kubectl create deployment web --image=nginx --dry-run=client -o yaml > app.yaml
echo "---" >> app.yaml
kubectl expose deployment web --port=80 --dry-run=client -o yaml >> app.yaml
```

## Common CKA Exam Scenarios

### Scenario 1: Create a Pod with Specific Requirements

**Question:** Create a pod named `web` with image `nginx:1.19`, label `tier=frontend`, resource requests of 100m CPU and 128Mi memory.

**Without dry-run (slow and error-prone):**

```yaml
# Must write entire YAML manually
apiVersion: v1
kind: Pod
metadata:
  name: web
  labels:
    tier: frontend
spec:
  containers:
  - name: web
    image: nginx:1.19
    resources:
      requests:
        cpu: "100m"
        memory: "128Mi"
```

**With dry-run (fast and accurate):**

```bash
kubectl run web --image=nginx:1.19 \
  --labels=tier=frontend \
  --requests='cpu=100m,memory=128Mi' \
  --dry-run=client -o yaml | kubectl apply -f -
```

### Scenario 2: Deployment with 3 Replicas

**Question:** Create a deployment `app` with image `redis`, 3 replicas, in namespace `production`.

```bash
kubectl create deployment app --image=redis --replicas=3 \
  -n production --dry-run=client -o yaml > deploy.yaml

# Edit if needed, then apply
kubectl apply -f deploy.yaml
```

### Scenario 3: Expose a Deployment

**Question:** Expose deployment `web` on port 80, target port 8080 as a NodePort service.

```bash
kubectl expose deployment web \
  --port=80 --target-port=8080 --type=NodePort \
  --dry-run=client -o yaml > service.yaml

# Optionally specify nodePort in YAML, then apply
kubectl apply -f service.yaml
```

### Scenario 4: ConfigMap from Multiple Sources

**Question:** Create a ConfigMap with database connection details.

```bash
kubectl create configmap app-config \
  --from-literal=DB_HOST=mysql \
  --from-literal=DB_PORT=3306 \
  --dry-run=client -o yaml > cm.yaml

kubectl apply -f cm.yaml
```

### Scenario 5: Role with Specific Permissions

**Question:** Create a role that can get, list, and watch pods and services.

```bash
kubectl create role dev-role \
  --verb=get,list,watch \
  --resource=pods,services \
  --dry-run=client -o yaml > role.yaml

kubectl apply -f role.yaml
```

## Time Comparison

| Method | Time Required | Error Rate | Flexibility |
|--------|---------------|------------|-------------|
| Write YAML manually | 3-5 minutes | High | Full |
| Use `--dry-run=client` | 30 seconds | Low | High |
| Pure imperative commands | 10 seconds | Low | Limited |

## Advantages and Limitations

### Advantages

✅ **Speed** - Generate templates in seconds  
✅ **Accuracy** - Kubernetes generates syntactically valid YAML  
✅ **Flexibility** - Easy to modify generated YAML before applying  
✅ **Validation** - Check commands before execution  
✅ **Learning** - See correct YAML structure for reference  
✅ **Consistency** - Ensures proper formatting and indentation  

### Limitations

⚠️ Not all resource types support `--dry-run=client`  
⚠️ Complex configurations still need manual editing  
⚠️ Some fields can't be set via kubectl create/run flags  
⚠️ Advanced features require YAML editing (affinity, tolerations, etc.)  

## Kubernetes Documentation in CKA Exam

### What's Allowed?

The CKA is an **open-book exam**. You're allowed to access:

✅ kubernetes.io/docs  
✅ kubernetes.io/blog  
✅ GitHub Kubernetes repos  

!!! warning "No External Resources"
    You cannot access Stack Overflow, Medium articles, or other external sites during the exam.

### Most Useful Documentation Pages

#### 1. kubectl Cheat Sheet

```
https://kubernetes.io/docs/reference/kubectl/cheatsheet/
```

- Quick reference for all kubectl commands
- Shows `--dry-run=client` examples
- Common operations and shortcuts

#### 2. kubectl Command Reference

```
https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands
```

- Detailed command documentation
- All available flags and options
- Usage examples

#### 3. API Reference

```
https://kubernetes.io/docs/reference/kubernetes-api/
```

- Understanding YAML structure
- All available fields for each resource type
- Field descriptions and defaults

### Documentation Strategy

**Use documentation for:**

- Complex YAML structures (StatefulSets, DaemonSets, NetworkPolicies)
- Specific field names you forgot
- Advanced configurations (affinity, tolerations, taints, PodDisruptionBudgets)
- Unfamiliar resource types

**Don't use documentation for:**

- Basic pod/deployment/service creation
- Common kubectl commands
- Simple YAML modifications

!!! tip "Time Management"
    Don't spend more than 2 minutes searching documentation. If you can't find it quickly, flag the question and move on.

## Recommended Approach for CKA

### Before the Exam (Practice Phase)

#### 1. Memorize Common Patterns

Practice these until they're muscle memory:

- `kubectl run` for pods
- `kubectl create deployment` for deployments
- `kubectl expose` for services
- `kubectl create configmap/secret` for configuration
- `kubectl create role/rolebinding` for RBAC

#### 2. Practice the Workflow

```bash
# Generate → Edit → Apply workflow
kubectl create deployment nginx --image=nginx --dry-run=client -o yaml > deploy.yaml
vim deploy.yaml
kubectl apply -f deploy.yaml
```

Practice this workflow until it becomes second nature.

#### 3. Set Up Aliases

Create useful aliases in your `.bashrc` or `.bash_profile`:

```bash
# Add this to your ~/.bashrc or just run it at the start of the exam
alias k=kubectl
alias kdr='kubectl --dry-run=client -o yaml'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgd='kubectl get deployments'

# Usage examples
k run nginx --image=nginx $kdr > pod.yaml
kgp -o wide
```

!!! note "Exam Environment"
    You can set up aliases during the exam, but practice beforehand so you don't waste time.

### During the Exam

#### 1. Use --dry-run=client First

For these resource types, always start with `--dry-run`:

- Pods (`kubectl run`)
- Deployments (`kubectl create deployment`)
- Services (`kubectl expose` or `kubectl create service`)
- ConfigMaps (`kubectl create configmap`)
- Secrets (`kubectl create secret`)
- Jobs (`kubectl create job`)
- CronJobs (`kubectl create cronjob`)
- Roles/RoleBindings (`kubectl create role/rolebinding`)
- ServiceAccounts (`kubectl create serviceaccount`)

#### 2. When to Use Documentation

Refer to kubernetes.io/docs for:

- StatefulSets
- DaemonSets
- NetworkPolicies
- PodDisruptionBudgets
- ResourceQuotas
- LimitRanges
- Custom configurations (affinity, tolerations, taints, init containers)

#### 3. Time Management Tips

- Read all questions first, flag difficult ones
- Start with questions you can solve quickly using `--dry-run`
- Don't spend more than 5-7 minutes per question
- If stuck, move on and come back later
- Leave 15-20 minutes at the end to review

## Essential Commands to Memorize

### Core Generators

```bash
# Pods
kubectl run NAME --image=IMAGE --dry-run=client -o yaml

# Deployments
kubectl create deployment NAME --image=IMAGE --replicas=N --dry-run=client -o yaml

# Services - from pod/deployment
kubectl expose TYPE NAME --port=PORT --target-port=PORT --type=TYPE --dry-run=client -o yaml

# Services - standalone
kubectl create service TYPE NAME --tcp=PORT:TARGETPORT --dry-run=client -o yaml

# ConfigMaps
kubectl create configmap NAME --from-literal=KEY=VALUE --dry-run=client -o yaml

# Secrets
kubectl create secret generic NAME --from-literal=KEY=VALUE --dry-run=client -o yaml

# Jobs
kubectl create job NAME --image=IMAGE -- COMMAND --dry-run=client -o yaml

# CronJobs
kubectl create cronjob NAME --image=IMAGE --schedule="CRON" -- COMMAND --dry-run=client -o yaml
```

### RBAC Resources

```bash
# ServiceAccounts
kubectl create serviceaccount NAME --dry-run=client -o yaml

# Roles
kubectl create role NAME --verb=VERB --resource=RESOURCE --dry-run=client -o yaml

# RoleBindings
kubectl create rolebinding NAME --role=ROLE --serviceaccount=NAMESPACE:SA --dry-run=client -o yaml

# ClusterRoles
kubectl create clusterrole NAME --verb=VERB --resource=RESOURCE --dry-run=client -o yaml

# ClusterRoleBindings
kubectl create clusterrolebinding NAME --clusterrole=ROLE --serviceaccount=NAMESPACE:SA --dry-run=client -o yaml
```

## Pro Tips for CKA Success

### 1. Use Imperative Commands When Possible

For simple resources without complex requirements:

```bash
# Faster than dry-run → edit → apply
kubectl run nginx --image=nginx --port=80 --labels=app=web

# Create and expose in one command
kubectl run nginx --image=nginx --port=80 --expose
```

### 2. Combine with kubectl apply

One-liner creation for simple cases:

```bash
kubectl run nginx --image=nginx --dry-run=client -o yaml | kubectl apply -f -
```

### 3. Use kubectl explain

When you forget field structures:

```bash
# See all fields for pods
kubectl explain pod.spec.containers

# See deployment fields
kubectl explain deployment.spec.template

# See nested fields
kubectl explain pod.spec.containers.resources
```

### 4. Set Namespace Context

Avoid typing `-n namespace` repeatedly:

```bash
# Set namespace for all subsequent commands
kubectl config set-context --current --namespace=production

# Now all commands use 'production' namespace
kubectl get pods  # same as: kubectl get pods -n production
```

### 5. Use kubectl get with Custom Output

```bash
# Show pod names and nodes
kubectl get pods -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName

# Show with wide output for more details
kubectl get pods -o wide

# Output as YAML to see all fields
kubectl get pod nginx -o yaml
```

### 6. Master vim Basics

You'll need to edit YAML files quickly:

```bash
# Essential vim commands
i           # Insert mode
Esc         # Exit insert mode
:wq         # Write and quit
:q!         # Quit without saving
dd          # Delete line
yy          # Copy line
p           # Paste
u           # Undo
/search     # Search for text
:set number # Show line numbers
:set paste  # Paste mode (preserves formatting)
```

## Practice Exercises

### Exercise 1: Multi-Container Pod

Create a pod with:
- Name: `multi-pod`
- First container: `nginx` with image `nginx:1.19`
- Second container: `redis` with image `redis:alpine`
- Label: `app=web`

```bash
# Generate base pod
kubectl run multi-pod --image=nginx:1.19 --labels=app=web --dry-run=client -o yaml > pod.yaml

# Edit to add second container
vim pod.yaml

# Add under containers:
# - name: redis
#   image: redis:alpine

# Apply
kubectl apply -f pod.yaml
```

### Exercise 2: Deployment with ConfigMap

Create:
1. ConfigMap with `DB_HOST=postgres` and `DB_PORT=5432`
2. Deployment using the ConfigMap as environment variables

```bash
# ConfigMap
kubectl create configmap db-config \
  --from-literal=DB_HOST=postgres \
  --from-literal=DB_PORT=5432 \
  --dry-run=client -o yaml > configmap.yaml

kubectl apply -f configmap.yaml

# Deployment
kubectl create deployment app --image=nginx --dry-run=client -o yaml > deploy.yaml

# Edit deploy.yaml to add envFrom:
# envFrom:
# - configMapRef:
#     name: db-config

kubectl apply -f deploy.yaml
```

### Exercise 3: Service and NetworkPolicy

Create:
1. A deployment with 3 replicas
2. Expose it as a ClusterIP service
3. Create a NetworkPolicy allowing traffic only from specific pods

```bash
# Deployment
kubectl create deployment web --image=nginx --replicas=3

# Service
kubectl expose deployment web --port=80 --dry-run=client -o yaml > service.yaml
kubectl apply -f service.yaml

# NetworkPolicy (need to create YAML manually or from docs)
# Search kubernetes.io/docs for NetworkPolicy examples
```

## Quick Reference Card

### Generate Resources

| Resource | Command |
|----------|---------|
| Pod | `kubectl run NAME --image=IMAGE --dry-run=client -o yaml` |
| Deployment | `kubectl create deployment NAME --image=IMAGE --dry-run=client -o yaml` |
| Service (from resource) | `kubectl expose TYPE NAME --port=PORT --dry-run=client -o yaml` |
| Service (standalone) | `kubectl create service TYPE NAME --tcp=PORT:PORT --dry-run=client -o yaml` |
| ConfigMap | `kubectl create configmap NAME --from-literal=K=V --dry-run=client -o yaml` |
| Secret | `kubectl create secret generic NAME --from-literal=K=V --dry-run=client -o yaml` |
| Job | `kubectl create job NAME --image=IMAGE --dry-run=client -o yaml` |
| CronJob | `kubectl create cronjob NAME --image=IMAGE --schedule="* * * * *" --dry-run=client -o yaml` |

### Common Flags

| Flag | Purpose |
|------|---------|
| `--dry-run=client` | Simulate command without creating |
| `-o yaml` | Output in YAML format |
| `-o json` | Output in JSON format |
| `-n NAMESPACE` | Specify namespace |
| `--replicas=N` | Set number of replicas |
| `--port=PORT` | Set container port |
| `--expose` | Create service automatically |
| `--labels=KEY=VALUE` | Add labels |
| `--requests=KEY=VALUE` | Set resource requests |
| `--limits=KEY=VALUE` | Set resource limits |

## Summary

### Is --dry-run=client Useful in CKA?

**Absolutely YES!** It's one of the most valuable tools for:

✅ Generating YAML templates quickly  
✅ Saving time on repetitive tasks  
✅ Reducing syntax errors and typos  
✅ Validating commands before execution  
✅ Learning correct YAML structure  

### Should You Use the Kubernetes Documentation?

**Yes, but strategically:**

- ✅ Use it for complex structures you don't remember
- ❌ Don't waste time searching for basic commands
- ✅ Memorize the most common `--dry-run` patterns
- ❌ Don't rely on docs for every question

### Final Recommendations

!!! success "Exam Success Strategy"
    1. **Master** `--dry-run=client` for common resources
    2. **Practice** the Generate → Edit → Apply workflow
    3. **Memorize** essential commands and flags
    4. **Use** documentation only for complex/unfamiliar resources
    5. **Manage** time wisely - don't get stuck on one question
    6. **Set up** useful aliases at the start of the exam

**Practice makes perfect!** The more you use `--dry-run=client` in your daily work, the faster and more confident you'll be during the exam.

---
---

# Appendix: Concise Summary & Shortcuts

Below is the concise version of the Dry-Run workflow for quick reference and essential command patterns.

## 1. What does it actually do?

*   **`--dry-run=client`**: Tells `kubectl` to simulate the command locally. It checks the syntax but **does not** send it to the cluster.
*   **`-o yaml`**: Tells `kubectl` to output the result as a YAML manifest instead of a success message.

---

## 2. Situations where you MUST use it

### A. Creating Pods with complex logic
`kubectl run` only supports basic flags. If you need to add **Resource Limits**, **Environment Variables**, or **Volume Mounts**, you generate the skeleton first.
```bash
# Goal: Pod with specific environment variables and limits
kubectl run nginx --image=nginx --dry-run=client -o yaml > pod.yaml
# Then edit pod.yaml to add 'env' and 'resources'
```

### B. Creating DaemonSets (The Shortcut)
Since there is no `kubectl create daemonset` command:
1.  Generate a Deployment:
    ```bash
    kubectl create deployment my-ds --image=nginx --dry-run=client -o yaml > ds.yaml
    ```
2.  Change `kind: Deployment` to `kind: DaemonSet`.
3.  Remove `replicas: 1`.

### C. Creating Services (Connecting to Pods)
Instead of typing selectors manually:
```bash
kubectl expose pod webapp --name=webapp-service --type=NodePort --port=80 --dry-run=client -o yaml > svc.yaml
```

### D. Multi-container Pods
You can't create a multi-container pod using a single CLI command. Generate a one-container pod first, then add the second container in YAML.

---

## 3. CLI vs. Kubernetes Documentation

Should you use the [Kubernetes Quick Reference](https://kubernetes.io/docs/reference/kubectl/cheatsheet/) or the CLI?

| Method | When to use it | Pros/Cons |
| :--- | :--- | :--- |
| **CLI (`dry-run`)** | **90% of the time.** Creating Pods, Deployments, Services, ConfigMaps, Secrets, CronJobs. | **Pro**: Fastest, Zero indentation errors. <br> **Con**: Doesn't support Affinity, Taints, or NetworkPolicy. |
| **Official Docs** | **For "Heavy" Logic.** Node Affinity, Ingress, NetworkPolicy, PV/PVC. | **Pro**: Copy-paste large blocks of complex YAML. <br> **Con**: High risk of copy-paste indentation errors. |

---

## 4. The "Work-Life Balance" of CKA

**The Golden Strategy:**
1.  **Generate the skeleton** using `kubectl ... --dry-run=client -o yaml`.
2.  **Add the "Organs"** (Affinity, Taints, etc.) by copy-pasting small snippets from the official docs.

---

## 5. Summary Cheat Sheet for CLI Generation

| Resource | Base Command |
| :--- | :--- |
| **Pod** | `kubectl run pod-name --image=nginx` |
| **Deployment** | `kubectl create deployment dep-name --image=nginx` |
| **Service (ClusterIP)** | `kubectl create service clusterip svc-name --tcp=80:80` |
| **Service (NodePort)** | `kubectl expose deployment dep-name --type=NodePort --port=80` |
| **ConfigMap** | `kubectl create configmap my-config --from-literal=key=value` |
| **Secret** | `kubectl create secret generic my-secret --from-literal=pass=123` |
| **CronJob** | `kubectl create cronjob my-job --image=nginx --schedule="*/1 * * * *"` |

**Always append `--dry-run=client -o yaml > file.yaml` to these!**
