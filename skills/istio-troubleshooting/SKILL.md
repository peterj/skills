---
name: istio-troubleshooting
description: Diagnoses and resolves common Istio service mesh problems across traffic management, security, observability, and upgrades. Use when debugging Istio networking issues (503 errors, route rules not working, TLS mismatches, gateway 404s), security problems (authorization policies, mTLS, JWT authentication), observability gaps (missing traces, Grafana output issues), EnvoyFilter breakage, or when upgrading Istio and migrating from EnvoyFilter to first-class APIs.
---

# Istio Troubleshooting Guide

## Quick start: Diagnose a failing request

1. **Check Envoy access logs** for response flags:
   ```bash
   kubectl logs PODNAME -c istio-proxy -n NAMESPACE
   ```
2. Common response flags:
   - `NR` — No route configured. Check `DestinationRule` or `VirtualService`.
   - `UO` — Upstream overflow (circuit breaking). Check circuit breaker in `DestinationRule`.
   - `UF` — Failed to connect upstream. Check for mTLS configuration conflict.
3. If the issue is a **503 after applying a DestinationRule**, see [TLS/mTLS conflicts](#503-after-destinationrule).
4. If **route rules have no effect**, see [Route rule issues](#route-rules-not-working).
5. For **authorization policy** problems, see [security-issues.md](security-issues.md).
6. For **upgrade/migration** issues, see [upgrade-issues.md](upgrade-issues.md).

## Traffic management problems

### 503 after DestinationRule {#503-after-destinationrule}

If requests return HTTP 503 immediately after applying a `DestinationRule` (and stop when you remove it), the `DestinationRule` is causing a TLS conflict. When mTLS is enabled globally, every `DestinationRule` must include:

```yaml
trafficPolicy:
  tls:
    mode: ISTIO_MUTUAL
```

Otherwise mode defaults to `DISABLE`, causing plaintext requests that conflict with the server expecting encrypted traffic.

### Route rules not working {#route-rules-not-working}

- **Weighted routing**: Up to 100 requests may be needed before weighted distribution is observed.
- **Service requirements**: Kubernetes services must meet [Istio's pod/service requirements](https://istio.io/docs/ops/deployment/application-requirements/) for L7 routing.
- **Propagation delay**: Configuration uses eventually consistent distribution. Large deployments may take seconds to propagate.

### Route rules ignored by ingress gateway

When a gateway `VirtualService` routes to a service, a separate `VirtualService` for that service's subsets won't apply to ingress traffic. The gateway uses its own host matching.

**Fix**: Include the subset directly in the gateway's `VirtualService`:

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: myapp
spec:
  hosts:
  - "myapp.com"
  gateways:
  - myapp-gateway
  http:
  - match:
    - uri:
        prefix: /hello
    route:
    - destination:
        host: helloworld.default.svc.cluster.local
        subset: v1
```

Or combine both VirtualServices into one with explicit `gateways` matching (`mesh` for internal, gateway name for external).

### Envoy crashing under load

Check file descriptor limits: `ulimit -a`. Default 1024 is too low. Fix: `ulimit -n 16384`.

### Envoy won't connect to HTTP/1.0 service

Envoy requires HTTP/1.1 or HTTP/2. For NGINX backends, set `proxy_http_version 1.1;` in config.

### 503 accessing headless services

When accessing a headless service by Pod IP with an `http-` prefixed port name, the sidecar can't find the route. Fixes:
1. Set correct `Host` header (e.g., `Host: nginx.default`).
2. Change port name to `tcp` or `tcp-web` to bypass HTTP routing.
3. Use the domain name (e.g., `web-0.nginx.default`) instead of Pod IP.

### Fault injection + retry/timeout don't work together

Istio doesn't support fault injection and retry/timeout on the same `VirtualService`. The retry config is ignored. **Workaround**: Remove fault from VirtualService; inject faults via `EnvoyFilter` on the upstream proxy instead.

### EnvoyFilter stops working after upgrade

`INSERT_BEFORE` operations depend on the referenced filter existing with an older creation time. After Istio upgrades, version-specific filters may be replaced. **Fix**: Use `INSERT_FIRST` or set explicit `priority` (e.g., `priority: 10`).

## TLS configuration mistakes

For detailed TLS troubleshooting scenarios, see [tls-issues.md](tls-issues.md).

Key issues:
- Sending HTTPS to a port declared as HTTP → `400 DPE` or SSL errors
- Gateway TLS termination + VirtualService TLS routing → 404 (use `http` routing after termination)
- Gateway TLS passthrough + VirtualService HTTP routing → no effect (use `tls` routing)
- Double TLS from TLS origination + HTTPS ServiceEntry → change ServiceEntry protocol to HTTP
- Multiple gateways with same wildcard cert → 404 from HTTP/2 connection reuse (use single gateway)
- SNI routing without SNI being sent → requests fail (use `--resolve` or set `hosts: "*"`)

## Observability problems

### No traces in Zipkin (Mac/Docker)

Docker for Mac time skew causes traces to appear days early. Fix: restart Docker, then reinstall Istio.

### Missing Grafana output

Client and server time must match. Ensure NTP/Chrony is configured correctly on both the cluster and the browser machine.

### Verify Istio CNI pods

```bash
kubectl -n kube-system get pod -l k8s-app=istio-cni-node
```

If using `PodSecurityPolicy`, ensure `istio-cni` service account can use a PSP allowing `NET_ADMIN` and `NET_RAW`.

## Key diagnostic commands

```bash
# Check proxy config
istioctl proxy-config listener POD -n NAMESPACE --port 80 --type HTTP -o json
istioctl proxy-config routes POD -n NAMESPACE
istioctl proxy-config secret POD

# Check authorization
istioctl x authz check POD.NAMESPACE

# Enable debug logging
istioctl admin log --level authorization:debug
istioctl proxy-config log deploy/DEPLOYMENT --level "rbac:debug"

# Get proxy config dump
kubectl exec POD -c istio-proxy -- pilot-agent request GET config_dump

# View Istiod logs
kubectl logs $(kubectl -n istio-system get pods -l app=istiod -o jsonpath='{.items[0].metadata.name}') -c discovery -n istio-system
```

## Additional resources

- For TLS configuration issues in detail, see [tls-issues.md](tls-issues.md)
- For security and authorization troubleshooting, see [security-issues.md](security-issues.md)
- For upgrade and EnvoyFilter migration, see [upgrade-issues.md](upgrade-issues.md)
