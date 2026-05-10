# Lab 4: Hubble Observability

## Objective

Use Hubble to get deep visibility into network flows, inspect HTTP requests, view the service dependency map, and set up the Hubble UI.

---

## What is Hubble?

Hubble is Cilium's built-in observability layer. It hooks into the eBPF dataplane and exposes:

- **Flow logs**: every connection between pods, with verdict (allowed/dropped)
- **HTTP visibility**: method, path, status code, latency
- **DNS visibility**: queries and responses
- **Service map**: auto-generated dependency graph
- **Metrics**: Prometheus-compatible flow metrics

No agents, no sidecars — it reads directly from the eBPF maps Cilium already maintains.

---

## Step 1: Enable the Hubble Port-Forward

```bash
# Start the Hubble relay port-forward (run in background)
cilium hubble port-forward &

# Verify the relay is reachable
hubble status
```

Expected:

```
Healthcheck (via localhost:4245): Ok
Current/Max Flows: 4096/4096 (100.00%)
Flows/s: 12.34
Connected Nodes: 3/3
```

---

## Step 2: Observe Live Flows

```bash
# Watch all flows in the demo namespace
hubble observe --namespace demo --follow
```

Generate traffic in another terminal:

```bash
for i in $(seq 1 10); do
  kubectl exec -n demo \
    $(kubectl get pod -n demo -l app=xwing -o name | head -1) \
    -- curl -s deathstar.demo.svc.cluster.local/v1/status
done
```

Back in the first terminal you'll see each flow:

```
TIMESTAMP   SOURCE                        DESTINATION                   TYPE     VERDICT   SUMMARY
19:32:01    demo/xwing-xxx                demo/deathstar-xxx            L7       FORWARDED HTTP/1.1 GET /v1/status
19:32:01    demo/deathstar-xxx            demo/xwing-xxx                L7       FORWARDED HTTP/1.1 200 OK
```

---

## Step 3: Filter Flows

```bash
# Only dropped traffic (policy violations)
hubble observe --namespace demo --verdict DROPPED --follow

# Only HTTP traffic
hubble observe --namespace demo --protocol http --follow

# From a specific pod
hubble observe --namespace demo \
  --from-pod demo/xwing \
  --follow

# Show DNS queries
hubble observe --namespace demo --protocol dns --follow

# JSON output for parsing
hubble observe --namespace demo --follow --output json \
  | jq '{src: .flow.source.pod_name, dst: .flow.destination.pod_name, verdict: .flow.verdict}'
```

---

## Step 4: Enable HTTP Visibility

By default, Hubble sees L3/L4 flows. To get HTTP method/path/status in the logs, annotate the namespace or deployment:

```bash
# Enable L7 HTTP visibility for the deathstar service
kubectl annotate pod -n demo \
  -l app=deathstar \
  policy.cilium.io/proxy-visibility="<Ingress/80/TCP/HTTP>"
```

Now re-run the curl loop and observe — HTTP details appear in the flow log:

```
demo/xwing-xxx → demo/deathstar-xxx   HTTP GET /v1/status   200 OK   1ms
```

---

## Step 5: Open the Hubble UI

```bash
cilium hubble ui
```

This opens the Hubble web UI in your browser automatically. You'll see:

- **Flow table**: live stream of all network flows
- **Service map**: auto-drawn graph of which services talk to which
- **Namespace filter**: isolate a single namespace
- **Verdict filter**: quickly find dropped flows

The service map is especially useful — it shows your actual runtime dependency graph without any manual configuration.

---

## Step 6: Hubble Metrics in Prometheus

Cilium exports Hubble flow metrics automatically. Check them:

```bash
# Port-forward to Cilium's metrics endpoint
kubectl port-forward -n kube-system \
  $(kubectl get pod -n kube-system -l k8s-app=cilium -o name | head -1) \
  9965:9965 &

curl -s localhost:9965/metrics | grep hubble_flows_processed
```

Key metrics:

| Metric | What It Measures |
|--------|-----------------|
| `hubble_flows_processed_total` | Total flows by verdict and direction |
| `hubble_http_requests_total` | HTTP requests by method, status, service |
| `hubble_drop_total` | Dropped flows by reason and direction |

---

## Checkpoint

- [ ] `hubble status` shows all nodes connected
- [ ] Live flows visible with `hubble observe --follow`
- [ ] HTTP visibility annotation applied, method/path visible in flows
- [ ] Dropped flows visible when L7 policy blocks a request
- [ ] Hubble UI open with service map

---

**Next:** [Lab 5: Traffic Management](./lab5-traffic.md)
