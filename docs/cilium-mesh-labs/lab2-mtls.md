# Lab 2: Transparent mTLS with Cilium

## Objective

Enable mutual TLS between pods without any application changes or sidecars. Cilium handles certificate management and encryption at the kernel level via eBPF.

---

## How Cilium mTLS Works

Traditional service meshes inject a sidecar to handle mTLS. Cilium does it differently:

```
Traditional (Istio):           Cilium:
┌──────────────────┐           ┌──────────────────┐
│ [app]            │           │ [app]            │
│ [envoy sidecar]  │           │                  │
│   handles mTLS   │           │ eBPF hook in     │
└──────────────────┘           │ kernel handles   │
                               │ encryption       │
                               └──────────────────┘
```

- No sidecar container = no extra memory/CPU per pod
- Encryption happens in the kernel network stack
- Certificates are managed by Cilium using SPIFFE/SPIRE identity

---

## Step 1: Enable Mutual Authentication Policy

Cilium uses `CiliumNetworkPolicy` with mutual authentication:

```bash
cat << 'EOF' | kubectl apply -f -
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: require-mtls
  namespace: demo
spec:
  endpointSelector:
    matchLabels:
      app: deathstar
  ingress:
    - fromEndpoints:
        - matchLabels:
            app: xwing
      authentication:
        mode: required
EOF
```

This says: the `deathstar` pod will only accept connections from the `xwing` pod, and that connection must be mutually authenticated (both sides prove identity).

---

## Step 2: Verify mTLS is Enforced

Test from the xwing pod (should succeed — mTLS authenticated):

```bash
kubectl exec -n demo -it \
  $(kubectl get pod -n demo -l app=xwing -o name | head -1) \
  -- curl -s -XPOST deathstar.demo.svc.cluster.local/v1/request-landing
```

Expected: `Ship landed`

Test from an unauthorized pod (should be dropped):

```bash
kubectl run unauthorized --image=curlimages/curl --restart=Never \
  -n demo -- curl -s --max-time 3 \
  deathstar.demo.svc.cluster.local/v1/request-landing

kubectl logs unauthorized -n demo
# Should show: connection refused or timeout
kubectl delete pod unauthorized -n demo
```

---

## Step 3: Inspect the Identity

Cilium assigns a numeric security identity to each workload based on its labels:

```bash
# List all Cilium endpoint identities
kubectl exec -n kube-system \
  $(kubectl get pod -n kube-system -l k8s-app=cilium -o name | head -1) \
  -- cilium endpoint list
```

Look for your demo pods — each has an `IDENTITY` number. This is what Cilium uses for policy enforcement, not IP addresses.

```bash
# Inspect a specific endpoint
kubectl exec -n kube-system \
  $(kubectl get pod -n kube-system -l k8s-app=cilium -o name | head -1) \
  -- cilium endpoint get <endpoint-id>
```

---

## Step 4: Enable WireGuard Node-to-Node Encryption

For encrypting traffic between nodes (not just pod identity verification):

```bash
cilium upgrade \
  --set encryption.enabled=true \
  --set encryption.type=wireguard

# Verify WireGuard is active
kubectl exec -n kube-system \
  $(kubectl get pod -n kube-system -l k8s-app=cilium -o name | head -1) \
  -- cilium status | grep Encryption
```

Expected: `Encryption: WireGuard`

This encrypts all inter-node traffic at the network level — complementing the identity-based mTLS at the pod level.

---

## Step 5: Observe mTLS Flows in Hubble

```bash
# Enable Hubble port-forward
cilium hubble port-forward &

# Observe flows with authentication info
hubble observe \
  --namespace demo \
  --follow \
  --output json | jq '.flow | {src: .source.pod_name, dst: .destination.pod_name, verdict: .verdict, auth: .auth_type}'
```

You'll see flows annotated with `SPIRE` authentication type for mTLS-verified connections.

---

## Checkpoint

- [ ] `CiliumNetworkPolicy` with `authentication.mode: required` applied
- [ ] xwing → deathstar succeeds
- [ ] Unauthorized pod → deathstar is dropped
- [ ] WireGuard encryption enabled between nodes
- [ ] Hubble shows authenticated flows

---

**Next:** [Lab 3: L7 Network Policies](./lab3-l7-policies.md)
