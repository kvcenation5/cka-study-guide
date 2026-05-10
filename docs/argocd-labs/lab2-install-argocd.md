# Lab 2: Installing ArgoCD on the Hub Cluster

## Objective

Install ArgoCD on the hub cluster, expose its UI via NodePort, and log in with the CLI.

---

## ArgoCD Components

```
┌──────────────────────────────────────────────────────┐
│  argocd namespace                                     │
│                                                       │
│  argocd-server          ← UI + API + CLI endpoint    │
│  argocd-repo-server     ← clones Git repos           │
│  argocd-application-controller  ← reconcile loop     │
│  argocd-dex-server      ← SSO / OIDC (optional)     │
│  argocd-redis           ← cache                      │
└──────────────────────────────────────────────────────┘
```

- **argocd-server**: The API server and web UI — what you log into.
- **argocd-repo-server**: Clones your Git repos and renders Helm/Kustomize/plain YAML.
- **argocd-application-controller**: Watches Application CRDs, diffs desired vs live state, triggers syncs.

---

## Step 1: Switch to Hub Context

```bash
kubectl config use-context kind-argocd-hub
kubectl config current-context   # confirm: kind-argocd-hub
```

---

## Step 2: Install ArgoCD

```bash
kubectl create namespace argocd

kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Wait for all pods:

```bash
kubectl wait --for=condition=Ready pod \
  -l app.kubernetes.io/name=argocd-server \
  -n argocd --timeout=120s

kubectl get pods -n argocd
```

Expected — all `1/1 Running`:

```
NAME                                                READY   STATUS
argocd-application-controller-0                     1/1     Running
argocd-dex-server-xxxxxxxxxx-xxxxx                  1/1     Running
argocd-notifications-controller-xxxxxxxxxx-xxxxx    1/1     Running
argocd-redis-xxxxxxxxxx-xxxxx                       1/1     Running
argocd-repo-server-xxxxxxxxxx-xxxxx                 1/1     Running
argocd-server-xxxxxxxxxx-xxxxx                      1/1     Running
```

---

## Step 3: Expose the UI via NodePort

By default `argocd-server` is a ClusterIP service. Patch it to NodePort so the host port mappings from Lab 1 kick in:

```bash
kubectl patch svc argocd-server -n argocd \
  --type='json' \
  -p='[
    {"op":"replace","path":"/spec/type","value":"NodePort"},
    {"op":"add","path":"/spec/ports/0/nodePort","value":30080},
    {"op":"add","path":"/spec/ports/1/nodePort","value":30443}
  ]'
```

Verify:

```bash
kubectl get svc argocd-server -n argocd
# TYPE: NodePort   PORT(S): 80:30080/TCP,443:30443/TCP
```

Open `http://localhost:30080` — you should see the ArgoCD login page.

!!! tip "Why not LoadBalancer?"
    KinD has no cloud load balancer. NodePort + the `extraPortMappings` from Lab 1 is the simplest path from your Mac browser to the ArgoCD pod.

---

## Step 4: Get the Initial Admin Password

```bash
kubectl get secret argocd-initial-admin-secret \
  -n argocd \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

---

## Step 5: Log In

```bash
argocd login localhost:30080 \
  --username admin \
  --password <paste-password-here> \
  --insecure
```

`--insecure` skips TLS verification — fine for local KinD.

```bash
argocd cluster list
# Should show: https://kubernetes.default.svc   in-cluster   Successful
```

ArgoCD always registers the hub itself as `in-cluster` automatically.

---

## Step 6: Change the Admin Password

```bash
argocd account update-password \
  --current-password <initial-password> \
  --new-password <your-new-password>

kubectl delete secret argocd-initial-admin-secret -n argocd
```

---

## Key CRDs Installed

```bash
kubectl get crd | grep argoproj
```

| CRD | Purpose |
|-----|---------|
| `applications.argoproj.io` | One app deployed to one cluster |
| `applicationsets.argoproj.io` | Template that generates many Applications |
| `appprojects.argoproj.io` | Tenant/RBAC boundary |

---

## Checkpoint

- [ ] All ArgoCD pods `Running`
- [ ] `http://localhost:30080` shows the login page
- [ ] `argocd login` succeeds
- [ ] `argocd cluster list` shows `in-cluster`

---

## Troubleshooting

### Browser shows "connection refused" on port 30080

```bash
kubectl get svc argocd-server -n argocd -o yaml | grep nodePort
docker inspect argocd-hub-control-plane | grep -A5 "30080"
```

### Pod stuck in CrashLoopBackOff

```bash
kubectl logs -n argocd <pod-name>
kubectl describe pod -n argocd <pod-name>
```

---

**Next:** [Lab 3: Registering Spoke Clusters](./lab3-register-clusters.md)
