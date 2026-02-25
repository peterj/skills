# Gateway Network Topology, Protocol Selection, and TLS Configuration

## Table of contents

- [Gateway network topology](#gateway-network-topology)
  - [X-Forwarded-For (XFF)](#x-forwarded-for-xff)
  - [X-Forwarded-Client-Cert (XFCC)](#x-forwarded-client-cert-xfcc)
  - [PROXY protocol](#proxy-protocol)
- [Protocol selection](#protocol-selection)
  - [Automatic detection](#automatic-detection)
  - [Explicit selection](#explicit-selection)
  - [Supported protocols table](#supported-protocols-table)
  - [HTTP gateway protocol behavior](#http-gateway-protocol-behavior)
- [TLS configuration](#tls-configuration)
  - [Sidecar connections](#sidecar-connections)
  - [Auto mTLS](#auto-mtls)e
  - [Gateway connections](#gateway-connections)

---

## Gateway network topology

Configuration can be set globally via `MeshConfig` or per gateway via pod annotation.

### Global configuration (IstioOperator)

```yaml
spec:
  meshConfig:
    defaultConfig:
      gatewayTopology:
        numTrustedProxies: <VALUE>
        forwardClientCertDetails: <ENUM_VALUE>
```

### Per-gateway pod annotation

```yaml
metadata:
  annotations:
    "proxy.istio.io/config": '{"gatewayTopology" : { "numTrustedProxies": <VALUE>, "forwardClientCertDetails": <ENUM_VALUE> } }'
```

### X-Forwarded-For (XFF)

Set `numTrustedProxies` to the number of trusted proxies in front of the Istio gateway.

- Controls the value of `X-Envoy-External-Address` populated by the ingress gateway.
- Example: cloud Load Balancer + reverse proxy in front of gateway → set `numTrustedProxies: 2`.
- All proxies in front must parse HTTP and append to `X-Forwarded-For` at each hop.
- If XFF entries are fewer than trusted hops configured, Envoy falls back to the immediate downstream address.

#### XFF example with httpbin

1. Install Istio with `numTrustedProxies: 2`:

```bash
cat <<EOF > topology.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  meshConfig:
    defaultConfig:
      gatewayTopology:
        numTrustedProxies: 2
EOF
istioctl install -f topology.yaml
```

2. Create and label namespace:

```bash
kubectl create namespace httpbin
kubectl label --overwrite namespace httpbin istio-injection=enabled
```

3. Deploy httpbin and gateway:

```bash
kubectl apply -n httpbin -f samples/httpbin/httpbin.yaml
# Istio APIs:
kubectl apply -n httpbin -f samples/httpbin/httpbin-gateway.yaml
# Or Gateway API:
kubectl apply -n httpbin -f samples/httpbin/gateway-api/httpbin-gateway.yaml
kubectl wait --for=condition=programmed gtw -n httpbin httpbin-gateway
```

4. Get gateway URL:

```bash
# Istio APIs:
export GATEWAY_URL=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
# Gateway API:
export GATEWAY_URL=$(kubectl get gateways.gateway.networking.k8s.io httpbin-gateway -n httpbin -ojsonpath='{.status.addresses[0].value}')
```

5. Test:

```bash
curl -s -H 'X-Forwarded-For: 56.5.6.7, 72.9.5.6, 98.1.2.3' "$GATEWAY_URL/get?show_env=true" | jq '.headers["X-Forwarded-For"][0]'
```

With `numTrustedProxies: 2`, the gateway sets `X-Envoy-External-Address` to the second-to-last address in XFF.

### X-Forwarded-Client-Cert (XFCC)

Set `forwardClientCertDetails` to control XFCC header handling:

| Value | Behavior |
|---|---|
| `UNDEFINED` | Field is not set |
| `SANITIZE` | Do not send XFCC to next hop |
| `FORWARD_ONLY` | Forward XFCC when client connection is mTLS |
| `APPEND_FORWARD` | Append client cert info to XFCC when mTLS, then forward |
| `SANITIZE_SET` | Reset XFCC with client cert info when mTLS (default for gateways) |
| `ALWAYS_FORWARD_ONLY` | Always forward XFCC regardless of mTLS |

```yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  meshConfig:
    defaultConfig:
      gatewayTopology:
        forwardClientCertDetails: SANITIZE_SET
```

### PROXY protocol

For TCP-only traffic where an external TCP load balancer needs to pass client attributes.

**Important restrictions:**
- Only for TCP traffic forwarding
- Do NOT use for L7 traffic or behind L7 load balancers
- Has performance implications

Enable globally:

```yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  meshConfig:
    defaultConfig:
      gatewayTopology:
        proxyProtocol: {}
```

Or via pod annotation:

```yaml
metadata:
  annotations:
    "proxy.istio.io/config": '{"gatewayTopology" : { "proxyProtocol": {} }}'
```

When PROXY protocol is used with `gatewayTopology`, `numTrustedProxies` and received `X-Forwarded-For` take precedence over PROXY protocol client information.

---

## Protocol selection

### Automatic detection

Istio auto-detects HTTP and HTTP/2. If not detected, traffic is treated as plain TCP.

Server-first protocols (e.g., MySQL) are incompatible with automatic protocol selection.

### Explicit selection

Two methods:
1. Port name: `name: <protocol>[-<suffix>]`
2. `appProtocol` field (Kubernetes 1.18+): `appProtocol: <protocol>`

`appProtocol` takes precedence over port name if both are defined.

### Supported protocols table

| Protocol | Sidecar Purpose | Gateway Purpose |
|---|---|---|
| `http` | Plaintext HTTP/1.1 | Plaintext HTTP (1.1 or 2) |
| `http2` | Plaintext HTTP/2 | Plaintext HTTP (1.1 or 2) |
| `https` | TLS encrypted (same as `tls` for sidecar) | TLS encrypted HTTP (1.1 or 2) |
| `tcp` | Opaque TCP data stream | Opaque TCP data stream |
| `tls` | TLS encrypted data | TLS encrypted data |
| `grpc`, `grpc-web` | Same as `http2` | Same as `http2` |
| `mongo`, `mysql`, `redis` | Experimental (requires env vars) | Experimental (requires env vars) |

### HTTP gateway protocol behavior

Gateways default to forwarding as HTTP/1.1 unless explicit protocol is set.

Use `useClientProtocol` in `DestinationRule.ConnectionPoolSettings.HTTPSettings` to match incoming protocol. Caution: HTTPS gateways advertise HTTP/1.1 and HTTP/2 via ALPN — if backend doesn't support HTTP/2, clients may still attempt it.

---

## TLS configuration

### Sidecar connections

Four connection types:

1. **External inbound**: Traffic captured by sidecar from outside. Accepts mTLS + plaintext in `PERMISSIVE` mode (default), mTLS-only in `STRICT`, plaintext-only in `DISABLE`. Configured via `PeerAuthentication`.

2. **Local inbound**: Sidecar to application. Always forwarded as-is (no new TLS origination by sidecar).

3. **Local outbound**: Application to sidecar. App may send plaintext or TLS. Istio detects protocol automatically or uses port name/`appProtocol`.

4. **External outbound**: Sidecar to external destination. Controlled via `DestinationRule` `trafficPolicy.tls.mode`: `DISABLE` (plaintext), `SIMPLE`/`MUTUAL`/`ISTIO_MUTUAL` (originate TLS).

**Key takeaways:**
- `PeerAuthentication` → what mTLS the sidecar **accepts**
- `DestinationRule` → what TLS the sidecar **sends**
- Port names / auto-detection → protocol parsing

### Auto mTLS

Without explicit `DestinationRule` TLS settings, sidecars automatically:
- Use Istio mutual TLS for mesh-internal traffic (workloads with sidecars)
- Send plaintext to workloads without sidecars

No configuration needed — all inter-mesh traffic is mTLS encrypted by default.

### Gateway connections

Two connections per request:

**Inbound (downstream):** Configured via `Gateway` resource.

- Plaintext HTTP: `protocol: HTTP`
- Raw TCP: `protocol: TCP`
- HTTPS: `protocol: HTTPS`
- TLS-wrapped TCP: `protocol: TLS`
- TLS passthrough: set `tls.mode: PASSTHROUGH` (routes on SNI, forwards as-is)
- Mutual TLS: set `tls.mode: MUTUAL` with `caCertificates` or `credentialName`

Gateway resource examples:

```yaml
# Plaintext HTTP
servers:
- port:
    number: 80
    name: http
    protocol: HTTP

# TLS Passthrough
servers:
- port:
    number: 443
    name: https
    protocol: HTTPS
  tls:
    mode: PASSTHROUGH

# Mutual TLS
servers:
- port:
    number: 443
    name: https
    protocol: HTTPS
  tls:
    mode: MUTUAL
    caCertificates: ...
```

**Outbound (upstream):** Configured via `DestinationRule` TLS settings or auto mTLS.

**Watch out for double encryption:** If Gateway uses `PASSTHROUGH` and DestinationRule originates TLS, traffic gets encrypted twice. This works but is usually not intended.

Ensure `VirtualService` bound to the gateway is consistent with the `Gateway` definition.
