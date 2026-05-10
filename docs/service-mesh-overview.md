# Service Meshes: Cilium vs Istio

## What is a Service Mesh?

A service mesh is an infrastructure layer that handles **service-to-service communication** inside a Kubernetes cluster. Instead of building networking concerns (retries, mTLS, timeouts, tracing) into every application, the mesh handles them transparently.

```
Without service mesh:              With service mesh:
┌───────────┐                      ┌───────────┐
│  Service A│──── plain HTTP ─────►│  Service B│
│           │  (no encryption,     │           │
│           │   no retries,        │           │
│           │   no tracing)        │           │
└───────────┘                      └───────────┘

┌───────────┐                      ┌───────────┐
│  Service A│                      │  Service B│
│  [proxy]  │──── mTLS ───────────►│  [proxy]  │
│           │  encrypted identity  │           │
│           │  retries, tracing    │           │
└───────────┘  circuit breaking    └───────────┘
```

Every service mesh provides the same core capabilities — they just implement them very differently.

---

## What is Cilium?

Cilium is a **CNI (Container Network Interface) plugin** that uses **Linux eBPF** to implement networking, security, and observability directly in the kernel. It replaces both kube-proxy and the traditional CNI, and optionally replaces a sidecar-based service mesh.

```
┌────────────────────────────────────────────┐
│             Linux Kernel                   │
│                                            │
│   ┌──────────────────────────────────┐    │
│   │         eBPF Programs            │    │
│   │  • Packet forwarding             │    │
│   │  • Network policy enforcement    │    │
│   │  • Load balancing (replaces      │    │
│   │    kube-proxy)                   │    │
│   │  • Flow observability (Hubble)   │    │
│   │  • mTLS identity enforcement     │    │
│   └──────────────────────────────────┘    │
└────────────────────────────────────────────┘
```

**Key point**: Cilium does all of this in the kernel — no extra container is added to your pods.

---

## What is Istio?

Istio is a **service mesh** that works by injecting an **Envoy proxy sidecar** into every pod. The sidecar intercepts all inbound and outbound traffic, giving Istio full L7 control without changing the application.

```
┌───────────────────────────────────┐
│  Your Pod                         │
│                                   │
│  ┌─────────────┐                 │
│  │ app          │                 │
│  │ container    │◄──────────────┐ │
│  └─────────────┘               │ │
│                                 │ │
│  ┌─────────────┐               │ │
│  │ envoy        │───────────────┘ │
│  │ sidecar      │ intercepts all  │
│  │ (auto-inject)│ traffic         │
│  └─────────────┘                 │
└───────────────────────────────────┘
         │
         │ TLS + telemetry + routing rules
         ▼
    istiod (control plane)
```

**Key point**: Istio's power comes from Envoy — a battle-tested L7 proxy used at massive scale.

---

## Head-to-Head Comparison

| Feature | Cilium | Istio |
|---------|--------|-------|
| **Architecture** | eBPF in kernel, no sidecars | Envoy sidecar per pod |
| **CNI** | Yes — replaces kindnet/flannel/Calico | No — needs a separate CNI |
| **kube-proxy replacement** | Yes — faster eBPF-based service routing | No |
| **mTLS** | Transparent, kernel-level (SPIFFE) | Envoy-managed, per-pod certificates |
| **L7 traffic management** | Via CiliumEnvoyConfig (embedded Envoy) | Via VirtualService + DestinationRule |
| **Canary deployments** | Supported | Rich support (weighted, header-based) |
| **Circuit breaking** | Supported | Supported (outlier detection) |
| **Network policies** | L3/L4/L7 in one CRD | Separate AuthorizationPolicy |
| **Observability** | Hubble (eBPF-native flows, HTTP, DNS) | Kiali, Jaeger, Grafana (sidecar metrics) |
| **Distributed tracing** | Basic (via Hubble) | Rich (Jaeger/Zipkin, per-request spans) |
| **Resource overhead** | Very low (~1% per node) | Higher (~50–100MB RAM per sidecar) |
| **Startup latency** | None | Sidecar injection adds ~1–2s |
| **Learning curve** | Medium | High |
| **Multi-cluster** | Cilium Cluster Mesh (built-in) | Istio multi-cluster (complex setup) |
| **FQDN / DNS policies** | Yes (eBPF DNS interception) | No |
| **Maturity** | v1.0 in 2018, CNCF graduated | v1.0 in 2018, CNCF graduated |

---

## Performance Difference

Cilium's eBPF dataplane is significantly faster than Istio's sidecar model because:

1. **No extra network hops** — eBPF runs in the kernel, on the same code path as normal packet processing
2. **No userspace context switches** — Istio's Envoy sidecar requires packets to cross from kernel to userspace twice per pod
3. **eBPF maps are O(1)** — Cilium service lookups are hash table operations vs iptables linear scans

At 50,000+ RPS, the difference becomes significant:

```
Latency at p99 (approximate):
  Without mesh:   2ms
  Cilium:         2.5ms  (+25%)
  Istio:          4ms    (+100%)
```

---

## When to Use Cilium

✅ You want to **replace kube-proxy** and get faster service routing  
✅ You need **L7 network policies** (HTTP/DNS-aware) without a full service mesh  
✅ You want **low overhead** — resource-constrained clusters, edge, IoT  
✅ You need **multi-cluster networking** (Cluster Mesh)  
✅ You want **eBPF-native observability** via Hubble without sidecar telemetry  
✅ You're starting a new cluster and want one tool to handle CNI + policy + mesh  

**Typical users**: Platform teams, clusters running thousands of pods, environments where sidecar overhead is unacceptable.

---

## When to Use Istio

✅ You need **rich traffic management** — fine-grained canary, header routing, fault injection  
✅ You want **deep distributed tracing** with per-request span correlation across services  
✅ You need **Kiali** — visual service graph with configuration validation  
✅ Your team is already invested in the **Envoy ecosystem**  
✅ You need **JWT/OIDC-based authorization** at the mesh level  
✅ You're migrating a brownfield system and need policy without touching app code  

**Typical users**: Large engineering orgs, teams with dedicated platform engineers, enterprises needing compliance-grade mTLS audit trails.

---

## Can You Use Both?

Yes — and it's increasingly common:

```
Cilium (CNI layer):    handles pod networking, kube-proxy replacement,
                       L3/L4 network policies, Cluster Mesh

Istio (mesh layer):    handles L7 traffic management, AuthorizationPolicy,
                       distributed tracing, Kiali observability
```

Cilium handles the network foundation; Istio adds application-layer control on top. Some teams run Cilium as CNI and use Cilium's native mTLS instead of Istio's, then use Istio only for traffic management features like VirtualService.

---

## Quick Decision Guide

```
Do you need to replace kube-proxy or the CNI?
  └─ YES → Cilium (Istio doesn't do this)

Do you need L7 HTTP/DNS network policies?
  └─ YES, lightweight → Cilium
  └─ YES, with JWT/OIDC auth → Istio

Do you need rich distributed tracing with Jaeger/Zipkin?
  └─ YES → Istio

Do you need multi-cluster networking?
  └─ YES, simple → Cilium Cluster Mesh
  └─ YES, with traffic management across clusters → Istio multi-cluster

Is resource overhead a concern?
  └─ YES → Cilium (no sidecar overhead)

Do you need Kiali-style service graph with config validation?
  └─ YES → Istio
```

---

## Labs

- **[Cilium Service Mesh Labs](./cilium-mesh-labs/index.md)** — eBPF CNI, transparent mTLS, L7 policies, Hubble
- **[Istio Service Mesh Labs](./istio-labs/index.md)** — Sidecar mesh, traffic management, security policies, full observability stack
