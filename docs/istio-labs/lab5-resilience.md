# Lab 5: Resilience Patterns

## Objective

Implement circuit breaking, fault injection, and retry/timeout policies to build a mesh that degrades gracefully under failures.

---

## Why Resilience Patterns?

In a microservices architecture, failures cascade: one slow service makes callers wait, exhausting their thread pools, which makes them slow, which makes their callers slow. Resilience patterns break this cascade:

| Pattern | Problem It Solves |
|---------|------------------|
| Circuit breaker | Stops calling a failing service, returns fast error instead |
| Timeout | Prevents a slow service from blocking callers indefinitely |
| Retry | Handles transient failures automatically |
| Fault injection | Tests that your resilience code actually works |
| Bulkhead | Limits concurrent connections to protect a service |

---

## Step 1: Circuit Breaking with DestinationRule

Configure the circuit breaker for the `details` service:

```bash
cat << 'EOF' | kubectl apply -n bookinfo -f -
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: details-circuit-breaker
spec:
  host: details
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 1
      http:
        http1MaxPendingRequests: 1
        maxRequestsPerConnection: 1
    outlierDetection:
      consecutive5xxErrors: 3
      interval: 10s
      baseEjectionTime: 30s
      maxEjectionPercent: 100
EOF
```

Settings explained:

| Setting | Effect |
|---------|--------|
| `maxConnections: 1` | Only 1 TCP connection allowed |
| `http1MaxPendingRequests: 1` | Queue max 1 request; reject the rest |
| `consecutive5xxErrors: 3` | Eject after 3 consecutive errors |
| `baseEjectionTime: 30s` | Ejected for 30 seconds |

Trigger the circuit breaker by sending concurrent requests:

```bash
# Install hey (HTTP load generator)
brew install hey

# Send 20 concurrent requests — most will be circuit-broken
hey -n 20 -c 10 http://localhost:30080/productpage
```

Watch for `503` responses — those are circuit-breaker rejections.

---

## Step 2: Fault Injection — HTTP Delay

Inject a 5-second delay into 50% of calls to the `ratings` service:

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
        delay:
          percentage:
            value: 50
          fixedDelay: 5s
      route:
        - destination:
            host: ratings
            subset: v1
EOF
```

Refresh the Bookinfo page — about half the time you'll wait 5+ seconds for the page to load. The other half loads quickly.

This simulates a slow database or external API — useful for testing how callers handle latency.

---

## Step 3: Fault Injection — HTTP Abort

Inject HTTP 500 errors into 30% of ratings requests:

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
            value: 30
          httpStatus: 500
      route:
        - destination:
            host: ratings
            subset: v1
EOF
```

Now ~30% of page loads show "Ratings service is currently unavailable". Watch this in Grafana — the ratings error rate spikes to ~30%.

!!! tip "Use fault injection in CI/CD"
    Inject faults in your staging environment and assert that your app degrades gracefully. If it doesn't, fix the fallback logic before it hits production.

---

## Step 4: Retry + Timeout Together

Combine retries and timeouts for the reviews service:

```bash
cat << 'EOF' | kubectl apply -n bookinfo -f -
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
    - reviews
  http:
    - route:
        - destination:
            host: reviews
            subset: v1
      timeout: 3s
      retries:
        attempts: 3
        perTryTimeout: 1s
        retryOn: 5xx,reset,connect-failure
EOF
```

Behavior:
- Each attempt has a 1s timeout
- Up to 3 attempts
- Total budget: 3s (matches the outer timeout)
- Retries on 5xx errors, connection resets, and connection failures

With the fault injection from Step 3 still active on ratings, reviews will retry failed ratings calls up to 3 times before giving up.

---

## Step 5: Remove Faults and Verify Recovery

```bash
# Remove fault injection
kubectl delete virtualservice ratings -n bookinfo

# Verify Grafana metrics return to normal
# Success rate should go back to ~100%
```

Watch the Kiali service graph — edges turn green as errors clear.

---

## Step 6: Combine Everything — Production Pattern

A production-ready config for `reviews`:

```bash
cat << 'EOF' | kubectl apply -n bookinfo -f -
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: reviews-production
spec:
  host: reviews
  trafficPolicy:
    connectionPool:
      http:
        http2MaxRequests: 1000
        maxRequestsPerConnection: 10
    outlierDetection:
      consecutive5xxErrors: 5
      interval: 30s
      baseEjectionTime: 60s
      maxEjectionPercent: 50
  subsets:
    - name: v1
      labels:
        version: v1
    - name: v3
      labels:
        version: v3
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: reviews-production
spec:
  hosts:
    - reviews
  http:
    - route:
        - destination:
            host: reviews
            subset: v1
          weight: 90
        - destination:
            host: reviews
            subset: v3
          weight: 10
      timeout: 5s
      retries:
        attempts: 3
        perTryTimeout: 2s
        retryOn: 5xx,reset,connect-failure,retriable-4xx
EOF
```

This gives you: canary deployment (90/10 split) + circuit breaking + retries + timeout in a single config.

---

## Clean Up

```bash
kubectl delete virtualservice --all -n bookinfo
kubectl delete destinationrule --all -n bookinfo
kind delete cluster --name istio-mesh
```

---

## Key Takeaways

| Pattern | Istio Resource | Setting |
|---------|---------------|---------|
| Circuit breaker | `DestinationRule` | `outlierDetection` |
| Bulkhead | `DestinationRule` | `connectionPool` |
| Timeout | `VirtualService` | `timeout` |
| Retry | `VirtualService` | `retries` |
| Fault injection | `VirtualService` | `fault` |
| Canary | `VirtualService` | weighted `route` |

**Congratulations!** You've built a fully observable, secured, and resilient Istio service mesh.
