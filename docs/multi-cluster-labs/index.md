# Multi-Cluster Networking with Cilium Cluster Mesh

## What You'll Build

```
┌─────────────────────┐                    ┌─────────────────────┐
│      Cluster 1      │                    │      Cluster 2      │
│     (kind-mesh1)    │                    │     (kind-mesh2)    │
│                     │    ClusterMesh     │                     │
│  ┌───────────────┐  │◄──────────────────►│  ┌───────────────┐  │
│  │ frontend-pod  │  │   Encrypted tunnel │  │ backend-pod   │  │
│  │               │──┼────────────────────┼──│               │  │
│  └───────────────┘  │  Cross-cluster     │  └───────────────┘  │
│                     │  service discovery │                     │
│  Cilium Agent       │                    │  Cilium Agent       │
└─────────────────────┘                    └─────────────────────┘
```

Two KinD clusters connected via Cilium Cluster Mesh, allowing pods in one cluster to discover and communicate with services in another cluster.

## Why This Matters

Multi-cluster setups solve real problems:

| Problem | Solution |
|---------|----------|
| Single cluster failure takes everything down | Workloads spread across clusters |
| Region latency for global users | Clusters in multiple regions |
| Cluster upgrade requires downtime | Migrate traffic to another cluster |
| Resource limits on single cluster | Scale horizontally across clusters |

## What is Cilium Cluster Mesh?

Cilium is a CNI (Container Network Interface) plugin that uses eBPF for networking. Cluster Mesh extends this across clusters:

- **Shared Service Discovery**: Services in cluster1 can be accessed from cluster2
- **Global Services**: Same service name resolves to pods in ALL connected clusters
- **Cross-cluster Network Policies**: Apply policies spanning multiple clusters
- **Encrypted Tunnels**: Traffic between clusters is encrypted by default

## Prerequisites Check

Before starting, verify you have these installed:

```bash
# Check each tool
kind version          # Should show v0.20+
cilium version        # Should show v0.15+ (CLI)
kubectl version       # Should show v1.28+
helm version          # Should show v3.x
docker info           # Docker must be running
```

Install missing tools:

```bash
brew install kind cilium-cli kubectl helm
```

## Labs Overview

| Lab | Topic | What You'll Learn |
|-----|-------|-------------------|
| [Lab 1](./lab1-kind-clusters.md) | Create KinD Clusters | Multi-cluster KinD config, networking setup |
| [Lab 2](./lab2-install-cilium.md) | Install Cilium | CNI installation, verification, troubleshooting |
| [Lab 3](./lab3-cluster-mesh.md) | Enable Cluster Mesh | Mesh connection, certificate exchange |
| [Lab 4](./lab4-global-services.md) | Global Services | Cross-cluster service discovery |
| [Lab 5](./lab5-challenges.md) | Challenges | Test your understanding |

## Time Estimate

- Lab 1-2: ~20 minutes (cluster creation + Cilium)
- Lab 3-4: ~30 minutes (mesh + services)
- Lab 5: ~30 minutes (challenges)

Total: ~1.5 hours for full hands-on experience

## Quick Reference

Commands you'll use frequently:

```bash
# Switch between clusters
kubectl config use-context kind-mesh1
kubectl config use-context kind-mesh2

# Check Cilium status
cilium status --context kind-mesh1
cilium status --context kind-mesh2

# Check Cluster Mesh status
cilium clustermesh status --context kind-mesh1

# View all contexts
kubectl config get-contexts
```

---

**Ready?** Start with [Lab 1: Creating KinD Clusters](./lab1-kind-clusters.md)
