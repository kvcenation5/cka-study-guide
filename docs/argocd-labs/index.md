# Multi-Cluster GitOps with ArgoCD

## What You'll Build

```
┌──────────────────────────────────────────────────────────────────┐
│                    kind-argocd-hub (Hub Cluster)                 │
│                                                                  │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │  ArgoCD Server  │  Repo Server  │  App Controller       │   │
│   └─────────────────────────────────────────────────────────┘   │
│         │  Watches Git Repos                                     │
│         │  Syncs manifests to spoke clusters                     │
└─────────────────────┬──────────────────────┬────────────────────┘
                      │                      │
           ┌──────────▼──────────┐  ┌────────▼────────────┐
           │    kind-spoke1      │  │    kind-spoke2       │
           │  (Target Cluster)   │  │  (Target Cluster)    │
           │                     │  │                      │
           │  apps deployed here │  │  apps deployed here  │
           └─────────────────────┘  └──────────────────────┘
```

One ArgoCD instance on the hub cluster manages application deployments across multiple spoke clusters — the hub/spoke GitOps model.

## Why This Matters

| Problem | ArgoCD Multi-Cluster Solution |
|---------|-------------------------------|
| Manually applying manifests to each cluster | ArgoCD syncs from Git automatically |
| Drift between clusters and desired state | Continuous reconciliation detects + corrects drift |
| Hard to audit what's deployed where | Single ArgoCD UI shows all clusters |
| Rollout coordination across clusters | ApplicationSets target clusters by label |
| Environment promotion (dev → staging → prod) | AppProject policies enforce promotion gates |

## What is ArgoCD?

ArgoCD is a declarative GitOps continuous delivery tool for Kubernetes:

- **GitOps Engine**: Git is the single source of truth; ArgoCD reconciles cluster state to match
- **Multi-Cluster**: One ArgoCD instance can manage hundreds of clusters
- **ApplicationSets**: Template-driven apps targeting clusters by label, name, or generator
- **App of Apps**: Parent Application manages child Applications — scales GitOps across teams
- **RBAC**: Fine-grained access control per project, cluster, and namespace

## Prerequisites Check

```bash
# Verify required tools
kind version        # v0.20+
kubectl version     # v1.28+
argocd version      # v2.9+ (CLI)
helm version        # v3.x
docker info         # Docker must be running
```

Install missing tools:

```bash
brew install kind kubectl argocd helm
```

## Labs Overview

| Lab | Topic | What You'll Learn |
|-----|-------|-------------------|
| [Lab 1](./lab1-kind-clusters.md) | Create KinD Clusters | Hub + spoke cluster config |
| [Lab 2](./lab2-install-argocd.md) | Install ArgoCD | ArgoCD on hub, expose UI |
| [Lab 3](./lab3-register-clusters.md) | Register Spoke Clusters | argocd cluster add, secrets |
| [Lab 4](./lab4-deploy-apps.md) | Deploy Applications | Target specific clusters from ArgoCD |
| [Lab 5](./lab5-applicationsets.md) | ApplicationSets | Template apps across all clusters |

## Time Estimate

- Lab 1–2: ~20 minutes (clusters + ArgoCD)
- Lab 3–4: ~25 minutes (register + first app)
- Lab 5: ~30 minutes (ApplicationSets)

Total: ~1.5 hours

## Quick Reference

```bash
# Switch between cluster contexts
kubectl config use-context kind-argocd-hub
kubectl config use-context kind-spoke1
kubectl config use-context kind-spoke2

# ArgoCD CLI login (after Lab 2)
argocd login localhost:30080 --username admin --insecure

# List registered clusters
argocd cluster list

# List all applications
argocd app list
```

---

**Ready?** Start with [Lab 1: Creating KinD Clusters](./lab1-kind-clusters.md)
