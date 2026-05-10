# Lab 2: Traffic Management

## Objective

Use Istio's `VirtualService` and `DestinationRule` to control how traffic is routed between service versions — enabling canary deployments, weighted splits, and header-based routing.

---

## Key Resources

| Resource | What It Does |
|----------|-------------|
| `VirtualService` | Defines routing rules — which version gets traffic |
| `DestinationRule` | Defines subsets (versions) and load balancing policy |
| `Gateway` | Controls inbound/outbound traffic at the mesh edge |

---

## Step 1: Understand the Bookinfo Reviews Service

The `reviews` service has three versions deployed simultaneously:

- **v1**: No star ratings
- **v2**: Black stars
- **v3**: Red stars

Without any Istio rules, requests round-robin across all three. You'll see different star colors on each page refresh.

---

## Step 2: Create Destination Rules (Define Subsets)

```bash
kubectl apply -n bookinfo \
  -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/bookinfo/networking/destination-rule-all.yaml
```

This creates DestinationRules that label the three `reviews` versions as subsets `v1`, `v2`, `v3`.

View them:

```bash
kubectl get destinationrules -n bookinfo -o yaml
```

---

## Step 3: Route All Traffic to v1

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
          weight: 100
EOF
```

Refresh `http://localhost:30080/productpage` several times — you should now always see v1 (no stars).

---

## Step 4: Canary — Send 20% to v3

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
          weight: 80
        - destination:
            host: reviews
            subset: v3
          weight: 20
EOF
```

Refresh the page ~10 times — roughly 2 in 10 requests show red stars (v3).

!!! tip "This is how canary deployments work in production"
    Shift weight gradually: 5% → 20% → 50% → 100% while monitoring error rates in Grafana. Roll back instantly by setting v3 weight back to 0.

---

## Step 5: Header-Based Routing (A/B Testing)

Route specific users to v2 based on a cookie:

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
    - match:
        - headers:
            end-user:
              exact: jason
      route:
        - destination:
            host: reviews
            subset: v2
    - route:
        - destination:
            host: reviews
            subset: v1
          weight: 100
EOF
```

Log into the Bookinfo app as user `jason` (any password) — you'll see black stars (v2). Log out — you see v1. Everyone else sees v1.

---

## Step 6: Timeout

Add a 1-second timeout to the `ratings` service call:

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
    - route:
        - destination:
            host: ratings
            subset: v1
      timeout: 1s
EOF
```

Now inject a 2-second delay into the ratings service (Lab 5 covers this in depth). The reviews service will get an error from ratings because of the timeout — you'll see "Ratings service is currently unavailable" on the productpage.

---

## Step 7: Retry Policy

Configure automatic retries on failure:

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
    - route:
        - destination:
            host: ratings
            subset: v1
      retries:
        attempts: 3
        perTryTimeout: 2s
        retryOn: gateway-error,connect-failure,retriable-4xx
EOF
```

On transient failures, Istio retries up to 3 times before returning an error to the caller.

---

## Checkpoint

- [ ] `DestinationRules` created for all services
- [ ] All traffic pinned to reviews v1
- [ ] Canary split: 80/20 between v1 and v3
- [ ] Header-based routing: user `jason` → v2
- [ ] Timeout and retry policies applied to ratings

---

**Next:** [Lab 3: mTLS & Security](./lab3-mtls-security.md)
