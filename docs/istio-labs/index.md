# Istio Service Mesh

## What You'll Build

```
┌─────────────────────────────────────────────────────────────┐
│                      KinD Cluster                           │
│                                                             │
│  ┌─────────────────┐          ┌─────────────────┐          │
│  │ frontend        │          │ backend          │          │
│  │ [app container] │  mTLS    │ [app container]  │          │
│  │ [envoy sidecar]─┼─────────►│ [envoy sidecar]  │          │
│  └─────────────────┘          └─────────────────┘          │
│            │                          │                     │
│  ┌─────────▼──────────────────────────▼─────────┐          │
│  │              istiod (control plane)           │          │
│  │   Pilot · Citadel · Galley · Kiali · Jaeger  │          │
│  └───────────────────────────────────────────────┘          │
└─────────────────────────────────────────────────────────────┘
```

Istio service mesh on KinD: automatic mTLS, traffic management with VirtualServices and DestinationRules, and full observability via Kiali, Jaeger, and Prometheus.

## Istio Architecture

| Component | Role |
|-----------|------|
| **istiod** | Control plane — pushes config to all Envoy proxies |
| **Envoy sidecar** | Data plane — intercepts all pod traffic |
| **Pilot** | Service discovery, traffic routing rules |
| **Citadel** | Certificate authority for mTLS |
| **Kiali** | Service graph UI + configuration validation |
| **Jaeger** | Distributed tracing |

## Prerequisites

```bash
kind version        # v0.20+
kubectl version     # v1.28+
istioctl version    # v1.20+
helm version        # v3.x
docker info         # Docker must be running
```

```bash
brew install kind kubectl istioctl helm
```

## Labs Overview

| Lab | Topic | What You'll Learn |
|-----|-------|-------------------|
| [Lab 1](./lab1-setup.md) | Cluster + Istio Install | istioctl install, sidecar injection |
| [Lab 2](./lab2-traffic.md) | Traffic Management | VirtualService, DestinationRule, canary |
| [Lab 3](./lab3-mtls-security.md) | mTLS & Security | PeerAuthentication, AuthorizationPolicy |
| [Lab 4](./lab4-observability.md) | Observability | Kiali, Jaeger, Prometheus, Grafana |
| [Lab 5](./lab5-resilience.md) | Resilience Patterns | Circuit breaking, fault injection, retries |

## Time Estimate

~2 hours total

## Quick Reference

```bash
# Check Istio status
istioctl analyze

# Verify sidecar injection
kubectl get pods -n <namespace> -o jsonpath='{.items[*].spec.containers[*].name}'

# Check mTLS status
istioctl authn tls-check <pod> <service>

# Open Kiali dashboard
istioctl dashboard kiali
```

---

**Ready?** Start with [Lab 1: Cluster Setup](./lab1-setup.md)
