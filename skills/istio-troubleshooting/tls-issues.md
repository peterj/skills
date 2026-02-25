# TLS Configuration Issues

## Table of contents

- [Sending HTTPS to an HTTP port](#sending-https-to-an-http-port)
- [Gateway to VirtualService TLS mismatch](#gateway-to-virtualservice-tls-mismatch)
  - [Gateway with TLS termination](#gateway-with-tls-termination)
  - [Gateway with TLS passthrough](#gateway-with-tls-passthrough)
- [Double TLS (TLS origination for a TLS request)](#double-tls)
- [404 errors with multiple gateways sharing TLS certificate](#404-with-shared-certificate)
- [SNI routing when not sending SNI](#sni-routing-issues)

## Sending HTTPS to an HTTP port

If a `ServiceEntry` declares port 443 with protocol `HTTP`, but the application sends HTTPS, Envoy tries to parse encrypted traffic as HTTP.

**Symptom**: `curl: (35) error:1408F10B:SSL routines:ssl3_get_record:wrong version number` or access log error `400 DPE`.

**Bad config**:
```yaml
spec:
  ports:
  - number: 443
    name: http
    protocol: HTTP
```

**Fix**: Change protocol to HTTPS:
```yaml
spec:
  ports:
  - number: 443
    name: https
    protocol: HTTPS
```

## Gateway to VirtualService TLS mismatch

### Gateway with TLS termination

When the Gateway terminates TLS (`tls.mode: SIMPLE`), traffic becomes HTTP after termination. A VirtualService using `tls` routing rules won't match because the request is now HTTP.

**Symptom**: 404 responses.

**Bad config**: Gateway has `tls.mode: SIMPLE`, VirtualService uses `tls` match with `sniHosts`.

**Fix**: Switch VirtualService to `http` routing:
```yaml
spec:
  http:
  - match:
    - headers:
        ":authority":
          regex: "*.example.com"
```

### Gateway with TLS passthrough

When the Gateway uses `tls.mode: PASSTHROUGH`, traffic remains encrypted. A VirtualService using `http` routing won't match.

**Symptom**: VirtualService has no effect.

**Fix**: Switch VirtualService to `tls` routing:
```yaml
spec:
  tls:
  - match:
    - sniHosts: ["httpbin.example.com"]
    route:
    - destination:
        host: httpbin.org
```

Alternatively, switch the Gateway to terminate TLS (`tls.mode: SIMPLE` with credentials).

## Double TLS {#double-tls}

When configuring TLS origination via `DestinationRule`, the application must send **plaintext**. If the `ServiceEntry` declares the port as `HTTPS`, the sidecar expects the app to send TLS, then performs TLS origination again — double encrypting.

**Symptom**: `(35) error:1408F10B:SSL routines:ssl3_get_record:wrong version number`.

**Bad config**: ServiceEntry with `protocol: HTTPS` on port 443 + DestinationRule with `tls.mode: SIMPLE`.

**Fix**: Change ServiceEntry port protocol to `HTTP`:
```yaml
spec:
  hosts:
  - httpbin.org
  ports:
  - number: 443
    name: http
    protocol: HTTP
```

The app must send plaintext to port 443 (e.g., `curl http://httpbin.org:443`). From Istio 1.8+, you can expose port 80 with `targetPort: 443`:
```yaml
spec:
  ports:
  - number: 80
    name: http
    protocol: HTTP
    targetPort: 443
```

## 404 with shared certificate {#404-with-shared-certificate}

Multiple Gateways using the same TLS certificate (e.g., wildcard `*.test.com`) on the same ingress workload cause HTTP/2 connection reuse. Browsers reuse the connection from the first host, and the second gateway returns 404.

**Fix**: Use a single wildcard Gateway and bind both VirtualServices to it:
```yaml
# Single Gateway
spec:
  servers:
  - hosts: ["*.test.com"]
    port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: wildcard-cert
---
# VirtualService 1
spec:
  hosts: ["service1.test.com"]
  gateways: [gw]
---
# VirtualService 2
spec:
  hosts: ["service2.test.com"]
  gateways: [gw]
```

## SNI routing issues {#sni-routing-issues}

An HTTPS Gateway with specific `hosts` performs SNI matching. If no SNI is sent (e.g., `curl` with `-H "Host:"` but no DNS), the request fails.

**Causes**:
- Direct IP access with Host header only (no SNI): use `--resolve` flag or set up DNS.
- Cloud load balancer stripping SNI: configure LB for TLS passthrough, or set Gateway `hosts: "*"`.

**Symptom**: LB health checks pass but real traffic fails.
