# Cilium Service Mesh

## What You'll Build

```
┌─────────────────────────────────────────────────────────┐
│                    KinD Cluster                         │
│                                                         │
│  ┌──────────┐   mTLS    ┌──────────┐                   │
│  │ frontend │◄─────────►│ backend  │                   │
│  │  pod     │           │  pod     │                   │
│  └──────────┘           └──────────┘                   │
│       │                      │                         │
│  ┌────▼──────────────────────▼────┐                    │
│  │        Cilium eBPF Dataplane   │                    │
│  │  mTLS · L7 Policies · Hubble  │                    │
│  └────────────────────────────────┘                    │
└─────────────────────────────────────────────────────────┘
```

Cilium as a full service mesh: transparent mTLS between pods, HTTP/gRPC-aware network policies, and deep traffic observability via Hubble — all without sidecars.

## Cilium vs Traditional Service Meshes

| Feature | Cilium (eBPF) | Istio (sidecar) |
|---------|--------------|-----------------|
| Architecture | Kernel-level eBPF | Envoy sidecar per pod |
| Overhead | Very low (~1%) | Higher (extra container per pod) |
| mTLS | Transparent, no config per pod | Requires injection + PeerAuthentication |
| L7 visibility | Hubble (flows, HTTP, DNS) | Kiali + Jaeger |
| Network policies | L3/L4/L7 in one CRD | Separate AuthorizationPolicy |
| Learning curve | Medium | High |

## Prerequisites

```bash
kind version        # v0.20+
kubectl version     # v1.28+
cilium version      # v0.15+ (CLI)
helm version        # v3.x
docker info         # Docker must be running
```

```bash
brew install kind kubectl cilium-cli helm
```

## Labs Overview

| Lab | Topic | What You'll Learn |
|-----|-------|-------------------|
| [Lab 1](./lab1-setup.md) | Cluster + Cilium Install | KinD without kube-proxy, eBPF dataplane |
| [Lab 2](./lab2-mtls.md) | Transparent mTLS | Mutual TLS between pods, no sidecars |
| [Lab 3](./lab3-l7-policies.md) | L7 Network Policies | HTTP-aware allow/deny rules |
| [Lab 4](./lab4-hubble.md) | Hubble Observability | Flow visibility, service map, UI |
| [Lab 5](./lab5-traffic.md) | Traffic Management | Load balancing, canary, circuit breaking |

## Time Estimate

~2 hours total

## Quick Reference

```bash
# Cilium status
cilium status

# Hubble observe flows
hubble observe --follow

# Check policy enforcement
cilium policy get

# Test connectivity
cilium connectivity test
```

---

**Ready?** Start with [Lab 1: Cluster Setup](./lab1-setup.md)
