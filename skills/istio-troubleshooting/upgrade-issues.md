# Upgrade and EnvoyFilter Migration

`EnvoyFilter` is an alpha API tightly coupled to Istio's xDS implementation. During upgrades, EnvoyFilter configs can break silently. Prefer first-class Istio APIs whenever possible.

## Table of contents

- [Telemetry API for metrics customization](#telemetry-api)
- [WasmPlugin API for Wasm extensibility](#wasmplugin-api)
- [Gateway topology for trusted hops](#gateway-topology-trusted-hops)
- [Gateway topology for PROXY protocol](#gateway-topology-proxy-protocol)
- [Proxy annotation for histogram buckets](#histogram-buckets)

## Telemetry API for metrics customization {#telemetry-api}

Replace `IstioOperator`-based metric customization (which relies on EnvoyFilter templates) with the `Telemetry` API. The two methods are **incompatible**.

**Before** (IstioOperator):
```yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  values:
    telemetry:
      v2:
        prometheus:
          configOverride:
            inboundSidecar:
              metrics:
                - name: requests_total
                  dimensions:
                    destination_port: string(destination.port)
```

**After** (Telemetry API):
```yaml
apiVersion: telemetry.istio.io/v1
kind: Telemetry
metadata:
  name: namespace-metrics
spec:
  metrics:
  - providers:
    - name: prometheus
    overrides:
    - match:
        metric: REQUEST_COUNT
      mode: SERVER
      tagOverrides:
        destination_port:
          value: "string(destination.port)"
```

## WasmPlugin API for Wasm extensibility {#wasmplugin-api}

Replace `EnvoyFilter`-based Wasm filter injection with the `WasmPlugin` API. Supports dynamic loading from artifact registries, URLs, or local files. The "Null" plugin runtime is no longer recommended.

## Gateway topology for trusted hops {#gateway-topology-trusted-hops}

Replace `EnvoyFilter` that sets `xff_num_trusted_hops` with a proxy annotation:

**Before** (EnvoyFilter):
```yaml
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: ingressgateway-redirect-config
spec:
  configPatches:
  - applyTo: NETWORK_FILTER
    match:
      context: GATEWAY
      listener:
        filterChain:
          filter:
            name: envoy.filters.network.http_connection_manager
    patch:
      operation: MERGE
      value:
        typed_config:
          '@type': type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
          xff_num_trusted_hops: 1
  workloadSelector:
    labels:
      istio: ingress-gateway
```

**After** (pod annotation):
```yaml
metadata:
  annotations:
    "proxy.istio.io/config": '{"gatewayTopology" : { "numTrustedProxies": 1 }}'
```

## Gateway topology for PROXY protocol {#gateway-topology-proxy-protocol}

Replace `EnvoyFilter` that inserts PROXY protocol listener filter with a proxy annotation:

**Before** (EnvoyFilter):
```yaml
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: proxy-protocol
spec:
  configPatches:
  - applyTo: LISTENER_FILTER
    patch:
      operation: INSERT_FIRST
      value:
        name: proxy_protocol
        typed_config:
          "@type": "type.googleapis.com/envoy.extensions.filters.listener.proxy_protocol.v3.ProxyProtocol"
  workloadSelector:
    labels:
      istio: ingress-gateway
```

**After** (pod annotation):
```yaml
metadata:
  annotations:
    "proxy.istio.io/config": '{"gatewayTopology" : { "proxyProtocol": {} }}'
```

## Proxy annotation for histogram buckets {#histogram-buckets}

Replace `EnvoyFilter` bootstrap patch for histogram bucket sizes with a pod annotation:

**Before** (EnvoyFilter):
```yaml
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: envoy-stats-1
  namespace: istio-system
spec:
  workloadSelector:
    labels:
      istio: ingressgateway
  configPatches:
  - applyTo: BOOTSTRAP
    patch:
      operation: MERGE
      value:
        stats_config:
          histogram_bucket_settings:
            - match:
                prefix: istiocustom
              buckets: [1,5,50,500,5000,10000]
```

**After** (pod annotation):
```yaml
metadata:
  annotations:
    "sidecar.istio.io/statsHistogramBuckets": '{"istiocustom":[1,5,50,500,5000,10000]}'
```
