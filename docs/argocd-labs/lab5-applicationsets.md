# Lab 5: ApplicationSets — Templating Across All Clusters

## Objective

Use `ApplicationSet` to automatically generate one `Application` per cluster. You'll implement the cluster generator, environment-based label targeting, and the App of Apps pattern.

---

## The Problem ApplicationSets Solve

In Lab 4 you wrote one Application per cluster per app. With 10 clusters and 20 apps that's 200 Application YAMLs to maintain. ApplicationSet generates them from a template:

```
ApplicationSet  (1 YAML)
  └── generates → Application for spoke1
  └── generates → Application for spoke2
  └── generates → Application for spoke3  ← auto-added when you register spoke3
```

---

## Generator Types

| Generator | What It Iterates |
|-----------|-----------------|
| `cluster` | Every cluster registered in ArgoCD |
| `git` | Directories or files in a Git repo |
| `list` | Hardcoded list of values |
| `matrix` | Cartesian product of two generators |

---

## Step 1: Cluster Generator — Deploy to All Spokes

```bash
cat << 'EOF' | kubectl apply -n argocd -f - --context kind-argocd-hub
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: guestbook-all-clusters
  namespace: argocd
spec:
  generators:
    - clusters:
        selector:
          matchExpressions:
            - key: argocd.argoproj.io/secret-type
              operator: Exists
  template:
    metadata:
      name: 'guestbook-{{name}}'
    spec:
      project: multicluster
      source:
        repoURL: https://github.com/argoproj/argocd-example-apps.git
        targetRevision: HEAD
        path: guestbook
      destination:
        server: '{{server}}'
        namespace: 'guestbook-{{name}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
EOF
```

### Template Variables

`{{name}}` and `{{server}}` are auto-populated from each cluster's ArgoCD secret:

| Variable | spoke1 value | spoke2 value |
|----------|-------------|-------------|
| `{{name}}` | `spoke1` | `spoke2` |
| `{{server}}` | `https://172.18.0.x:6443` | `https://172.18.0.y:6443` |

```bash
argocd app list
# guestbook-spoke1 and guestbook-spoke2 appear automatically
```

---

## Step 2: Label Clusters for Environment Targeting

Add environment labels to the cluster secrets so ApplicationSets can target subsets:

```bash
# Find the secret names
kubectl get secrets -n argocd \
  -l "argocd.argoproj.io/secret-type=cluster" \
  --context kind-argocd-hub

# Label spoke1 as staging
kubectl patch secret <spoke1-secret-name> -n argocd \
  --type merge \
  -p '{"metadata":{"labels":{"env":"staging"}}}' \
  --context kind-argocd-hub

# Label spoke2 as production
kubectl patch secret <spoke2-secret-name> -n argocd \
  --type merge \
  -p '{"metadata":{"labels":{"env":"production"}}}' \
  --context kind-argocd-hub
```

Now deploy only to `staging`:

```bash
cat << 'EOF' | kubectl apply -n argocd -f - --context kind-argocd-hub
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: nginx-staging-only
  namespace: argocd
spec:
  generators:
    - clusters:
        selector:
          matchLabels:
            env: staging
  template:
    metadata:
      name: 'nginx-{{name}}'
    spec:
      project: multicluster
      source:
        repoURL: https://github.com/argoproj/argocd-example-apps.git
        targetRevision: HEAD
        path: nginx
      destination:
        server: '{{server}}'
        namespace: nginx-staging
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
EOF
```

This only creates `nginx-spoke1` (the staging cluster). `spoke2` (production) is skipped.

---

## Step 3: App of Apps Pattern

Store your Application/ApplicationSet YAMLs in Git. One root Application deploys all of them:

```
Git repo
├── apps/
│   ├── guestbook-appset.yaml      ← ApplicationSet (all clusters)
│   ├── nginx-staging-appset.yaml  ← ApplicationSet (staging only)
│   └── monitoring-app.yaml        ← Application (hub only)
└── (root-app applied once via kubectl)
```

```bash
cat << 'EOF' | kubectl apply -n argocd -f - --context kind-argocd-hub
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root-app
  namespace: argocd
spec:
  project: multicluster
  source:
    repoURL: https://github.com/<your-org>/<your-repo>.git
    targetRevision: HEAD
    path: apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF
```

When `root-app` syncs it applies every YAML in `apps/`, which creates the ApplicationSets, which generate the Applications. Deploying a new app to all clusters = commit one file to Git.

---

## Step 4: List Generator (Explicit Targets)

When you want to name specific clusters rather than select by label:

```bash
cat << 'EOF' | kubectl apply -n argocd -f - --context kind-argocd-hub
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: redis-selected
  namespace: argocd
spec:
  generators:
    - list:
        elements:
          - cluster: spoke1
            url: REPLACE_SPOKE1_IP
          - cluster: spoke2
            url: REPLACE_SPOKE2_IP
  template:
    metadata:
      name: 'redis-{{cluster}}'
    spec:
      project: multicluster
      source:
        repoURL: https://github.com/argoproj/argocd-example-apps.git
        targetRevision: HEAD
        path: redis
      destination:
        server: '{{url}}'
        namespace: redis
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
EOF
```

---

## Final State Check

```bash
argocd app list
kubectl get applicationsets -n argocd --context kind-argocd-hub
```

---

## Clean Up

```bash
kubectl delete applicationsets --all -n argocd --context kind-argocd-hub
argocd app delete --all --yes
kind delete cluster --name argocd-hub
kind delete cluster --name spoke1
kind delete cluster --name spoke2
```

---

## Key Takeaways

| Use Case | Tool |
|----------|------|
| One app to one cluster | `Application` |
| Same app to all clusters | `ApplicationSet` + cluster generator |
| Same app to clusters matching a label | `ApplicationSet` + cluster generator + `matchLabels` |
| Explicit cluster list | `ApplicationSet` + list generator |
| App × clusters matrix | `ApplicationSet` + matrix generator |
| Manage Application YAMLs in Git | App of Apps pattern |

---

**Congratulations!** You've built a complete multi-cluster GitOps platform. Add a new spoke to ArgoCD and every ApplicationSet picks it up automatically — zero manual Application creation.
