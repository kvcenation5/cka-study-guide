# Lab 4: Deploying Applications to Multiple Clusters

## Objective

Create ArgoCD `Application` resources that deploy workloads to specific spoke clusters. You'll see ArgoCD reconcile Git state to live cluster state and observe self-healing in action.

---

## The Application CRD

An ArgoCD Application has two critical sections:

```yaml
spec:
  source:
    repoURL: <git-repo>      # where the manifests live
    path: <folder>           # subfolder in the repo
  destination:
    server: <cluster-url>    # which cluster to deploy to
    namespace: <namespace>   # which namespace in that cluster
```

ArgoCD continuously compares the manifests at `source` with live state at `destination` and syncs any differences.

---

## Step 1: Switch to Hub Context

```bash
kubectl config use-context kind-argocd-hub
```

---

## Step 2: Deploy Guestbook to Spoke 1

```bash
SPOKE1_SERVER=$(argocd cluster list -o server | grep -v "kubernetes.default" | head -1)

argocd app create guestbook-spoke1 \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path guestbook \
  --dest-server "${SPOKE1_SERVER}" \
  --dest-namespace guestbook-spoke1 \
  --project multicluster \
  --sync-policy automated \
  --auto-prune \
  --self-heal
```

| Flag | Effect |
|------|--------|
| `--sync-policy automated` | ArgoCD syncs immediately when Git changes |
| `--auto-prune` | Deletes resources removed from Git |
| `--self-heal` | Reverts manual cluster changes that drift from Git |

---

## Step 3: Deploy to Spoke 2

```bash
SPOKE2_SERVER=$(argocd cluster list -o server | grep -v "kubernetes.default" | tail -1)

argocd app create guestbook-spoke2 \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path guestbook \
  --dest-server "${SPOKE2_SERVER}" \
  --dest-namespace guestbook-spoke2 \
  --project multicluster \
  --sync-policy automated \
  --auto-prune \
  --self-heal
```

---

## Step 4: Watch the Sync

```bash
argocd app list
```

Expected within ~30 seconds:

```
NAME               CLUSTER  NAMESPACE         PROJECT       STATUS  HEALTH
guestbook-spoke1   spoke1   guestbook-spoke1  multicluster  Synced  Healthy
guestbook-spoke2   spoke2   guestbook-spoke2  multicluster  Synced  Healthy
```

Verify pods running on the actual spokes:

```bash
kubectl get pods -n guestbook-spoke1 --context kind-spoke1
kubectl get pods -n guestbook-spoke2 --context kind-spoke2
```

---

## Step 5: Observe Drift and Self-Healing

`--self-heal` means Git always wins. Test it:

```bash
# Manually scale down the deployment on spoke1
kubectl scale deployment guestbook-ui \
  -n guestbook-spoke1 --replicas=0 --context kind-spoke1

# Watch ArgoCD detect the drift and revert it
watch argocd app get guestbook-spoke1
```

Within ~30 seconds the replica count is restored. This is the core GitOps guarantee.

---

## Step 6: Declarative YAML Approach

The CLI is convenient for one-offs. The production approach is to commit Application manifests to Git and apply them:

```bash
cat << 'EOF' | kubectl apply -n argocd -f - --context kind-argocd-hub
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-spoke1
  namespace: argocd
spec:
  project: multicluster
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: HEAD
    path: nginx
  destination:
    server: REPLACE_WITH_SPOKE1_SERVER
    namespace: nginx-demo
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF
```

In Lab 5, ApplicationSets replace `REPLACE_WITH_SPOKE1_SERVER` automatically using template variables.

---

## Step 7: Browse the ArgoCD UI

Open `http://localhost:30080`. You'll see:

- All applications with their sync status
- Click an app → live graph of every Kubernetes resource (Deployment → ReplicaSet → Pods)
- Click a resource → its YAML, events, and logs

!!! tip "The graph view is your best debugging tool"
    When an app is `Degraded` or `OutOfSync`, the graph immediately highlights which resource is unhealthy.

---

## Checkpoint

- [ ] `argocd app list` shows both apps `Synced` + `Healthy`
- [ ] Pods running on `kind-spoke1` and `kind-spoke2`
- [ ] Drift test: manual scale-down was reverted automatically
- [ ] ArgoCD UI shows the resource graph

---

## Troubleshooting

### App stuck in "Progressing"

```bash
argocd app get guestbook-spoke1   # check Conditions section
kubectl describe pod -n guestbook-spoke1 --context kind-spoke1
```

### Namespace not created automatically

```bash
argocd app set guestbook-spoke1 --sync-option CreateNamespace=true
```

---

**Next:** [Lab 5: ApplicationSets](./lab5-applicationsets.md)
