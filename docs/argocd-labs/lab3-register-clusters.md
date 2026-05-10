# Lab 3: Registering Spoke Clusters with ArgoCD

## Objective

Add `kind-spoke1` and `kind-spoke2` to ArgoCD so the hub can deploy applications to them.

---

## How ArgoCD Connects to External Clusters

ArgoCD stores external cluster credentials as Kubernetes Secrets in the `argocd` namespace. Each secret contains:

- The cluster API server URL
- A service account token with cluster-admin permissions
- The cluster CA certificate

`argocd cluster add` automates this: it reads your local kubeconfig, creates a `argocd-manager` ServiceAccount on the target cluster, and stores its credentials as a Secret on the hub.

```
Hub cluster (ArgoCD)
  └── argocd namespace
        ├── Secret: cluster-spoke1   ← credentials to reach spoke1
        └── Secret: cluster-spoke2   ← credentials to reach spoke2
```

---

## Step 1: Confirm Spoke Contexts Exist

```bash
kubectl config get-contexts
# kind-spoke1 and kind-spoke2 must be present
```

---

## Step 2: Get Docker-Internal IPs for the Spokes

!!! warning "127.0.0.1 won't work"
    KinD kubeconfigs use `127.0.0.1` as the API server address (your Mac's localhost). But ArgoCD runs *inside* the hub Docker container — from there, `127.0.0.1` is the hub itself, not a spoke. You must use each spoke's container IP on the `kind` Docker bridge network.

```bash
SPOKE1_IP=$(docker inspect spoke1-control-plane \
  --format '{{ .NetworkSettings.Networks.kind.IPAddress }}')
SPOKE2_IP=$(docker inspect spoke2-control-plane \
  --format '{{ .NetworkSettings.Networks.kind.IPAddress }}')

echo "spoke1: $SPOKE1_IP"
echo "spoke2: $SPOKE2_IP"
```

---

## Step 3: Register Both Spokes

```bash
argocd cluster add kind-spoke1 \
  --name spoke1 \
  --server "https://${SPOKE1_IP}:6443" \
  --insecure \
  --yes

argocd cluster add kind-spoke2 \
  --name spoke2 \
  --server "https://${SPOKE2_IP}:6443" \
  --insecure \
  --yes
```

Expected output per cluster:

```
INFO[0001] ServiceAccount "argocd-manager" created in namespace "kube-system"
INFO[0001] ClusterRole "argocd-manager-role" created
INFO[0001] ClusterRoleBinding "argocd-manager-role-binding" created
Cluster 'https://172.18.0.x:6443' added
```

---

## Step 4: Verify

```bash
argocd cluster list
```

Expected:

```
SERVER                          NAME        VERSION   STATUS
https://kubernetes.default.svc  in-cluster  1.31      Successful
https://172.18.0.x:6443         spoke1      1.31      Successful
https://172.18.0.y:6443         spoke2      1.31      Successful
```

All three show `Successful`. Also verify the secrets ArgoCD stored:

```bash
kubectl get secrets -n argocd | grep cluster
```

---

## Step 5: Inspect What Was Created on the Spoke

```bash
kubectl get serviceaccount argocd-manager \
  -n kube-system --context kind-spoke1

kubectl get clusterrolebinding argocd-manager-role-binding \
  --context kind-spoke1
```

!!! question "Why cluster-admin on spokes?"
    ArgoCD needs to create and manage arbitrary resources (Deployments, CRDs, etc.) across all namespaces. `cluster-admin` is the default. In production, scope it with `--namespace` to deploy only to specific namespaces.

---

## Step 6: Create an AppProject

AppProjects are ArgoCD's tenant boundary — they control which Git repos and cluster destinations are permitted:

```bash
cat << 'EOF' | kubectl apply -n argocd -f - --context kind-argocd-hub
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: multicluster
  namespace: argocd
spec:
  description: Multi-cluster GitOps project
  sourceRepos:
    - '*'
  destinations:
    - server: '*'
      namespace: '*'
  clusterResourceWhitelist:
    - group: '*'
      kind: '*'
EOF
```

!!! warning "Production note"
    Replace `'*'` wildcards with your Git org URL and specific cluster servers + namespaces.

---

## Checkpoint

- [ ] `argocd cluster list` shows spoke1 and spoke2 as `Successful`
- [ ] Cluster secrets exist in the `argocd` namespace
- [ ] `argocd-manager` ServiceAccount on both spokes
- [ ] `multicluster` AppProject created

---

## Troubleshooting

### Cluster shows "Unknown" status

```bash
# Test connectivity from inside the hub cluster
kubectl run conn-test --image=curlimages/curl --restart=Never \
  --context kind-argocd-hub \
  -- curl -k "https://${SPOKE1_IP}:6443/healthz"
kubectl logs conn-test --context kind-argocd-hub
kubectl delete pod conn-test --context kind-argocd-hub
```

If you get `connection refused`, the IP is wrong — re-run the `docker inspect` command.

### Re-register after IP changes

KinD container IPs can change if Docker restarts. Re-register:

```bash
argocd cluster rm "https://${OLD_IP}:6443"
argocd cluster add kind-spoke1 --name spoke1 \
  --server "https://${NEW_SPOKE1_IP}:6443" --insecure --yes
```

---

**Next:** [Lab 4: Deploying Applications to Multiple Clusters](./lab4-deploy-apps.md)
