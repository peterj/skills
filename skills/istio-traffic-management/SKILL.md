---
name: istio-traffic-management
description: Configures Istio traffic management including multicluster traffic control, gateway network topology (XFF/XFCC headers, PROXY protocol), protocol selection, and TLS configuration. Use when working with Istio service mesh traffic routing, multicluster setups, gateway configuration, protocol detection, mTLS settings, or when troubleshooting TLS/proxy header issues.
---

# Istio Traffic Management Configuration

## Quick start

### Keep traffic cluster-local (multicluster)

Use `MeshConfig.serviceSettings` to prevent cross-cluster load balancing:

```yaml
# Per service
serviceSettings:
- settings:
    clusterLocal: true
  hosts:
  - "mysvc.myns.svc.cluster.local"

# Per namespace
serviceSettings:
- settings:
    clusterLocal: true
  hosts:
  - "*.myns.svc.cluster.local"

# Global (all services)
serviceSettings:
- settings:
    clusterLocal: true
  hosts:
  - "*"
```

Combine global cluster-local with exceptions:

```yaml
serviceSettings:
- settings:
    clusterLocal: true
  hosts:
  - "*"
- settings:
    clusterLocal: false
  hosts:
  - "*.myns.svc.cluster.local"
```

### Set protocol explicitly on a Service

```yaml
kind: Service
metadata:
  name: myservice
spec:
  ports:
  - port: 3306
    name: database
    appProtocol: https
  - port: 80
    name: http-web
```

### Configure trusted proxies for correct client IP

```yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  meshConfig:
    defaultConfig:
      gatewayTopology:
        numTrustedProxies: 2
```

## Key concepts

### Multicluster traffic

- **Cluster-local traffic**: Use `MeshConfig.serviceSettings` with `clusterLocal: true` to keep traffic within a cluster.
- **Partitioning by cluster**: Use `DestinationRule.subsets` with label `topology.istio.io/cluster` to create per-cluster subsets, then route with `VirtualService`.
- Subset-based routing mixes service-level and topology-level policy — use only when granular cluster-based control is needed.

### Protocol selection

- **Automatic**: Istio auto-detects HTTP and HTTP/2. Undetected traffic is treated as TCP. Server-first protocols (e.g., MySQL) are incompatible with auto-detection.
- **Explicit**: Set via port name (`name: <protocol>[-<suffix>]`) or `appProtocol` field. `appProtocol` takes precedence.
- **Supported protocols**: `http`, `http2`, `https`, `tcp`, `tls`, `grpc`, `grpc-web`, `mongo`, `mysql`, `redis` (last three are experimental).
- **Gateway behavior**: Gateways default to forwarding as HTTP/1.1 unless explicit protocol is set. Use `useClientProtocol` in DestinationRule to match incoming protocol.

### TLS configuration

- **`PeerAuthentication`**: Controls what mTLS traffic a sidecar accepts (`PERMISSIVE`, `STRICT`, `DISABLE`).
- **`DestinationRule`**: Controls what TLS traffic a sidecar/gateway sends (`DISABLE`, `SIMPLE`, `MUTUAL`, `ISTIO_MUTUAL`).
- **Auto mTLS**: Sidecars automatically use mTLS for mesh-internal traffic and plaintext for non-mesh workloads, unless a `DestinationRule` explicitly overrides.
- **Gateway inbound**: Configured via `Gateway` resource — set protocol (`HTTP`, `HTTPS`, `TLS`, `TCP`) and TLS mode (`PASSTHROUGH`, `MUTUAL`, etc.).
- **Gateway outbound**: Configured via `DestinationRule` TLS settings or auto mTLS. Watch for double encryption when Gateway uses `PASSTHROUGH` and DestinationRule originates TLS.

### Gateway network topology

- **`numTrustedProxies`**: Number of trusted proxies in front of the Istio gateway. Controls `X-Envoy-External-Address` extraction from `X-Forwarded-For`.
- **`forwardClientCertDetails`**: Controls XFCC header handling. Values: `SANITIZE`, `FORWARD_ONLY`, `APPEND_FORWARD`, `SANITIZE_SET` (default for gateways), `ALWAYS_FORWARD_ONLY`.
- **PROXY protocol**: For TCP-only traffic. Enabled via `gatewayTopology.proxyProtocol: {}`. Not for L7 traffic or behind L7 load balancers.

## Additional resources

- For multicluster traffic patterns and partitioning, see [references/multicluster.md](references/multicluster.md)
- For gateway topology, TLS, and protocol details, see [references/gateway-and-tls.md](references/gateway-and-tls.md)
