# Lab 4: Observability with Kiali, Jaeger, and Prometheus

## Objective

Use Istio's observability stack to visualize the service graph, trace requests end-to-end, and monitor service health with dashboards.

---

## The Observability Stack

```
Your App (Envoy sidecar)
  │
  ├── Metrics ──────────► Prometheus ──► Grafana (dashboards)
  ├── Traces ───────────► Jaeger (distributed tracing)
  └── Service graph ────► Kiali (topology + config validation)
```

All three work automatically once sidecars are injected — no application instrumentation needed.

---

## Step 1: Generate Sustained Traffic

The dashboards are only interesting with live traffic. Run this in a background terminal:

```bash
for i in $(seq 1 1000); do
  curl -s "http://localhost:30080/productpage" > /dev/null
  sleep 0.5
done
```

---

## Step 2: Kiali — Service Graph

```bash
istioctl dashboard kiali
```

In the Kiali UI:

1. Click **Graph** in the left sidebar
2. Select namespace `bookinfo`
3. Set the time range to "Last 1m"

You'll see a live service graph showing:
- Each microservice as a node
- Request rates on edges
- Health indicators (green/yellow/red)
- Which version of `reviews` is receiving traffic

**Try changing the VirtualService** (from Lab 2) and watch the graph update in real time.

### Kiali Configuration Validation

```bash
# Kiali also validates your Istio config
istioctl analyze -n bookinfo
```

If you have misconfigured VirtualServices or missing DestinationRules, Kiali highlights them with warnings in the UI.

---

## Step 3: Jaeger — Distributed Tracing

```bash
istioctl dashboard jaeger
```

In the Jaeger UI:

1. Select service `productpage.bookinfo`
2. Click **Find Traces**
3. Click a trace

A single user request to `/productpage` generates a trace spanning all four services:

```
productpage (12ms)
  ├── details (2ms)
  └── reviews (8ms)
        └── ratings (3ms)
```

Each span shows:
- Service name and version
- HTTP method, path, status code
- Duration
- Any errors

!!! tip "Finding latency bottlenecks"
    Sort traces by duration (longest first) to instantly find which service is slowing down the request chain.

---

## Step 4: Prometheus + Grafana — Metrics

```bash
istioctl dashboard grafana
```

Navigate to **Istio Service Dashboard**. Key metrics per service:

| Metric | What to Watch |
|--------|--------------|
| Request Volume | RPS by source and destination |
| Success Rate | % of non-5xx responses |
| P50/P90/P99 Latency | Latency percentiles |
| TCP Connections | Active connections |

**Useful PromQL queries:**

```promql
# Request rate to reviews service
rate(istio_requests_total{destination_service="reviews.bookinfo.svc.cluster.local"}[1m])

# Error rate (5xx)
rate(istio_requests_total{
  destination_service="reviews.bookinfo.svc.cluster.local",
  response_code=~"5.*"
}[1m])

# P99 latency
histogram_quantile(0.99,
  rate(istio_request_duration_milliseconds_bucket{
    destination_service="reviews.bookinfo.svc.cluster.local"
  }[5m])
)
```

---

## Step 5: Inject a Fault and Watch It Propagate

Inject a 50% failure rate on the ratings service:

```bash
cat << 'EOF' | kubectl apply -n bookinfo -f -
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: ratings
spec:
  hosts:
    - ratings
  http:
    - fault:
        abort:
          percentage:
            value: 50
          httpStatus: 500
      route:
        - destination:
            host: ratings
            subset: v1
EOF
```

Watch in Grafana: the `ratings` success rate drops to ~50%. In Kiali: the edge from `reviews` to `ratings` turns red. In Jaeger: traces for `/productpage` show span errors on the `ratings` service.

Remove the fault:

```bash
kubectl delete virtualservice ratings -n bookinfo
```

---

## Step 6: Access Logs via Envoy

Each sidecar logs every request. Access them directly:

```bash
kubectl logs -n bookinfo \
  $(kubectl get pod -n bookinfo -l app=productpage -o name | head -1) \
  -c istio-proxy \
  --tail=20
```

Envoy access log format shows: timestamp, method, path, response code, bytes, duration, upstream cluster.

---

## Checkpoint

- [ ] Kiali service graph shows live traffic with health indicators
- [ ] Jaeger traces show the full request span tree
- [ ] Grafana Istio dashboard shows RPS, success rate, latency
- [ ] Fault injection causes visible error spike in all three tools
- [ ] Fault removed and metrics recover

---

**Next:** [Lab 5: Resilience Patterns](./lab5-resilience.md)
